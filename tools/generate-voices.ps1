#requires -Version 5.1
[CmdletBinding()]
param([switch]$Missing)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$voiceArguments = @()
if ($Missing) { $voiceArguments += '--missing' }
& node (Join-Path $PSScriptRoot 'generate-voices.cjs') @voiceArguments
if ($LASTEXITCODE -ne 0) {
    throw "Neural voice generation failed with exit code $LASTEXITCODE."
}
