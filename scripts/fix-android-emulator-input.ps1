param(
    [switch]$ResetGboard
)

$ErrorActionPreference = 'Stop'

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) {
    throw "adb.exe was not found at $adb"
}

$avdRoot = Join-Path $env:USERPROFILE '.android\avd'
if (-not (Test-Path -LiteralPath $avdRoot)) {
    throw "Android AVD folder was not found at $avdRoot"
}

Get-ChildItem -LiteralPath $avdRoot -Filter '*.avd' | ForEach-Object {
    $configPath = Join-Path $_.FullName 'config.ini'
    if (-not (Test-Path -LiteralPath $configPath)) {
        return
    }

    $hasKeyboardLine = $false
    $hasCharmapLine = $false
    $config = Get-Content -LiteralPath $configPath | ForEach-Object {
        if ($_ -match '^\s*hw\.keyboard\s*=') {
            $hasKeyboardLine = $true
            'hw.keyboard=yes'
        } elseif ($_ -match '^\s*hw\.keyboard\.charmap\s*=') {
            $hasCharmapLine = $true
            'hw.keyboard.charmap=qwerty2'
        } else {
            $_
        }
    }

    if (-not $hasKeyboardLine) {
        $config += 'hw.keyboard=yes'
    }

    if (-not $hasCharmapLine) {
        $config += 'hw.keyboard.charmap=qwerty2'
    }

    Set-Content -LiteralPath $configPath -Value $config -Encoding ASCII
    Write-Host "Updated $($_.Name): host keyboard input enabled."
}

$devices = & $adb devices
$onlineDevice = $devices | Select-String -Pattern "`tdevice$" | Select-Object -First 1
if ($onlineDevice) {
    & $adb shell settings put secure show_ime_with_hard_keyboard 1
    & $adb shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME | Out-Host

    if ($ResetGboard) {
        & $adb shell pm clear com.google.android.inputmethod.latin | Out-Host
        & $adb shell settings put secure show_ime_with_hard_keyboard 1
        & $adb shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME | Out-Host
    }

    Write-Host 'Runtime input settings updated on the connected emulator.'
} else {
    Write-Host 'No online emulator was found. AVD files were updated; start an emulator to apply runtime settings.'
}

Write-Host 'Restart or cold boot the emulator once for AVD hardware keyboard changes to take full effect.'
