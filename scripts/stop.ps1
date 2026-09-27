param(
    [switch]$PurgeVolumes
)

$ErrorActionPreference = 'Stop'
$platformRoot = Split-Path -Parent $PSScriptRoot
$arguments = @('compose', '--project-directory', $platformRoot, '-f', (Join-Path $platformRoot 'compose.yml'), 'down')

if ($PurgeVolumes) {
    $arguments += '--volumes'
}

& docker $arguments
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose shutdown failed'
}
