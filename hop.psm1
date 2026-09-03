# hop for PowerShell: a bookmark picker for the directories you actually work
# in, and the hosts you ssh to.
#
# The bash version prints a path and a shell function turns it into a `cd`,
# because a child process cannot move its parent. A PowerShell function runs in
# the caller's session and can call Set-Location directly, so here the function
# is the whole program. install.ps1 imports this module from your profile.
#
# Same bookmarks format, same ssh config parsing, same merge order as the bash
# version, with $env:ProgramData\hop standing in for /etc/hop and
# $env:APPDATA\hop for ~/.config/hop. Not ported: the category column and
# alt-N, which work by fzf re-invoking the script on every keypress. pwsh
# takes a few hundred milliseconds to start, so that would feel sluggish.
# `tab` is ported: the row lists it switches between are written to temp
# files before fzf starts, and a batch file cycles through them, so no pwsh
# sits under the key.

$script:SysDir  = Join-Path $env:ProgramData 'hop'
$script:UserDir = Join-Path $env:APPDATA 'hop'
$script:Utf8    = [Text.UTF8Encoding]::new($false)

function Get-HopSources {
  if ($env:HOP_CONFIG) { return @($env:HOP_CONFIG) }
  $out = @()
  foreach ($dir in $script:SysDir, $script:UserDir) {
    $f = Join-Path $dir 'bookmarks'
    if (Test-Path -LiteralPath $f -PathType Leaf) { $out += $f }
    $d = Join-Path $dir 'bookmarks.d'
    if (Test-Path -LiteralPath $d -PathType Container) {
      $out += @(Get-ChildItem -LiteralPath $d -Filter '*.conf' -File | Sort-Object Name | ForEach-Object FullName)
    }
  }
  $out
}

# Emits one object per bookmark. Only ~ and $HOME are expanded; the file is
# hand-edited but never evaluated.
function Read-HopFile([string]$file) {
  $cat = 'misc'
  foreach ($raw in [IO.File]::ReadLines($file)) {
    $line = $raw.TrimEnd("`r")
    if ($line -match '^\s*#') { continue }
    $line = ($line -replace '\s#.*$', '').Trim()
    if (-not $line) { continue }
    if ($line -match '^\[(.*)\]$') { $cat = $Matches[1]; continue }

    $tok, $rest = $line -split '\s+', 2
    # A leading * pins the entry to the top of the list.
    $pin = $false
    if ($tok.StartsWith('*')) { $pin = $true; $tok = $tok.Substring(1) }
    if ($rest) { $name = $tok; $path = $rest.Trim() }
    else       { $path = $tok; $name = Split-Path -Leaf $path }

    $path = $path.Replace('$HOME', $HOME)
    if ($path.StartsWith('~')) { $path = $HOME + $path.Substring(1) }
    # Lists are shared across machines and written with /, which Windows
    # accepts but displays badly next to $HOME's backslashes. ssh entries are
    # not paths and keep theirs.
    if (-not $path.StartsWith('ssh://')) { $path = $path.Replace('/', '\') }

    [pscustomobject]@{ Pin = $pin; Cat = $cat; Name = $name; Path = $path }
  }
}

# Settings: $env:ProgramData\hop\config then $env:APPDATA\hop\config, last one
# wins. `key = value`, # starts a comment.
function Get-HopSetting([string]$key, [string]$default) {
  $v = $default
  foreach ($f in (Join-Path $script:SysDir 'config'), (Join-Path $script:UserDir 'config')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    foreach ($l in [IO.File]::ReadLines($f)) {
      if ($l -match "^\s*$key\s*=\s*([^#]*)") { $got = $Matches[1].Trim(); if ($got) { $v = $got } }
    }
  }
  $v
}

# --- ssh hosts ---------------------------------------------------------------
# Hosts from your ssh config are a second source, in the same shape as
# bookmarks so they merge, pin and filter alike. Path is ssh://user@host, what
# you see and filter on; Name is the alias, and `enter` runs `ssh <alias>` so
# the config supplies the key, port and jumps exactly as it would from the
# shell. `ssh_config` names the file, defaulting to where ssh itself looks;
# `off` disables the source for machines that are only ever the destination.

function Get-HopSshConfigPath {
  $p = Get-HopSetting ssh_config (Join-Path $HOME '.ssh\config')
  if ($p -in 'off', 'no', 'none') { return $null }
  $p = $p.Replace('$HOME', $HOME)
  if ($p.StartsWith('~')) { $p = $HOME + $p.Substring(1) }
  $p.Replace('/', '\')
}

# One Include argument to the files it names. Relative paths are relative to
# ~/.ssh, as ssh resolves them; wildcards expand.
function Resolve-HopSshInclude([string]$spec) {
  $spec = $spec.Trim('"').Replace('$HOME', $HOME)
  if ($spec.StartsWith('~')) { $spec = $HOME + $spec.Substring(1) }
  if (-not [IO.Path]::IsPathRooted($spec)) { $spec = Join-Path $HOME ".ssh\$spec" }
  try { @(Get-Item -Path $spec -ErrorAction Stop | Where-Object { -not $_.PSIsContainer } | ForEach-Object FullName) }
  catch { @() }
}

# Categories come from marker comments, `# [acme/web]`, which ssh ignores and
# a generator can emit. Everything until the next marker belongs to it, under
# an `ssh/` prefix so typing `ssh` narrows to hosts. Include is followed; an
# included file with no markers is grouped by its file name, except one
# called `config`, which is a pointer and inherits. Wildcard and negated Host
# patterns and Match blocks are skipped: rules, not places you can go.
function Read-HopSshFile([string]$file, [string]$cat, [int]$depth) {
  if ($depth -ge 8) { return }
  $alias = $null; $hcat = ''; $hostn = ''; $user = ''
  $emit = {
    if ($alias) {
      $u = if ($user) { "$user@" } else { '' }
      $h = if ($hostn) { $hostn } else { $alias }
      [pscustomobject]@{ Pin = $false; Cat = $hcat; Name = $alias; Path = "ssh://$u$h" }
    }
  }
  foreach ($raw in [IO.File]::ReadLines($file)) {
    $line = $raw.TrimEnd("`r")
    if ($line -match '^\s*#\s*\[([^\]]+)\]\s*$') { $cat = 'ssh/' + $Matches[1]; continue }
    if ($line -match '^\s*(#|$)') { continue }
    if ($line -notmatch '^\s*([A-Za-z]+)\s*=?\s*(.*)$') { continue }
    $key = $Matches[1].ToLowerInvariant(); $val = $Matches[2].Trim().Trim('"')
    switch ($key) {
      'host' {
        & $emit; $alias = $null
        $tok = ($val -split '\s+')[0]
        if ($tok -and $tok -notmatch '[*?]' -and -not $tok.StartsWith('!')) {
          $alias = $tok; $hcat = $cat; $hostn = ''; $user = ''
        }
      }
      'match'    { & $emit; $alias = $null }
      'hostname' { $hostn = $val }
      'user'     { $user = $val }
      'include'  {
        foreach ($spec in ($val -split '\s+')) {
          foreach ($f in Resolve-HopSshInclude $spec) {
            $sub = 'ssh/' + [IO.Path]::GetFileNameWithoutExtension($f)
            if ($sub -eq 'ssh/config') { $sub = $cat }
            Read-HopSshFile $f $sub ($depth + 1)
          }
        }
      }
    }
  }
  & $emit
}

function Get-HopSshHosts {
  $p = Get-HopSshConfigPath
  if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { return }
  if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { return }
  Read-HopSshFile $p 'ssh' 0
}

$script:HostRe = '^\s*[Hh]ost[\s=]+([^\s*?!]+)'

# The file to edit or replace. A config with no concrete hosts of its own and
# a single Include is a pointer, common when the real file lives in a synced
# folder, so follow it: editing the pointer is never what you meant.
function Get-HopSshEditTarget([string]$p) {
  $lines = [IO.File]::ReadAllLines($p)
  if (@($lines | Where-Object { $_ -match $script:HostRe }).Count) { return $p }
  $incs = @($lines | ForEach-Object { if ($_ -match '^\s*[Ii]nclude[\s=]+(.+)$') { $Matches[1].Trim() } })
  if ($incs.Count -ne 1) { return $p }
  $t = @(Resolve-HopSshInclude $incs[0])
  if ($t.Count -eq 1) { $t[0] } else { $p }
}

# Replace the ssh config from the clipboard, a file, or the pipeline. For
# when a server inventory generates the whole file and you want it in place
# without hunting for the path. Checked with `ssh -G` before anything is
# touched; the old file is kept beside it as .bak.
function Import-HopSshConfig([string]$cfg, [string]$file, $piped) {
  if ($file)               { $new = Get-Content -LiteralPath $file -Raw }
  elseif ($null -ne $piped) { $new = ($piped -join "`n") }
  else                     { $new = Get-Clipboard -Raw }
  if (-not $new) { Write-Host 'hop: nothing to import'; return }
  $new = ($new -replace "`r", '').TrimEnd() + "`n"
  $re = [regex]::new($script:HostRe, 'Multiline')
  $first = $re.Match($new)
  if (-not $first.Success) { Write-Host 'hop: that does not look like an ssh config: no Host line'; return }

  $tmp = [IO.Path]::GetTempFileName()
  [IO.File]::WriteAllText($tmp, $new, $script:Utf8)
  # Piped in explicitly: when hop itself is fed from a pipeline, a native
  # command inside it otherwise inherits that pipe and Windows complains.
  $check = $null | & ssh -G -F $tmp $first.Groups[1].Value 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'hop: ssh rejects it, nothing written:'
    $check | Where-Object { $_ -is [Management.Automation.ErrorRecord] } | ForEach-Object { Write-Host "     $_" }
    Remove-Item -LiteralPath $tmp -Force; return
  }
  Remove-Item -LiteralPath $tmp -Force

  $oldHosts = @()
  if (Test-Path -LiteralPath $cfg -PathType Leaf) {
    $oldHosts = @($re.Matches((Get-Content -LiteralPath $cfg -Raw)) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    Copy-Item -LiteralPath $cfg -Destination "$cfg.bak" -Force
  }
  $newHosts = @($re.Matches($new) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  New-Item -ItemType Directory -Force (Split-Path -Parent $cfg) | Out-Null
  [IO.File]::WriteAllText($cfg, $new, $script:Utf8)

  $msg = "hop: wrote $($newHosts.Count) hosts to $cfg"
  if ($oldHosts.Count) { $msg += " (old copy in $(Split-Path -Leaf $cfg).bak)" }
  Write-Host $msg
  foreach ($h in $newHosts) { if ($h -notin $oldHosts) { Write-Host "     + $h" } }
  foreach ($h in $oldHosts) { if ($h -notin $newHosts) { Write-Host "     - $h" } }
}

# --- merge ------------------------------------------------------------------
# ssh hosts first, then the files, so a bookmarks file can repin or repoint
# one host by repeating its category and name. Later sources override the same
# category/name in place and leave the rest alone. Pinned entries sort first,
# source order within each group.
function Get-HopBookmarks {
  $merged = [ordered]@{}
  foreach ($b in Get-HopSshHosts) { $merged["$($b.Cat)`t$($b.Name)"] = $b }
  foreach ($f in Get-HopSources) {
    foreach ($b in Read-HopFile $f) { $merged["$($b.Cat)`t$($b.Name)"] = $b }
  }
  $all = @($merged.Values)
  @($all | Where-Object Pin) + @($all | Where-Object { -not $_.Pin })
}

# A bookmark may point at a file; you hop to its directory.
function Get-HopDestDir([string]$p) {
  if (Test-Path -LiteralPath $p -PathType Container) { $p } else { Split-Path -Parent $p }
}

function Get-HopShortPath([string]$p) {
  if ($p.StartsWith('ssh://')) { return $p.Substring(6) }
  if ($p.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { '~' + $p.Substring($HOME.Length) } else { $p }
}

# Find a virtualenv to activate for a directory. Walks up because the venv
# usually sits beside the project rather than inside the package dir it points
# at. Stops at $HOME so it never escapes into shared parents.
function Find-HopVenv([string]$dir) {
  $home_ = $HOME.TrimEnd('\', '/')
  $d = $dir
  while ($d) {
    foreach ($c in 'venv', '.venv', 'env') {
      $a = Join-Path $d "$c\Scripts\Activate.ps1"
      if (Test-Path -LiteralPath $a -PathType Leaf) { return $a }
    }
    if ($d.TrimEnd('\', '/') -ieq $home_) { break }
    $parent = Split-Path -Parent $d
    if (-not $parent -or $parent -eq $d) { break }
    $d = $parent
  }
}

function Enter-HopDir([string]$dir) {
  Set-Location -LiteralPath $dir
  $v = Find-HopVenv $dir
  if (-not $v) { return }
  if ($env:VIRTUAL_ENV -and (Get-Command deactivate -ErrorAction SilentlyContinue)) { deactivate }
  . $v
}

function Invoke-HopEditor([string]$file) {
  $ed = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
  $exe, $edArgs = $ed -split ' '
  & $exe @edArgs $file
}

function Write-HopUsage {
  Write-Host @'
hop [--all] [query]     pick a bookmark and cd there, or an ssh host and connect
hop --edit              open your bookmarks file in $env:EDITOR
hop --list              print entries as category<TAB>name<TAB>path
hop --ssh-edit          open your ssh config in $env:EDITOR
hop --ssh-import [file] replace your ssh config from the clipboard, a file, or
                        the pipeline; checked with `ssh -G` first, old copy in .bak

In the picker:
  tab / shift-tab   all, bookmarks, ssh hosts (or the categories, with one kind)
  type              filter, category names match too (`hop web` pre-types it)
  enter             cd there, or ssh there
  ^a claude    ^e edit    ^u git pull    ^p git push    ^o toggle preview

Bookmarks: $env:APPDATA\hop\bookmarks (yours) merged over
$env:ProgramData\hop\bookmarks (system wide), plus bookmarks.d\*.conf beside each.
Hosts: ~\.ssh\config, Include lines followed, `# [name]` comments grouping.
Set `ssh_config = <file>` or `ssh_config = off` in $env:APPDATA\hop\config.
'@
}

# The batch file behind tab. fzf runs binds through cmd.exe; this reads the
# current index from a state file, steps it, and types the matching row list.
# `%~1` strips whatever quoting fzf wrapped the argument in.
$script:CycleCmd = @'
@echo off
setlocal EnableDelayedExpansion
set "d=%~1"
set "s=%~2"
set /a n=%~3
set i=0
set /p i=<"!d!\state"
set /a i=(i+!s!+n) %% n
>"!d!\state" echo !i!
type "!d!\rows!i!.txt"
'@

# The preview, also run by fzf through cmd.exe. Field 6 says which kind of
# row it is; for a host, `ssh -G` resolves who you would land as and where,
# without connecting. For a directory, git status and a listing.
$script:PreviewCmd = @'
@echo off
setlocal EnableDelayedExpansion
if "%~1"=="ssh" (
  set kc=0
  for /f "tokens=1,*" %%a in ('ssh -G -F "%HOP_SSHCFG%" "%~3" 2^>nul') do (
    if "%%a"=="user" set "u=%%b"
    if "%%a"=="hostname" set "h=%%b"
    if "%%a"=="port" set "p=%%b"
    if "%%a"=="identityfile" set /a kc+=1
    if "%%a"=="identityfile" if not defined k set "k=%%b"
    if "%%a"=="proxyjump" if not "%%b"=="none" set "j=%%b"
  )
  if defined h (
    echo !u!@!h!
    if not "!p!"=="22" echo port !p!
    rem one identityfile means the config named it; several is ssh's default list
    if "!kc!"=="1" echo key !k!
    if defined j echo via !j!
  )
) else (
  git -C "%~2" -c color.ui=always status -sb 2>nul && echo. && git -C "%~2" -c color.ui=always log --oneline -5 2>nul
  echo.
  dir /b "%~2" 2>nul
)
'@

function hop {
  $piped = if ($MyInvocation.ExpectingInput) { @($input) } else { $null }
  $showAll = $false; $query = @(); $mode = 'pick'
  foreach ($a in $args) {
    switch ($a) {
      '--all'        { $showAll = $true }
      '--help'       { Write-HopUsage; return }
      '-h'           { Write-HopUsage; return }
      '--edit'       { $mode = 'edit' }
      '--list'       { $mode = 'list' }
      '--ssh-edit'   { $mode = 'ssh-edit' }
      '--ssh-import' { $mode = 'ssh-import' }
      default        { $query += $a }
    }
  }
  $query = $query -join ' '

  switch ($mode) {
    'edit' {
      $f = Join-Path $script:UserDir 'bookmarks'
      if (-not (Test-Path -LiteralPath $f)) {
        New-Item -ItemType Directory -Force (Split-Path -Parent $f) | Out-Null
        @'
# Your bookmarks. These MERGE with anything in %ProgramData%\hop, so you only
# need what is yours. Repeating a category/name from there overrides just that
# one. Drop-ins in %APPDATA%\hop\bookmarks.d\*.conf are merged too.

[mine]
'@ | Set-Content -LiteralPath $f -Encoding utf8
      }
      Invoke-HopEditor $f; return
    }
    'list' {
      foreach ($b in Get-HopBookmarks) { Write-Output "$($b.Cat)`t$($b.Name)`t$($b.Path)" }
      return
    }
    'ssh-edit' {
      $cfg = Get-HopSshConfigPath
      if (-not $cfg) { Write-Host 'hop: ssh_config is off in your settings'; return }
      if (-not (Test-Path -LiteralPath $cfg -PathType Leaf)) { Invoke-HopEditor $cfg; return }
      Invoke-HopEditor (Get-HopSshEditTarget $cfg); return
    }
    'ssh-import' {
      $cfg = Get-HopSshConfigPath
      if (-not $cfg) { Write-Host 'hop: ssh_config is off in your settings'; return }
      if (Test-Path -LiteralPath $cfg -PathType Leaf) { $cfg = Get-HopSshEditTarget $cfg }
      Import-HopSshConfig $cfg $query $piped; return
    }
  }

  $all = @(Get-HopBookmarks)
  if (-not $all.Count) {
    Write-Host "hop: no bookmarks in $script:SysDir or $script:UserDir. Run: hop --edit"; return
  }
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host 'hop: fzf is not on PATH (winget install junegunn.fzf)'; return
  }

  # --- layout -------------------------------------------------------------
  $cols = 0
  if ($env:HOP_COLS) { $cols = [int]$env:HOP_COLS }
  else { try { $cols = $Host.UI.RawUI.WindowSize.Width } catch {} }
  if (-not $cols) { $cols = 80 }
  # The preview costs half the width, so below 90 columns it starts hidden.
  # ^o toggles it either way. The path column is the first thing to go.
  $pvw = if ($cols -ge 90) { 'right,50%,border-left' } else { 'hidden,right,50%,border-left' }
  $showPath = $cols -ge 56

  # What tab walks: all, bookmarks, ssh when both kinds are present; the
  # categories when there is only one kind and so nothing else to switch.
  $hasSsh = [bool]($all | Where-Object { $_.Path.StartsWith('ssh://') } | Select-Object -First 1)
  $hasDir = [bool]($all | Where-Object { -not $_.Path.StartsWith('ssh://') } | Select-Object -First 1)
  $cycle = if ($hasSsh -and $hasDir) { @('@bookmarks', '@ssh') } else { @($all | ForEach-Object Cat | Select-Object -Unique) }

  # Rows for one filter. Column widths come from the whole set, not the
  # visible subset, so the list does not jitter as you filter or cycle.
  # Within the ssh section the ssh/ prefix is dropped from the category
  # column, since every row would carry it.
  $e = [char]27
  $st = @{ missing = 0 }
  $rowsFor = {
    param([string]$only)
    $cw = 0; $nw = 0
    foreach ($b in $all) {
      $c = $b.Cat; if ($only -eq '@ssh') { $c = $c -replace '^ssh/?', '' }
      if ($c.Length + 1 -gt $cw) { $cw = $c.Length + 1 }
      if ($b.Name.Length -gt $nw) { $nw = $b.Name.Length }
    }
    foreach ($b in $all) {
      $isSsh = $b.Path.StartsWith('ssh://')
      if (-not $isSsh -and -not (Test-Path -LiteralPath $b.Path)) {
        if (-not $showAll) { if ($only -eq '') { $st.missing++ }; continue }
      }
      if ($only -eq '@ssh' -and -not $isSsh) { continue }
      if ($only -eq '@bookmarks' -and $isSsh) { continue }
      if ($only -ne '' -and -not $only.StartsWith('@') -and $b.Cat -ne $only) { continue }
      $mark = if ($b.Pin) { '*' } else { ' ' }
      $c = $b.Cat; if ($only -eq '@ssh') { $c = $c -replace '^ssh/?', '' }
      if ($c) { $c += '/' }
      $pre  = if ($only -eq '' -or $only.StartsWith('@')) { "$e[2m{0,-$cw}$e[0m " -f $c } else { '' }
      $disp = if ($showPath) { ("{0,-$nw} $e[2m{1}$e[0m" -f $b.Name, (Get-HopShortPath $b.Path)) } else { $b.Name }
      $dest = if ($isSsh) { '' } else { Get-HopDestDir $b.Path }
      $kind = if ($isSsh) { 'ssh' } else { 'dir' }
      # Fields after the display: path, destination dir, category, name, kind.
      "$mark$pre$disp`t$($b.Path)`t$dest`t$($b.Cat)`t$($b.Name)`t$kind"
    }
  }
  $rows = @(& $rowsFor '')
  if (-not $rows.Count) { Write-Host 'hop: no bookmark path exists on this machine (try: hop --all)'; return }

  # Everything tab can show is rendered up front, so the key costs a `type`.
  $work = Join-Path ([IO.Path]::GetTempPath()) "hop-$PID"
  New-Item -ItemType Directory -Force $work | Out-Null
  [IO.File]::WriteAllLines((Join-Path $work 'rows0.txt'), [string[]]$rows, $script:Utf8)
  for ($i = 0; $i -lt $cycle.Count; $i++) {
    [IO.File]::WriteAllLines((Join-Path $work "rows$($i + 1).txt"), [string[]]@(& $rowsFor $cycle[$i]), $script:Utf8)
  }
  [IO.File]::WriteAllText((Join-Path $work 'state'), "0`n", $script:Utf8)
  $cycleCmd = Join-Path $work 'cycle.cmd'
  $previewCmd = Join-Path $work 'preview.cmd'
  [IO.File]::WriteAllText($cycleCmd, $script:CycleCmd, $script:Utf8)
  [IO.File]::WriteAllText($previewCmd, $script:PreviewCmd, $script:Utf8)
  $n = $cycle.Count + 1

  # The separator is spelled as a code point: a literal would turn into two
  # characters wherever the file is read as ANSI instead of UTF-8.
  $dot = [string][char]0xB7
  $hdr = if ($hasSsh -and $hasDir) { "tab bookmarks/ssh $dot " } else { "tab category $dot " }
  $hdr += if ($cols -ge 76) { "enter cd/ssh $dot ^e edit $dot ^a claude $dot ^u pull $dot ^p push $dot ^o preview" }
          else               { "enter cd/ssh $dot ^e edit $dot ^a claude" }
  if ($st.missing -gt 0) { $hdr += "`n$($st.missing) not here (--all)" }

  # `minimal = on` is shorthand for `header = off`; the explicit key still wins.
  $hdef = if ((Get-HopSetting minimal off) -eq 'on') { 'off' } else { 'on' }
  $info = 'inline'; $hdrArgs = @("--header=$hdr")
  if ((Get-HopSetting header $hdef) -eq 'off') { $info = 'hidden'; $hdrArgs = @() }

  $fzfArgs = @(
    '--ansi', '--layout=reverse', '--border', '--height=80%', "--info=$info",
    '--delimiter=\t', '--with-nth=1', '--nth=1',
    '--prompt=hop > ', "--query=$query",
    '--bind=ctrl-o:toggle-preview',
    "--bind=tab:reload(""$cycleCmd"" ""$work"" 1 $n)",
    "--bind=btab:reload(""$cycleCmd"" ""$work"" -1 $n)",
    '--expect=ctrl-a,ctrl-e,ctrl-u,ctrl-p',
    "--preview=""$previewCmd"" {6} {3} {5}", "--preview-window=$pvw"
  ) + $hdrArgs

  # Paths cross the pipe both ways, so both directions must agree on UTF-8.
  # The console default is the OEM code page, which mangles anything non-ASCII.
  $oldOut = [Console]::OutputEncoding; $oldPipe = $OutputEncoding
  $oldCfg = $env:HOP_SSHCFG
  try {
    [Console]::OutputEncoding = $script:Utf8
    $OutputEncoding = $script:Utf8
    $env:HOP_SSHCFG = Get-HopSshConfigPath
    $out = @($rows | fzf @fzfArgs)
  } finally {
    [Console]::OutputEncoding = $oldOut; $OutputEncoding = $oldPipe
    $env:HOP_SSHCFG = $oldCfg
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  }
  if ($out.Count -lt 2) { return }
  $key = $out[0]; $sel = $out[1]
  if (-not $sel) { return }

  $f = $sel -split "`t"
  $target = $f[1]; $dir = $f[2]; $name = $f[4]

  # An ssh host: connect, and stay where you were. The alias is the name; the
  # config supplies everything else. ^e opens the config, where the entry lives.
  if ($target.StartsWith('ssh://')) {
    switch ($key) {
      'ctrl-e' { Invoke-HopEditor (Get-HopSshEditTarget (Get-HopSshConfigPath)) }
      ''       { & ssh $name }
    }
    return
  }

  switch ($key) {
    'ctrl-a' {
      Enter-HopDir $dir
      if (Get-Command claude -ErrorAction SilentlyContinue) { claude } else { Write-Host 'hop: claude is not on PATH' }
      return
    }
    'ctrl-e' { Enter-HopDir $dir; Invoke-HopEditor $target; return }
    'ctrl-u' { Enter-HopDir $dir; git pull; return }
    'ctrl-p' { Enter-HopDir $dir; git push; return }
  }
  Enter-HopDir $dir
}

Export-ModuleMember -Function hop
