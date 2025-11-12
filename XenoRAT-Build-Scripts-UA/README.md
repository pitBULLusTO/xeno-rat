# NOTES
Автор: DeepSeek
Дата: 2025-08-08

# Керівництво з автоматичної збірки Xeno RAT

Цей документ описує, як використовувати PowerShell-скрипт `Build-XenoRAT.ps1` для автоматичної збірки проєкту Xeno RAT з вихідного коду.

## Вимоги

Для успішної збірки на вашій Windows-машині (Windows 10/11/Server 2019+) мають бути встановлені наступні компоненти:

1.  **Git:** Необхідний для клонування репозиторію.
    - **Завантажити:** [git-scm.com](https://git-scm.com/download/win)

2.  **.NET Framework 4.8 SDK:** Необхідний для компіляції проєкту.
    - **Завантажити:** [dotnet.microsoft.com/download/dotnet-framework/net48](https://dotnet.microsoft.com/download/dotnet-framework/net48)
    - Оберіть "Developer Pack".

3.  **Build Tools for Visual Studio:** Містить MSBuild, компілятор C#.
    - **Завантажити:** [visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
    - При встановленні через Visual Studio Installer оберіть робоче навантаження **".NET desktop build tools"**.

## Крок 1: Завантаження скрипта

Завантажте скрипт `Build-XenoRAT.ps1` та `README.md` з директорії `Build` репозиторію:

- [Build-XenoRAT.ps1](https://github.com/SecNN/xeno-rat-moom825/blob/vola/Build/Build-XenoRAT.ps1)
- [README.md](https://github.com/SecNN/xeno-rat-moom825/blob/vola/Build/README.md)

Збережіть їх в одній папці на вашому сервері, наприклад, `C:\BuildScripts`.

## Крок 2: Запуск скрипта

1.  **Відкрийте PowerShell від імені адміністратора.**
    - Натисніть `Win + X` та оберіть `Windows PowerShell (Admin)` або `Windows Terminal (Admin)`.

2.  **Дозвольте виконання скриптів (якщо потрібно).**
    За замовчуванням виконання скриптів може бути заблоковано. Виконайте наступну команду, щоб дозволити виконання для поточної сесії:

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
    ```

3.  **Перейдіть до директорії зі скриптом.**

    ```powershell
    cd C:\BuildScripts
    ```

4.  **Запустіть скрипт.**

    ```powershell
    .\Build-XenoRAT.ps1
    ```

Скрипт почне виконання та виводитиме інформацію про кожен крок.

## Параметри скрипта

Ви можете налаштувати роботу скрипта за допомогою параметрів:

-   `-BuildPath [шлях]` — вказує директорію, де відбуватиметься збірка. За замовчуванням: `C:\XenoRAT-Build`.
-   `-Branch [гілка]` — вказує гілку репозиторію для збірки. За замовчуванням: `vola`.

### Приклад з параметрами

```powershell
# Збірка з гілки main в директорію D:\MyBuilds
.\Build-XenoRAT.ps1 -BuildPath "D:\MyBuilds" -Branch "main"
```

## Що робить скрипт?

1.  **Перевіряє наявність** Git, MSBuild та .NET Framework SDK.
2.  **Завантажує NuGet**, якщо він відсутній.
3.  **Клонує** вказану гілку репозиторію `SecNN/xeno-rat-moom825`.
4.  **Відновлює** всі необхідні NuGet-пакети.
5.  **Компілює** проєкти `xeno rat server` та `xeno rat client` в конфігурації `Release`.
6.  **Створює** релізну папку `XenoRAT-Release` з усіма необхідними файлами:
    -   `xeno rat server.exe` та його залежності (DLL).
    -   Папку `stub` з `xeno rat client.exe` для Builder.
    -   Папку `Plugins` з вихідним кодом плагінів.
7.  **Створює ZIP-архів** `XenoRAT-Release-[гілка].zip` для зручного розповсюдження.

## Результати збірки

Після успішного виконання скрипта ви знайдете:

-   **Релізну папку:** `C:\XenoRAT-Build\XenoRAT-Release`
-   **Архів:** `C:\XenoRAT-Build\XenoRAT-Release-vola.zip`

Тепер ви можете перенести цю папку або архів на цільову машину та запустити `xeno rat server.exe`.

## Усунення неполадок

| Проблема | Рішення |
| :--- | :--- |
| **Помилка "MSBuild не знайдено"** | Переконайтеся, що ви встановили **Build Tools for Visual Studio** з робочим навантаженням **".NET desktop build tools"**. |
| **Помилка компіляції** | Перевірте, що встановлено **.NET Framework 4.8 SDK (Developer Pack)**. |
| **Помилка клонування репозиторію** | Перевірте ваше інтернет-з'єднання та доступність GitHub. |
| **Скрипт не запускається (помилка ExecutionPolicy)** | Виконайте команду `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` в PowerShell (від імені адміністратора). |

## Додаткова інформація

### Час виконання

Перша збірка може зайняти **5-15 хвилин** залежно від швидкості інтернету та продуктивності сервера.

### Розмір релізу

Готовий архів матиме розмір приблизно **15-25 МБ** (без залежностей плагінів).

### Підтримка

Якщо у вас виникли проблеми зі збіркою:

1. Переконайтеся, що всі вимоги встановлені
2. Запустіть PowerShell від імені адміністратора
3. Перевірте підключення до інтернету
4. Перегляньте повідомлення про помилки в консолі

### Безпека

⚠️ **Важливо:** Перед використанням зібраного релізу:

- Змініть всі параметри за замовчуванням (IP, порт, ключ шифрування)
- Прочитайте чеклист безпеки в репозиторії
- Тестуйте тільки в ізольованому середовищі
- Дотримуйтесь місцевого законодавства

## Корисні посилання

- **Репозиторій:** [github.com/SecNN/xeno-rat-moom825](https://github.com/SecNN/xeno-rat-moom825)
- **Гілка vola:** [github.com/SecNN/xeno-rat-moom825/tree/vola](https://github.com/SecNN/xeno-rat-moom825/tree/vola)
- **Документація:** Доступна в папці `Docs/` репозиторію
- **Чеклист безпеки:** `Docs/Security/SECURITY_CHECKLIST.md`
- **Інструкції з тестування:** `Docs/Test/Guideline_Server_to_PC.md`
