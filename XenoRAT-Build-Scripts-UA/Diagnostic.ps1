# Diagnostic.ps1
Write-Host "PowerShell Version:" -ForegroundColor Cyan
$PSVersionTable

Write-Host "`nChecking file encoding..." -ForegroundColor Cyan
$bytes = [System.IO.File]::ReadAllBytes(".\Build-XenoRAT-EN.ps1")
$hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "File has UTF-8 BOM: $hasBOM"

Write-Host "`nSystem locale:" -ForegroundColor Cyan
Get-Culture

Write-Host "`nConsole encoding:" -ForegroundColor Cyan
[Console]::OutputEncoding