$ErrorActionPreference = 'Stop'

$checks = @(
    @{ Name = 'order-service readiness'; Url = 'http://localhost:8080/actuator/health/readiness' },
    @{ Name = 'inventory-worker readiness'; Url = 'http://localhost:8081/q/health/ready' },
    @{ Name = 'payment-worker readiness'; Url = 'http://localhost:8082/q/health/ready' },
    @{ Name = 'Keycloak realm'; Url = 'http://localhost:8083/realms/orderflow/.well-known/openid-configuration' }
)

foreach ($check in $checks) {
    $deadline = (Get-Date).AddMinutes(4)
    do {
        try {
            $response = Invoke-WebRequest -Uri $check.Url -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Host "OK: $($check.Name)"
                break
            }
        }
        catch {
            if ((Get-Date) -ge $deadline) {
                throw "Timed out waiting for $($check.Name) at $($check.Url)"
            }
            Start-Sleep -Seconds 5
        }
    } while ((Get-Date) -lt $deadline)
}

$platformRoot = Split-Path -Parent $PSScriptRoot
$topics = docker compose --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 --list
$expectedTopics = @(
    'orderflow-inventory-commands',
    'orderflow-inventory-events',
    'orderflow-payment-commands',
    'orderflow-payment-events'
)

foreach ($topic in $expectedTopics) {
    if ($topics -notcontains $topic) {
        throw "Kafka topic was not provisioned: $topic"
    }
}

Write-Host 'OK: Kafka topics'

$databaseChecks = @(
    @{ Name = 'order-service migration'; User = 'order_service'; Database = 'orderflow_orders' },
    @{ Name = 'inventory-worker migration'; User = 'inventory_worker'; Database = 'orderflow_inventory' },
    @{ Name = 'payment-worker migration'; User = 'payment_worker'; Database = 'orderflow_payments' }
)

foreach ($check in $databaseChecks) {
    $migrationCount = docker compose --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T postgres psql --username $check.User --dbname $check.Database --tuples-only --no-align --command 'SELECT COUNT(*) FROM flyway_schema_history WHERE success;'
    if (($LASTEXITCODE -ne 0) -or ($migrationCount.Trim() -ne '1')) {
        throw "Flyway migration was not applied for $($check.Name)"
    }
}

Write-Host 'OK: Flyway migrations'

docker compose --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T postgres psql --username order_service --dbname orderflow_inventory --command 'SELECT 1;' 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    throw 'Database isolation failed: order_service connected to orderflow_inventory'
}

Write-Host 'OK: database access isolation'
