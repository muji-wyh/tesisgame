#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# System.Speech uses the installed Windows desktop voices, not a network service.
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        throw 'Windows PowerShell 5.1 is required to generate the prerecorded voices.'
    }
    & $windowsPowerShell -NoLogo -NoProfile -NonInteractive -File $PSCommandPath
    if ($LASTEXITCODE -ne 0) {
        throw "Windows PowerShell voice generation failed with exit code $LASTEXITCODE."
    }
    return
}
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'Run this generator with Windows PowerShell 5.1.'
}

function Assert-EnglishText {
    param([object]$Text, [string]$Label)
    if ($Text -isnot [string] -or
        -not [regex]::IsMatch($Text, '\A[A-Za-z][A-Za-z0-9 ,.!?''-]*\z')) {
        throw "$Label must be a nonempty ASCII English string with ordinary punctuation."
    }
}

function Assert-VoiceId {
    param([object]$Id)
    if ($Id -isnot [string] -or -not [regex]::IsMatch($Id, '\A[a-z]+(?:-[a-z]+)*\z')) {
        throw 'Voice IDs must contain only lowercase ASCII words separated by hyphens.'
    }
}

$root = Split-Path -Parent $PSScriptRoot
$promptPath = Join-Path $root 'voice-prompts.json'
$wordPath = Join-Path $root 'words.json'
$outputDirectory = Join-Path $root 'assets\audio\voice'
$prompts = Get-Content -LiteralPath $promptPath -Raw -Encoding UTF8 | ConvertFrom-Json
$words = Get-Content -LiteralPath $wordPath -Raw -Encoding UTF8 | ConvertFrom-Json
$expectedPromptIds = @(
    'welcome', 'correct', 'wrong', 'loss',
    'spring-theme', 'summer-theme', 'autumn-theme', 'winter-theme',
    'spring-arrive', 'summer-arrive', 'autumn-arrive', 'winter-arrive',
    'spring-open', 'summer-open', 'autumn-open', 'winter-open'
)
if ($prompts -isnot [pscustomobject]) {
    throw 'voice-prompts.json must be an object of prompt IDs and English strings.'
}
$actualPromptIds = @($prompts.PSObject.Properties | ForEach-Object { $_.Name })
if ($actualPromptIds.Count -ne $expectedPromptIds.Count) {
    throw 'voice-prompts.json must contain exactly the sixteen required prompt IDs.'
}
foreach ($id in $expectedPromptIds) {
    if ($actualPromptIds -cnotcontains $id) {
        throw "Missing required voice prompt: $id"
    }
}
if ($words -isnot [array] -or $words.Count -eq 0) {
    throw 'words.json must be a nonempty vocabulary array.'
}

$messages = [System.Collections.Generic.List[object]]::new()
$seenIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($property in $prompts.PSObject.Properties) {
    Assert-VoiceId $property.Name
    Assert-EnglishText $property.Value "Prompt '$($property.Name)'"
    if (-not $seenIds.Add($property.Name)) {
        throw "Duplicate voice ID: $($property.Name)"
    }
    $messages.Add([pscustomobject]@{ Id = $property.Name; Text = $property.Value })
}
foreach ($word in $words) {
    if ($null -eq $word -or $word -isnot [pscustomobject] -or
        $word.PSObject.Properties.Name -notcontains 'id' -or
        $word.PSObject.Properties.Name -notcontains 'text' -or
        $word.PSObject.Properties.Name -notcontains 'audio') {
        throw 'Every vocabulary entry must provide id, text, and audio.'
    }
    Assert-VoiceId $word.id
    Assert-EnglishText $word.text "Vocabulary '$($word.id)'"
    $id = "word-$($word.id)"
    if ($word.audio -cne "assets/audio/voice/$id.wav") {
        throw "Unexpected audio path for vocabulary '$($word.id)'."
    }
    if (-not $seenIds.Add($id)) {
        throw "Duplicate voice ID: $id"
    }
    $messages.Add([pscustomobject]@{ Id = $id; Text = $word.text })
}
foreach ($message in $messages) {
    $pending = Join-Path $outputDirectory "$($message.Id).generating.wav"
    $destination = Join-Path $outputDirectory "$($message.Id).wav"
    if (Test-Path -LiteralPath $pending) {
        throw "Pending output already exists: $pending. Diagnose it before removing only that exact file."
    }
    if ((Test-Path -LiteralPath $destination) -and
        -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        throw "Voice destination is not a regular file: $destination"
    }
}

Add-Type -AssemblyName System.Speech
$synthesizer = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    $voiceName = 'Microsoft Zira Desktop'
    $installed = @($synthesizer.GetInstalledVoices() | Where-Object {
        $_.Enabled -and $_.VoiceInfo.Name -ceq $voiceName -and $_.VoiceInfo.Culture.Name -ceq 'en-US'
    })
    if ($installed.Count -eq 0) {
        throw "Required enabled en-US voice '$voiceName' is missing. No alternative voice will be used."
    }
    $synthesizer.SelectVoice($voiceName)
    $synthesizer.Rate = -1
    $synthesizer.Volume = 85
    $format = [System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(
        22050,
        [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
        [System.Speech.AudioFormat.AudioChannel]::Mono
    )
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

    foreach ($message in $messages) {
        $pending = Join-Path $outputDirectory "$($message.Id).generating.wav"
        $destination = Join-Path $outputDirectory "$($message.Id).wav"
        try {
            $synthesizer.SetOutputToWaveFile($pending, $format)
            $synthesizer.Speak($message.Text)
        }
        finally {
            $synthesizer.SetOutputToNull()
        }
        $bytes = [System.IO.File]::ReadAllBytes($pending)
        if ($bytes.Length -le 1000 -or
            [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -cne 'RIFF' -or
            [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4) -cne 'WAVE') {
            throw "Invalid generated voice WAV: $pending. The final output has not been replaced."
        }
        Move-Item -LiteralPath $pending -Destination $destination -Force
    }
    Write-Host "Generated $($messages.Count) English voice WAVs with $voiceName (22050 Hz, PCM16 mono, rate -1, volume 85)."
}
finally {
    $synthesizer.Dispose()
}
