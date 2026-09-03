# Installs hop for PowerShell: fzf if missing, a seed bookmarks file, and an
# Import-Module line in your profile so `hop` is a function in every session.
#
#   git clone https://github.com/yatahaze/hop.git $HOME\hop; & $HOME\hop\install.ps1
#
# The profile line is delimited with markers so re-running this replaces the
# block instead of appending a second copy, and removing it is one edit.
$ErrorActionPreference = 'Stop'

$Src = $PSScriptRoot
$ConfigDir = Join-Path $env:APPDATA 'hop'

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'installing fzf with winget'
    winget install --id junegunn.fzf -e --accept-source-agreements --accept-package-agreements
    # winget puts it on PATH for new sessions, not this one.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
  }
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host 'hop needs fzf on PATH: https://github.com/junegunn/fzf#windows'
    exit 1
  }
}

New-Item -ItemType Directory -Force $ConfigDir | Out-Null
$bm = Join-Path $ConfigDir 'bookmarks'
if (-not (Test-Path -LiteralPath $bm)) {
  # The shared example is unix-shaped; seed something that exists here.
  @"
# hop bookmarks. One per line, grouped under [category] headers.
#
#   name    path          explicit name
#   path                  name defaults to the last path component
#
# ~ and `$HOME are expanded. Nothing else is: this file is read, never eval'd.
# / and \ both work. Bookmarks whose path doesn't exist on this machine are
# hidden (the count shows in the header; ``hop --all`` reveals them).
#
# Categories are yours to invent. They are just the filter prefix.
# Prefix a name with * to pin it to the top.

[repos]
hop             $Src

[configs]
*claude         ~/.claude
powershell      $(Split-Path -Parent $PROFILE)
"@ | Set-Content -LiteralPath $bm -Encoding utf8
  Write-Host "seeded $bm"
} else {
  Write-Host "kept existing $bm"
}

# The module is imported by absolute path, so nothing depends on PSModulePath.
$block = @(
  '# >>> hop >>>'
  "Import-Module `"$(Join-Path $Src 'hop.psm1')`""
  '# <<< hop <<<'
)
$rc = $PROFILE
New-Item -ItemType Directory -Force (Split-Path -Parent $rc) | Out-Null
[string[]]$lines = @()
if (Test-Path -LiteralPath $rc) { $lines = @(Get-Content -LiteralPath $rc) }
$start = [array]::IndexOf($lines, '# >>> hop >>>')
$end   = [array]::IndexOf($lines, '# <<< hop <<<')
if ($start -ge 0 -and $end -ge $start) {
  $before = if ($start -gt 0) { $lines[0..($start - 1)] } else { @() }
  $after  = if ($end -lt $lines.Count - 1) { $lines[($end + 1)..($lines.Count - 1)] } else { @() }
  $lines = @($before) + $block + @($after)
  Write-Host "replaced existing hop block in $rc"
} else {
  if ($lines.Count -and $lines[-1] -ne '') { $lines += '' }
  $lines += $block
  Write-Host "added hop block to $rc"
}
Set-Content -LiteralPath $rc -Value $lines -Encoding utf8

Write-Host
Write-Host 'done. Open a new PowerShell (or: . $PROFILE) and run: hop'
