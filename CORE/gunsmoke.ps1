param(
    [string]$MameZip = '',
    [string]$MegaZip = '',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($MameZip)) { $MameZip = Join-Path $ScriptDir 'gunsmoke.zip' }
if ([string]::IsNullOrWhiteSpace($MegaZip)) { $MegaZip = Join-Path $ScriptDir 'gunsmoke_meg65_roms.zip' }
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $ScriptDir 'arcade\gunsmoke' }

# Convert to absolute paths: .NET resolves relative paths against process cwd
# (often C:\WINDOWS\system32), not PowerShell's current location.
$MameZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MameZip)
$MegaZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MegaZip)
$OutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)

Write-Host "MAME ZIP:     $MameZip"
Write-Host "Prepared ZIP: $MegaZip"
Write-Host "Output:       $OutputDir"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-ZipEntry {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$Name)
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Missing ZIP entry: $Name" }
    $stream = $entry.Open()
    $buffer = New-Object System.IO.MemoryStream
    try {
        $stream.CopyTo($buffer)
        return ,($buffer.ToArray())
    }
    finally {
        $stream.Dispose()
        $buffer.Dispose()
    }
}

function Write-Rom {
    param([string]$Name, [byte[]]$Bytes)
    $path = Join-Path $OutputDir $Name
    [System.IO.File]::WriteAllBytes($path, $Bytes)
    [uint32]$crc = 4294967295
    foreach ($b in $Bytes) {
        $crc = $crc -bxor [uint32]$b
        for ($k = 0; $k -lt 8; $k++) {
            if (($crc -band [uint32]1) -ne 0) {
                $crc = ($crc -shr 1) -bxor [uint32]3988292384
            } else {
                $crc = $crc -shr 1
            }
        }
    }
    $crc = $crc -bxor [uint32]4294967295
    Write-Host ('{0,-24} {1,7} bytes  CRC32 {2:X8}' -f $Name, $Bytes.Length, $crc)
}

function Sort-Map {
    param([byte[]]$Data)
    if (($Data.Length % 32) -ne 0) { throw 'Map ROM size must be a multiple of 32' }
    $out = New-Object byte[] $Data.Length
    for ($i = 0; $i -lt $Data.Length; $i++) {
        # JTFRAME gfx_sort=hvvvx
        $j = ($i -band (-bnot 0x1e)) -bor (($i -band 0x10) -shr 3) -bor (($i -band 0x0e) -shl 1)
        $out[$j] = $Data[$i]
    }
    return ,$out
}

function Build-Objects {
    param([System.IO.Compression.ZipArchive]$Archive)
    $pairs = @(
        @('06l_gs18.bin', '06n_gs22.bin'),
        @('04l_gs17.bin', '04n_gs21.bin'),
        @('03l_gs16.bin', '03n_gs20.bin'),
        @('01l_gs15.bin', '01n_gs19.bin')
    )
    $src = New-Object byte[] 262144
    for ($p = 0; $p -lt $pairs.Count; $p++) {
        [byte[]]$even = Read-ZipEntry $Archive $pairs[$p][0]
        [byte[]]$odd = Read-ZipEntry $Archive $pairs[$p][1]
        if ($even.Length -ne 32768 -or $odd.Length -ne 32768) {
            throw "Invalid object chip size in pair $p"
        }
        $base = $p * 65536
        for ($i = 0; $i -lt 32768; $i++) {
            $src[$base + 2*$i] = $even[$i]
            $src[$base + 2*$i + 1] = $odd[$i]
        }
    }
    $out = New-Object byte[] $src.Length
    for ($i = 0; $i -lt $src.Length; $i++) {
        # JTFRAME gfx_sort=hvvvvxx
        $j = ($i -band (-bnot 0x7c)) -bor (($i -band 0x40) -shr 4) -bor (($i -band 0x3c) -shl 1)
        $out[$j] = $src[$i]
    }
    return ,$out
}

if (-not (Test-Path -LiteralPath $MameZip -PathType Leaf)) { throw "Missing: $MameZip" }
if (-not (Test-Path -LiteralPath $MegaZip -PathType Leaf)) { throw "Missing: $MegaZip" }
[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$mame = [System.IO.Compression.ZipFile]::OpenRead([System.IO.Path]::GetFullPath($MameZip))
$prepared = $null
try {
    $prepared = [System.IO.Compression.ZipFile]::OpenRead([System.IO.Path]::GetFullPath($MegaZip))
    foreach ($part in @('main', 'sound', 'char')) {
        $name = "gunsmoke_$part.rom"
        [byte[]]$data = Read-ZipEntry $prepared $name
        Write-Rom $name $data
    }
    [byte[]]$map = Read-ZipEntry $prepared 'gunsmoke_map.rom'
    Write-Rom 'gunsmoke_map.rom' (Sort-Map $map)
    [byte[]]$scr = Read-ZipEntry $prepared 'gunsmoke_scr.rom'
    Write-Rom 'gunsmoke_scr.rom' $scr
    Write-Rom 'gunsmoke_obj.rom' (Build-Objects $mame)
    [byte[]]$prom = Read-ZipEntry $prepared 'gunsmoke_prom.rom'
    Write-Rom 'gunsmoke_prom.rom' $prom
}
finally {
    if ($null -ne $prepared) { $prepared.Dispose() }
    $mame.Dispose()
}
Write-Host "`nROMs written to: $OutputDir"
