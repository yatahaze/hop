# hop for PowerShell: a bookmark picker for the directories you actually work in.
#
# The bash version prints a path and a shell function turns it into a `cd`,
# because a child process cannot move its parent. A PowerShell function runs in
# the caller's session and can call Set-Location directly, so here the function
# is the whole program. install.ps1 imports this module from your profile.
#
# Same bookmarks format, same merge order as the bash version, with
# $env:ProgramData\hop standing in for /etc/hop and $env:APPDATA\hop for
# ~/.config/hop. Not ported: the category column and tab cycling, which work by
# fzf re-invoking the script on every keypress. pwsh takes a few hundred
# milliseconds to start, so that would feel sluggish; the category is a
# filterable prefix instead, and `hop web` still narrows.

$script:SysDir  = Join-Path $env:ProgramData 'hop'
$script:UserDir = Join-Path $env:APPDATA 'hop'

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
    # accepts but displays badly next to $HOME's backslashes.
    $path = $path.Replace('/', '\')

    [pscustomobject]@{ Pin = $pin; Cat = $cat; Name = $name; Path = $path }
  }
}

# Later sources override the same category/name in place and leave the rest
# alone, so a personal file can repoint one system entry without masking the
# other fifty. Pinned entries sort first, file order within each group.
function Get-HopBookmarks {
  $merged = [ordered]@{}
  foreach ($f in Get-HopSources) {
    foreach ($b in Read-HopFile $f) { $merged["$($b.Cat)`t$($b.Name)"] = $b }
  }
  $all = @($merged.Values)
  @($all | Where-Object Pin) + @($all | Where-Object { -not $_.Pin })
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

# A bookmark may point at a file; you hop to its directory.
function Get-HopDestDir([string]$p) {
  if (Test-Path -LiteralPath $p -PathType Container) { $p } else { Split-Path -Parent $p }
}

function Get-HopShortPath([string]$p) {
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

function Write-HopUsage {
  Write-Host @'
hop [--all] [query]     pick a bookmark and cd there
hop --edit              open your bookmarks file in $env:EDITOR
hop --list              print bookmarks as category<TAB>name<TAB>path

In the picker:
  type              filter, category names match too (`hop web` pre-types it)
  enter             cd there
  ^a claude    ^e edit    ^u git pull    ^p git push    ^o toggle preview

Bookmarks: $env:APPDATA\hop\bookmarks (yours) merged over
$env:ProgramData\hop\bookmarks (system wide), plus bookmarks.d\*.conf beside each.
'@
}

function hop {
  $showAll = $false; $query = @()
  foreach ($a in $args) {
    switch ($a) {
      '--all'  { $showAll = $true }
      '--help' { Write-HopUsage; return }
      '-h'     { Write-HopUsage; return }
      '--edit' {
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
        $ed = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
        $exe, $edArgs = $ed -split ' '
        & $exe @edArgs $f
        return
      }
      '--list' {
        foreach ($b in Get-HopBookmarks) { Write-Output "$($b.Cat)`t$($b.Name)`t$($b.Path)" }
        return
      }
      default  { $query += $a }
    }
  }
  $query = $query -join ' '

  if (-not (Get-HopSources)) {
    Write-Host "hop: no bookmarks in $script:SysDir or $script:UserDir. Run: hop --edit"; return
  }
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host 'hop: fzf is not on PATH (winget install junegunn.fzf)'; return
  }

  $all = @(Get-HopBookmarks)
  # Column widths come from the whole set, not the visible subset, so the list
  # does not jitter as you filter.
  $cw = 0; $nw = 0
  foreach ($b in $all) {
    if ($b.Cat.Length + 1 -gt $cw) { $cw = $b.Cat.Length + 1 }
    if ($b.Name.Length -gt $nw)    { $nw = $b.Name.Length }
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

  $e = [char]27
  $rows = [Collections.Generic.List[string]]::new()
  $missing = 0
  foreach ($b in $all) {
    if (-not (Test-Path -LiteralPath $b.Path)) { if (-not $showAll) { $missing++; continue } }
    $mark = if ($b.Pin) { '*' } else { ' ' }
    $pre  = ("$e[2m{0,-$cw}$e[0m " -f ($b.Cat + '/'))
    $disp = if ($showPath) { ("{0,-$nw} $e[2m{1}$e[0m" -f $b.Name, (Get-HopShortPath $b.Path)) } else { $b.Name }
    $dest = Get-HopDestDir $b.Path
    # Fields after the display: path, destination dir, category, name.
    $rows.Add("$mark$pre$disp`t$($b.Path)`t$dest`t$($b.Cat)`t$($b.Name)")
  }
  if (-not $rows.Count) { Write-Host 'hop: no bookmark path exists on this machine (try: hop --all)'; return }

  $hdr = if ($cols -ge 62) { 'enter cd · ^e edit · ^a claude · ^u pull · ^p push · ^o preview' }
         else              { 'enter cd · ^e edit · ^a claude' }
  if ($missing -gt 0) { $hdr += "`n$missing not here (--all)" }

  # `minimal = on` is shorthand for `header = off`; the explicit key still wins.
  $hdef = if ((Get-HopSetting minimal off) -eq 'on') { 'off' } else { 'on' }
  $info = 'inline'; $hdrArgs = @("--header=$hdr")
  if ((Get-HopSetting header $hdef) -eq 'off') { $info = 'hidden'; $hdrArgs = @() }

  # fzf runs the preview through cmd.exe on Windows. git only, no pwsh, so it
  # stays fast. {3} is the destination directory; fzf quotes it.
  $preview = 'git -C {3} -c color.ui=always status -sb 2>nul && echo. && git -C {3} -c color.ui=always log --oneline -5 2>nul & echo. & dir /b {3} 2>nul'

  $fzfArgs = @(
    '--ansi', '--layout=reverse', '--border', '--height=80%', "--info=$info",
    '--delimiter=\t', '--with-nth=1', '--nth=1',
    '--prompt=hop > ', "--query=$query",
    '--bind=ctrl-o:toggle-preview',
    '--expect=ctrl-a,ctrl-e,ctrl-u,ctrl-p',
    "--preview=$preview", "--preview-window=$pvw"
  ) + $hdrArgs

  # Paths cross the pipe both ways, so both directions must agree on UTF-8.
  # The console default is the OEM code page, which mangles anything non-ASCII.
  $oldOut = [Console]::OutputEncoding; $oldPipe = $OutputEncoding
  try {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $out = @($rows | fzf @fzfArgs)
  } finally {
    [Console]::OutputEncoding = $oldOut; $OutputEncoding = $oldPipe
  }
  if ($out.Count -lt 2) { return }
  $key = $out[0]; $sel = $out[1]
  if (-not $sel) { return }

  $f = $sel -split "`t"
  $target = $f[1]; $dir = $f[2]

  switch ($key) {
    'ctrl-a' {
      Enter-HopDir $dir
      if (Get-Command claude -ErrorAction SilentlyContinue) { claude } else { Write-Host 'hop: claude is not on PATH' }
      return
    }
    'ctrl-e' {
      $ed = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
      $exe, $edArgs = $ed -split ' '
      Enter-HopDir $dir
      & $exe @edArgs $target
      return
    }
    'ctrl-u' { Enter-HopDir $dir; git pull; return }
    'ctrl-p' { Enter-HopDir $dir; git push; return }
  }
  Enter-HopDir $dir
}

Export-ModuleMember -Function hop
