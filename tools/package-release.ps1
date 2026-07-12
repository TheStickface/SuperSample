# Packages the mod into a portal-ready zip in dist/.
#
# The Factorio mod portal rejects zips with backslash directory separators
# (which Compress-Archive and even System.IO.Compression.ZipFile.CreateFromDirectory
# produce on Windows), so entries are written manually with forward slashes.

$repoRoot = Split-Path $PSScriptRoot -Parent
$info     = Get-Content (Join-Path $repoRoot "info.json") -Raw | ConvertFrom-Json
$release  = "$($info.name)_$($info.version)"

$excludeDirs = @('.git', '.claude', 'docs', 'tools', 'dist')

$distDir  = Join-Path $repoRoot "dist"
$stageDir = Join-Path $distDir $release
$zipPath  = Join-Path $distDir "$release.zip"

if (Test-Path $stageDir) { Remove-Item -Path $stageDir -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item -Path $zipPath -Force }
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

Get-ChildItem -Path $repoRoot -Force |
    Where-Object { ($excludeDirs -notcontains $_.Name) -and (-not $_.Name.StartsWith('.')) } |
    ForEach-Object { Copy-Item -Path $_.FullName -Destination $stageDir -Recurse -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$fs      = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::Create)
$archive = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)

$slash = [char]47
$back  = [char]92
Get-ChildItem -Path $stageDir -Recurse -File | ForEach-Object {
    $entryName   = $_.FullName.Substring($distDir.Length + 1).Replace($back, $slash)
    $entry       = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $entryStream = $entry.Open()
    $bytes       = [System.IO.File]::ReadAllBytes($_.FullName)
    $entryStream.Write($bytes, 0, $bytes.Length)
    $entryStream.Close()
}
$archive.Dispose()
$fs.Dispose()

Remove-Item -Path $stageDir -Recurse -Force

Write-Output "Packaged: $zipPath"
