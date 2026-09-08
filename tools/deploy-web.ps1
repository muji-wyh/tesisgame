#requires -Version 5.1
[CmdletBinding()]
param([switch]$SkipBuild)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$subscription = '2909b61b-7489-445e-9039-2fd51429745b'
$hostname = 'gentle-forest-02ff42900.3.azurestaticapps.net'
$previousToken = [Environment]::GetEnvironmentVariable('SWA_CLI_DEPLOYMENT_TOKEN', 'Process')
$token = $null

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $null = Get-Command npm, az, swa
    if (-not $SkipBuild) {
        & npm run build:web
        if ($LASTEXITCODE -ne 0) {
            throw "Web build failed with exit code $LASTEXITCODE. Nothing was deployed."
        }
    }

    foreach ($file in @('.\build\web\index.html', '.\build\web\staticwebapp.config.json')) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Missing Web export file: $file. Run npm run build:web first."
        }
    }

    $targetJson = & az staticwebapp show --subscription $subscription `
        --name tesisgame --resource-group rg-footises --output json --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw 'The Azure app could not be read. Sign in with az login for the personal subscription.'
    }
    $target = $targetJson | ConvertFrom-Json
    if ($target.defaultHostname -ne $hostname) {
        throw 'The Azure app hostname does not match the configured production target. Nothing was deployed.'
    }

    $token = & az staticwebapp secrets list --subscription $subscription `
        --name tesisgame --resource-group rg-footises `
        --query properties.apiKey --output tsv --only-show-errors
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw 'The Azure deployment token is unavailable. Nothing was deployed.'
    }
    $env:SWA_CLI_DEPLOYMENT_TOKEN = $token.Trim()
    Write-Host "Deploying tesisgame to https://$hostname"
    & swa deploy .\build\web --swa-config-location .\web --env production
    if ($LASTEXITCODE -ne 0) {
        throw "Azure deployment failed with exit code $LASTEXITCODE."
    }
} finally {
    [Environment]::SetEnvironmentVariable('SWA_CLI_DEPLOYMENT_TOKEN', $previousToken, 'Process')
    $token = $null
    Pop-Location
}
