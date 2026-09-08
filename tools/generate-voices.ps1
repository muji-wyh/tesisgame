#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& node (Join-Path $PSScriptRoot 'generate-voices.cjs')
if ($LASTEXITCODE -ne 0) {
    throw "Neural voice generation failed with exit code $LASTEXITCODE."
}
