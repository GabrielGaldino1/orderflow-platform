$ErrorActionPreference = 'Stop'

$platformRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $platformRoot
$repositories = @(
    'orderflow-order-service',
    'orderflow-inventory-worker',
    'orderflow-payment-worker'
)

foreach ($repository in $repositories) {
    $repositoryRoot = Join-Path $workspaceRoot $repository
    Write-Host "Building $repository"
    Push-Location $repositoryRoot
    try {
        & .\mvnw.cmd clean verify
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed for $repository"
        }
    }
    finally {
        Pop-Location
    }
}
