## 8. Автоматизація через PowerShell

Для спрощення налаштування сервера можна використовувати PowerShell скрипти. **Всі команди необхідно виконувати від імені адміністратора.**

### 8.1. Скрипт повного налаштування сервера

Цей скрипт виконує всі необхідні кроки підготовки Windows Server для роботи Xeno RAT:
```powershell
# XenoRAT Server Setup Script
# Потребує запуску від імені адміністратора

# Параметри конфігурації
$Port = 8080  # Вкажіть потрібний порт
$RuleName = "ZaUkraine TCP Listener"

Write-Host "=== Налаштування Windows Server для Xeno RAT ===" -ForegroundColor Cyan

# 1. Перевірка прав адміністратора
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ПОМИЛКА] Скрипт повинен бути запущений від імені адміністратора!" -ForegroundColor Red
    exit 1
}

# 2. Отримання публічної IP-адреси
Write-Host "`n[Крок 1/5] Визначення публічної IP-адреси..." -ForegroundColor Yellow
try {
    $PublicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 10).Trim()
    Write-Host "Публічний IP: $PublicIP" -ForegroundColor Green
} catch {
    Write-Host "[ПОПЕРЕДЖЕННЯ] Не вдалося визначити публічний IP автоматично." -ForegroundColor Yellow
    Write-Host "Використовуйте IP-адресу, надану вашим хостинг-провайдером." -ForegroundColor Yellow
    $PublicIP = "ВКАЖІТЬ_ВАШ_IP"
}

# 3. Налаштування правила брандмауера
Write-Host "`n[Крок 2/5] Створення правила брандмауера для порту $Port..." -ForegroundColor Yellow

# Перевірка існування правила з такою назвою
$existingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Правило '$RuleName' вже існує. Видалення старого правила..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName $RuleName
}

# Створення нового правила
try {
    New-NetFirewallRule `
        -DisplayName $RuleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $Port `
        -Action Allow `
        -Profile Domain,Private,Public `
        -Description "Дозволяє вхідні TCP-підключення для Xeno RAT Server на порт $Port"
    
    Write-Host "Правило брандмауера успішно створено!" -ForegroundColor Green
} catch {
    Write-Host "[ПОМИЛКА] Не вдалося створити правило брандмауера: $_" -ForegroundColor Red
    exit 1
}

# 4. Вимкнення IE Enhanced Security Configuration
Write-Host "`n[Крок 3/5] Вимкнення IE Enhanced Security Configuration..." -ForegroundColor Yellow

try {
    # Для адміністраторів
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" `
        -Name "IsInstalled" -Value 0 -ErrorAction Stop
    
    # Для користувачів
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" `
        -Name "IsInstalled" -Value 0 -ErrorAction Stop
    
    Write-Host "IE Enhanced Security успішно вимкнено!" -ForegroundColor Green
} catch {
    Write-Host "[ПОПЕРЕДЖЕННЯ] Не вдалося вимкнути IE Enhanced Security: $_" -ForegroundColor Yellow
}

# 5. Перевірка .NET Framework
Write-Host "`n[Крок 4/5] Перевірка версії .NET Framework..." -ForegroundColor Yellow

try {
    $dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
    
    if ($dotNetVersion -ge 528040) {
        $versionName = switch ($dotNetVersion) {
            { $_ -ge 533320 } { "4.8.1" }
            { $_ -ge 528040 } { "4.8" }
            default { "4.x" }
        }
        Write-Host ".NET Framework $versionName встановлено (Release: $dotNetVersion)" -ForegroundColor Green
    } else {
        Write-Host "[ПОПЕРЕДЖЕННЯ] Встановлена застаріла версія .NET Framework!" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ПОПЕРЕДЖЕННЯ] Не вдалося визначити версію .NET Framework: $_" -ForegroundColor Yellow
}

# 6. Перевірка доступності порту
Write-Host "`n[Крок 5/5] Перевірка доступності порту $Port..." -ForegroundColor Yellow

$portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue

if ($portInUse) {
    Write-Host "[ПОПЕРЕДЖЕННЯ] Порт $Port вже використовується процесом:" -ForegroundColor Yellow
    Get-Process -Id $portInUse.OwningProcess | Select-Object Id, ProcessName, Path
    Write-Host "Рекомендується обрати інший порт або зупинити конфліктуючий процес." -ForegroundColor Yellow
} else {
    Write-Host "Порт $Port вільний і готовий до використання!" -ForegroundColor Green
}

# Підсумкова інформація
Write-Host "`n=== Налаштування завершено ===" -ForegroundColor Cyan
Write-Host "`nПараметри для Builder:" -ForegroundColor White
Write-Host "  IP/Host: $PublicIP" -ForegroundColor White
Write-Host "  Port: $Port" -ForegroundColor White
Write-Host "`nРекомендації щодо безпеки:" -ForegroundColor Yellow
Write-Host "  - Використовуйте складний унікальний Encryption Key" -ForegroundColor Yellow
Write-Host "  - Використовуйте складний унікальний Mutex" -ForegroundColor Yellow
Write-Host "  - Розгляньте використання нестандартного порту (не 8080)" -ForegroundColor Yellow
Write-Host "  - Регулярно перевіряйте логи сервера" -ForegroundColor Yellow
```

### 8.2. Скрипт для швидкого налаштування тільки брандмауера

Якщо вам потрібно тільки створити правило брандмауера:
```powershell
# Швидке налаштування правила брандмауера для Xeno RAT
# Параметри
param(
    [int]$Port = 8080,
    [string]$RuleName = "ZaUkraine TCP Listener"
)

# Перевірка прав
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Потрібні права адміністратора!" -ForegroundColor Red
    exit 1
}

# Видалення старого правила, якщо існує
Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule

# Створення правила
New-NetFirewallRule `
    -DisplayName $RuleName `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort $Port `
    -Action Allow `
    -Profile Domain,Private,Public `
    -Description "Xeno RAT Server listener на порту $Port"

Write-Host "Правило '$RuleName' для порту $Port створено успішно!" -ForegroundColor Green
```

**Використання:**
```powershell
# З параметрами за замовчуванням (порт 8080)
.\setup-firewall.ps1

# З користувацьким портом
.\setup-firewall.ps1 -Port 4444
```

### 8.3. Скрипт діагностики

Для перевірки конфігурації після налаштування:
```powershell
# Діагностика конфігурації Xeno RAT Server

param([int]$Port = 8080)

Write-Host "=== Діагностика конфігурації Xeno RAT ===" -ForegroundColor Cyan

# 1. Перевірка правила брандмауера
Write-Host "`n[1] Правила брандмауера для порту $Port:" -ForegroundColor Yellow
$rules = Get-NetFirewallRule | Where-Object {
    $portFilter = $_ | Get-NetFirewallPortFilter
    $portFilter.LocalPort -contains $Port -and $_.Direction -eq 'Inbound'
}

if ($rules) {
    $rules | ForEach-Object {
        Write-Host "  ✓ Правило: $($_.DisplayName)" -ForegroundColor Green
        Write-Host "    Статус: $($_.Enabled ? 'Увімкнено' : 'Вимкнено')" -ForegroundColor $(if ($_.Enabled) { 'Green' } else { 'Red' })
        Write-Host "    Дія: $($_.Action)" -ForegroundColor White
    }
} else {
    Write-Host "  ✗ Правила не знайдено!" -ForegroundColor Red
}

# 2. Перевірка порту
Write-Host "`n[2] Статус порту $Port:" -ForegroundColor Yellow
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue

if ($listener) {
    Write-Host "  ✓ Порт прослуховується процесом:" -ForegroundColor Green
    $process = Get-Process -Id $listener.OwningProcess
    Write-Host "    PID: $($process.Id)" -ForegroundColor White
    Write-Host "    Ім'я: $($process.ProcessName)" -ForegroundColor White
    Write-Host "    Шлях: $($process.Path)" -ForegroundColor White
} else {
    Write-Host "  • Порт вільний (очікує запуску Xeno RAT Server)" -ForegroundColor Yellow
}

# 3. Публічний IP
Write-Host "`n[3] Публічна IP-адреса:" -ForegroundColor Yellow
try {
    $ip = Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 5
    Write-Host "  $ip" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Не вдалося визначити" -ForegroundColor Red
}

# 4. IE Enhanced Security
Write-Host "`n[4] IE Enhanced Security Configuration:" -ForegroundColor Yellow
$ieEscAdmin = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}").IsInstalled
$ieEscUser = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}").IsInstalled

Write-Host "  Адміністратори: $(if ($ieEscAdmin -eq 0) { '✓ Вимкнено' } else { '✗ Увімкнено' })" -ForegroundColor $(if ($ieEscAdmin -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "  Користувачі: $(if ($ieEscUser -eq 0) { '✓ Вимкнено' } else { '✗ Увімкнено' })" -ForegroundColor $(if ($ieEscUser -eq 0) { 'Green' } else { 'Yellow' })

# 5. .NET Framework
Write-Host "`n[5] .NET Framework:" -ForegroundColor Yellow
try {
    $release = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release
    $version = switch ($release) {
        { $_ -ge 533320 } { "4.8.1 або вище" }
        { $_ -ge 528040 } { "4.8" }
        { $_ -ge 461808 } { "4.7.2" }
        default { "< 4.7.2 (потрібне оновлення)" }
    }
    Write-Host "  ✓ Версія: $version (Release: $release)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Не встановлено або помилка визначення" -ForegroundColor Red
}

Write-Host "`n=== Діагностика завершена ===" -ForegroundColor Cyan
```

### 8.4. Скрипт для видалення конфігурації

Для очищення налаштувань після тестування:
```powershell
# Видалення конфігурації Xeno RAT

param([string]$RuleName = "ZaUkraine TCP Listener")

Write-Host "=== Видалення конфігурації Xeno RAT ===" -ForegroundColor Cyan

# Видалення правил брандмауера
Write-Host "`nВидалення правил брандмауера..." -ForegroundColor Yellow
$rules = Get-NetFirewallRule -DisplayName "*XenoRAT*" -ErrorAction SilentlyContinue

if ($rules) {
    $rules | ForEach-Object {
        Write-Host "  Видалення: $($_.DisplayName)" -ForegroundColor Yellow
        Remove-NetFirewallRule -DisplayName $_.DisplayName
    }
    Write-Host "  ✓ Правила видалено" -ForegroundColor Green
} else {
    Write-Host "  • Правила не знайдено" -ForegroundColor Gray
}

Write-Host "`n✓ Очищення завершено" -ForegroundColor Green
Write-Host "Примітка: IE Enhanced Security та інші системні налаштування не були змінені." -ForegroundColor Yellow
```