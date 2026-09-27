param(
    [string]$ProjectName = 'orderflow'
)

$ErrorActionPreference = 'Stop'

function Invoke-ExpectedErrorResponse {
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [string]$Body
    )

    try {
        $response = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $Body -UseBasicParsing
        return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = $response.Content }
    }
    catch {
        $response = $_.Exception.Response
        if ($null -eq $response) {
            throw
        }

        if (($null -ne $response.Content) -and ($response.Content.PSObject.Methods.Name -contains 'ReadAsStringAsync')) {
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
        else {
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            try {
                $content = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
        }

        return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = $content }
    }
}

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
$topics = docker compose --project-name $ProjectName --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 --list
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
    @{ Name = 'order-service migration'; User = 'order_service'; Database = 'orderflow_orders'; ExpectedCount = '2' },
    @{ Name = 'inventory-worker migration'; User = 'inventory_worker'; Database = 'orderflow_inventory'; ExpectedCount = '1' },
    @{ Name = 'payment-worker migration'; User = 'payment_worker'; Database = 'orderflow_payments'; ExpectedCount = '1' }
)

foreach ($check in $databaseChecks) {
    $migrationCount = docker compose --project-name $ProjectName --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T postgres psql --username $check.User --dbname $check.Database --tuples-only --no-align --command 'SELECT COUNT(*) FROM flyway_schema_history WHERE success;'
    if (($LASTEXITCODE -ne 0) -or ($migrationCount.Trim() -ne $check.ExpectedCount)) {
        throw "Flyway migration was not applied for $($check.Name)"
    }
}

Write-Host 'OK: Flyway migrations'

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
docker compose --project-name $ProjectName --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T postgres psql --username order_service --dbname orderflow_inventory --command 'SELECT 1;' 2>$null | Out-Null
$databaseIsolationExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($databaseIsolationExitCode -eq 0) {
    throw 'Database isolation failed: order_service connected to orderflow_inventory'
}

Write-Host 'OK: database access isolation'

$tokenResponse = Invoke-RestMethod -Method Post -Uri 'http://localhost:8083/realms/orderflow/protocol/openid-connect/token' -ContentType 'application/x-www-form-urlencoded' -Body @{
    grant_type = 'password'
    client_id = 'orderflow-api'
    username = 'customer.demo'
    password = 'orderflow_customer_dev'
}

if ([string]::IsNullOrWhiteSpace($tokenResponse.access_token)) {
    throw 'Keycloak did not issue an access token for the local customer'
}

$idempotencyKey = "smoke-$([guid]::NewGuid())"
$correlationId = [guid]::NewGuid().ToString()
$headers = @{
    Authorization = "Bearer $($tokenResponse.access_token)"
    'Idempotency-Key' = $idempotencyKey
    'X-Correlation-Id' = $correlationId
}
$orderRequest = @{
    items = @(
        @{ productId = '22222222-2222-4222-8222-222222222221'; quantity = 1 },
        @{ productId = '22222222-2222-4222-8222-222222222221'; quantity = 2 },
        @{ productId = '22222222-2222-4222-8222-222222222222'; quantity = 1 }
    )
} | ConvertTo-Json -Depth 4

$createResponse = Invoke-WebRequest -Method Post -Uri 'http://localhost:8080/api/v1/orders' -Headers $headers -ContentType 'application/json' -Body $orderRequest -UseBasicParsing
$createdOrder = $createResponse.Content | ConvertFrom-Json
if (($createResponse.StatusCode -ne 201) -or [string]::IsNullOrWhiteSpace($createResponse.Headers.Location) -or ($createdOrder.status -ne 'INVENTORY_PENDING')) {
    throw 'Order creation did not return the expected 201 response, Location header and INVENTORY_PENDING status'
}

$replayResponse = Invoke-WebRequest -Method Post -Uri 'http://localhost:8080/api/v1/orders' -Headers $headers -ContentType 'application/json' -Body $orderRequest -UseBasicParsing
$replayedOrder = $replayResponse.Content | ConvertFrom-Json
if (($replayResponse.StatusCode -ne 201) -or ($replayedOrder.orderId -ne $createdOrder.orderId) -or ($replayResponse.Content -ne $createResponse.Content)) {
    throw 'Equivalent idempotent retry did not return the original order response'
}

$conflictingRequest = @{
    items = @(
        @{ productId = '22222222-2222-4222-8222-222222222221'; quantity = 4 }
    )
} | ConvertTo-Json -Depth 4
$conflictResponse = Invoke-ExpectedErrorResponse -Uri 'http://localhost:8080/api/v1/orders' -Headers $headers -Body $conflictingRequest
if ($conflictResponse.StatusCode -ne 409) {
    throw "Conflicting idempotency key returned HTTP $($conflictResponse.StatusCode) instead of 409"
}

$invalidHeaders = @{
    Authorization = "Bearer $($tokenResponse.access_token)"
    'Idempotency-Key' = "smoke-invalid-$([guid]::NewGuid())"
    'X-Correlation-Id' = [guid]::NewGuid().ToString()
}
$invalidRequest = @{
    items = @(
        @{ productId = '22222222-2222-4222-8222-222222222223'; quantity = 1 },
        @{ productId = '22222222-2222-4222-8222-222222222299'; quantity = 1 }
    )
} | ConvertTo-Json -Depth 4
$invalidHttpResponse = Invoke-ExpectedErrorResponse -Uri 'http://localhost:8080/api/v1/orders' -Headers $invalidHeaders -Body $invalidRequest
$invalidResponse = $invalidHttpResponse.Content | ConvertFrom-Json
$invalidProductIds = @($invalidResponse.invalidProductIds)
if (($invalidHttpResponse.StatusCode -ne 422) -or ($invalidProductIds.Count -ne 2) -or ($invalidProductIds -notcontains '22222222-2222-4222-8222-222222222223') -or ($invalidProductIds -notcontains '22222222-2222-4222-8222-222222222299')) {
    throw 'Invalid product validation did not return HTTP 422 with every invalid product id'
}

$outboxCount = docker compose --project-name $ProjectName --project-directory $platformRoot -f (Join-Path $platformRoot 'compose.yml') exec -T postgres psql --username order_service --dbname orderflow_orders --tuples-only --no-align --command "SELECT COUNT(*) FROM outbox_messages WHERE aggregate_id = '$($createdOrder.orderId)';"
if (($LASTEXITCODE -ne 0) -or ($outboxCount.Trim() -ne '1')) {
    throw 'Order creation did not persist exactly one atomic outbox message'
}

Write-Host 'OK: authenticated idempotent order creation, validation and transactional outbox'
