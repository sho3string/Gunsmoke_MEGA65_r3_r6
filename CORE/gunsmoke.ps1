param(
    [string]$MameZip = '',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($MameZip)) { $MameZip = Join-Path $ScriptDir 'GUNSMOKE.ZIP' }
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $ScriptDir 'arcade\gunsmoke' }
$MameZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MameZip)
$OutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Chip {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$Name, [int]$Size)
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Missing MAME ROM chip: $Name" }
    if ($entry.Length -ne $Size) { throw "Incorrect chip size for ${Name}: expected $Size, got $($entry.Length)" }
    $stream = $entry.Open()
    $memory = New-Object System.IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        return ,([byte[]]$memory.ToArray())
    } finally {
        $stream.Dispose()
        $memory.Dispose()
    }
}

function Join-Bytes {
    param([byte[][]]$Parts)
    $total = 0
    foreach ($part in $Parts) { $total += $part.Length }
    $result = New-Object byte[] $total
    $offset = 0
    foreach ($part in $Parts) {
        [Array]::Copy($part, 0, $result, $offset, $part.Length)
        $offset += $part.Length
    }
    return ,$result
}

function Swap-Pairs {
    param([byte[]]$Data)
    if (($Data.Length % 2) -ne 0) { throw 'Cannot swap odd-length ROM' }
    $result = New-Object byte[] $Data.Length
    for ($i = 0; $i -lt $Data.Length; $i += 2) {
        $result[$i] = $Data[$i + 1]
        $result[$i + 1] = $Data[$i]
    }
    return ,$result
}

function Interleave-Chips {
    param([byte[]]$Even, [byte[]]$Odd)
    if ($Even.Length -ne $Odd.Length) { throw 'Interleaved ROM chips have different sizes' }
    $result = New-Object byte[] ($Even.Length * 2)
    for ($i = 0; $i -lt $Even.Length; $i++) {
        $result[2 * $i] = $Even[$i]
        $result[2 * $i + 1] = $Odd[$i]
    }
    return ,$result
}

function Sort-Graphics {
    param([byte[]]$Data, [int]$Mask, [int]$HighBit, [int]$Shift)
    $result = New-Object byte[] $Data.Length
    for ($i = 0; $i -lt $Data.Length; $i++) {
        $j = ($i -band (-bnot $Mask)) -bor (($i -band $HighBit) -shr $Shift) -bor (($i -band ($Mask -bxor $HighBit)) -shl 1)
        $result[$j] = $Data[$i]
    }
    return ,$result
}

function Write-Rom {
    param([string]$Part, [byte[]]$Data)
    $name = "gunsmoke_$Part.rom"
    [System.IO.File]::WriteAllBytes((Join-Path $OutputDir $name), $Data)
    # Signed 64-bit arithmetic avoids PowerShell 5.1 UInt32 overflow/conversion errors.
    [long]$crc = 4294967295
    foreach ($b in $Data) {
        $crc = $crc -bxor [long]$b
        for ($k = 0; $k -lt 8; $k++) {
            if (($crc -band 1) -ne 0) {
                $crc = ($crc -shr 1) -bxor ([long]3988292384)
            } else {
                $crc = $crc -shr 1
            }
        }
    }
    $crc = $crc -bxor ([long]4294967295)
    Write-Host ('{0,-24} {1,7} bytes  CRC32 {2:X8}' -f $name, $Data.Length, $crc)
}

if (-not (Test-Path -LiteralPath $MameZip -PathType Leaf)) { throw "Missing MAME ZIP: $MameZip" }
[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$archive = [System.IO.Compression.ZipFile]::OpenRead($MameZip)
try {
    $main = Join-Bytes @(
        (Get-Chip $archive '09n_gs03.bin' 32768),
        (Get-Chip $archive '10n_gs04.bin' 32768),
        (Get-Chip $archive '12n_gs05.bin' 32768)
    )
    Write-Rom 'main' $main
    Write-Rom 'sound' (Get-Chip $archive '14h_gs02.bin' 32768)
    Write-Rom 'char' (Swap-Pairs (Get-Chip $archive '11f_gs01.bin' 16384))
    $map = Swap-Pairs (Get-Chip $archive '11c_gs14.bin' 32768)
    Write-Rom 'map' (Sort-Graphics $map 0x1e 0x10 3) # hvvvx

    $screenParts = (New-Object 'System.Collections.Generic.List[byte[]]')
    foreach ($pair in @(
        @('06a_gs09.bin', '06c_gs13.bin'),
        @('05a_gs08.bin', '05c_gs12.bin'),
        @('04a_gs07.bin', '04c_gs11.bin'),
        @('02a_gs06.bin', '02c_gs10.bin')
    )) {
        $screenParts.Add((Interleave-Chips (Get-Chip $archive $pair[0] 32768) (Get-Chip $archive $pair[1] 32768)))
    }
    Write-Rom 'scr' (Join-Bytes $screenParts.ToArray())

    $objectParts = (New-Object 'System.Collections.Generic.List[byte[]]')
    foreach ($pair in @(
        @('06l_gs18.bin', '06n_gs22.bin'),
        @('04l_gs17.bin', '04n_gs21.bin'),
        @('03l_gs16.bin', '03n_gs20.bin'),
        @('01l_gs15.bin', '01n_gs19.bin')
    )) {
        $objectParts.Add((Interleave-Chips (Get-Chip $archive $pair[0] 32768) (Get-Chip $archive $pair[1] 32768)))
    }
    Write-Rom 'obj' (Sort-Graphics (Join-Bytes $objectParts.ToArray()) 0x7c 0x40 4) # hvvvvxx

    $promParts = (New-Object 'System.Collections.Generic.List[byte[]]')
    foreach ($name in @(
        '03b_g-01.bin', '04b_g-02.bin', '05b_g-03.bin', '09d_g-04.bin',
        '14a_g-06.bin', '15a_g-07.bin', '09f_g-09.bin', '08f_g-08.bin',
        '02j_g-10.bin', '01f_g-05.bin'
    )) { $promParts.Add((Get-Chip $archive $name 256)) }
    Write-Rom 'prom' (Join-Bytes $promParts.ToArray())
} finally {
    $archive.Dispose()
}
Write-Host "`nROMs written to: $OutputDir"
