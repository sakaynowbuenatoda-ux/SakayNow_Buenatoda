param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function New-NotificationWave {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [array]$Segments
    )

    $sampleRate = 22050
    $channels = 1
    $bitsPerSample = 16
    $samples = [System.Collections.Generic.List[Int16]]::new()

    foreach ($segment in $Segments) {
        $frequency = [double]$segment.Frequency
        $duration = [double]$segment.Duration
        $sampleCount = [Math]::Max(1, [int][Math]::Round($duration * $sampleRate))
        $attack = [Math]::Min(0.018, $duration / 3)
        $release = [Math]::Min(0.045, $duration / 2)

        for ($index = 0; $index -lt $sampleCount; $index += 1) {
            if ($frequency -le 0) {
                $samples.Add(0)
                continue
            }

            $time = $index / $sampleRate
            $remaining = $duration - $time
            $envelope = [Math]::Min(
                1.0,
                [Math]::Min($time / $attack, $remaining / $release)
            )
            $fundamental = [Math]::Sin(2 * [Math]::PI * $frequency * $time)
            $harmonic = 0.18 * [Math]::Sin(
                2 * [Math]::PI * ($frequency * 2) * $time
            )
            $value = 0.24 * $envelope * ($fundamental + $harmonic)
            $sample = [Math]::Max(
                [Int16]::MinValue,
                [Math]::Min([Int16]::MaxValue, [int]($value * 32767))
            )
            $samples.Add([Int16]$sample)
        }
    }

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $dataLength = $samples.Count * ($bitsPerSample / 8)
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $dataLength))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
        $writer.Write([int]16)
        $writer.Write([Int16]1)
        $writer.Write([Int16]$channels)
        $writer.Write([int]$sampleRate)
        $writer.Write([int]($sampleRate * $channels * ($bitsPerSample / 8)))
        $writer.Write([Int16]($channels * ($bitsPerSample / 8)))
        $writer.Write([Int16]$bitsPerSample)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]$dataLength)
        foreach ($sample in $samples) {
            $writer.Write($sample)
        }
        $writer.Flush()
        [IO.File]::WriteAllBytes($Path, $stream.ToArray())
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

$soundDefinitions = @{
    'sakaynow_message' = @(
        @{ Frequency = 880; Duration = 0.10 },
        @{ Frequency = 0; Duration = 0.035 },
        @{ Frequency = 1175; Duration = 0.14 }
    )
    'sakaynow_booking_accepted' = @(
        @{ Frequency = 523; Duration = 0.11 },
        @{ Frequency = 659; Duration = 0.11 },
        @{ Frequency = 784; Duration = 0.18 }
    )
    'sakaynow_driver_arrived' = @(
        @{ Frequency = 740; Duration = 0.16 },
        @{ Frequency = 0; Duration = 0.045 },
        @{ Frequency = 988; Duration = 0.22 }
    )
    'sakaynow_booking_request' = @(
        @{ Frequency = 659; Duration = 0.12 },
        @{ Frequency = 0; Duration = 0.045 },
        @{ Frequency = 659; Duration = 0.12 },
        @{ Frequency = 0; Duration = 0.045 },
        @{ Frequency = 880; Duration = 0.20 }
    )
}

$androidDirectory = Join-Path $RepositoryRoot 'android/app/src/main/res/raw'
$iosDirectory = Join-Path $RepositoryRoot 'ios/Runner/Sounds'
New-Item -ItemType Directory -Force -Path $androidDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $iosDirectory | Out-Null

foreach ($entry in $soundDefinitions.GetEnumerator()) {
    $fileName = "$($entry.Key).wav"
    $androidPath = Join-Path $androidDirectory $fileName
    $iosPath = Join-Path $iosDirectory $fileName
    New-NotificationWave -Path $androidPath -Segments $entry.Value
    Copy-Item -LiteralPath $androidPath -Destination $iosPath -Force
}

Write-Output "Generated $($soundDefinitions.Count) Android and iOS notification sounds."
