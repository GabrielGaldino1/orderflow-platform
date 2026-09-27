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
    Write-Host "Packaging $repository"
    Push-Location $repositoryRoot
    try {
        & .\mvnw.cmd clean package '-DskipTests'
        if ($LASTEXITCODE -ne 0) {
            throw "Packaging failed for $repository"
        }
    }
    finally {
        Pop-Location
    }
}

docker compose --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') up --detach --build
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose startup failed'
}

& (Join-Path $PSScriptRoot 'smoke-test.ps1')
