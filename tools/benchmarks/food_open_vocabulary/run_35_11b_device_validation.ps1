$ErrorActionPreference = "Stop"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$serial = "RZCW8201QBV"

Write-Host "0. Building incremental debug APK..."
flutter build apk --debug
if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk --debug failed with exit code $LASTEXITCODE"
}

Write-Host "1. Starting ADB server and waiting for $serial..."
& $adb start-server
& $adb -s $serial wait-for-device
Start-Sleep -Seconds 2
& $adb devices -l

Write-Host "2. Installing build\app\outputs\flutter-apk\app-debug.apk on $serial..."
& $adb -s $serial install -r "c:\projects\FitFuel\build\app\outputs\flutter-apk\app-debug.apk"

Write-Host "3. Preparing validation_images directory on $serial..."
$remoteDir = "/sdcard/Android/data/com.example.fitfuel/files/validation_images"
& $adb -s $serial shell "mkdir -p $remoteDir"

$localImgDir = "c:\projects\FitFuel\tools\benchmarks\food_open_vocabulary\device_assets\extracted_validation_images"
$imagesToPush = @(
    "food_0221.jpg",
    "food_0249.jpg",
    "food_0289.jpg",
    "food_0021.jpg",
    "food_0275.jpg",
    "food_0468.jpg",
    "food_0009.jpg",
    "food_0003.jpg",
    "food_0075.jpg",
    "food_0303.jpg",
    "food_0046.jpg",
    "food_0061.jpg",
    "food_0477.jpg",
    "food_0472.jpg",
    "food_0466.jpg",
    "non_food_laptop.jpg",
    "non_food_empty_plate.jpg"
)
foreach ($img in $imagesToPush) {
    & $adb -s $serial push "$localImgDir\$img" "$remoteDir/$img"
}

Write-Host "4. Running ONLINE Phase 35.11B Real-Device Validation..."
& $adb -s $serial shell "am force-stop com.example.fitfuel"
& $adb -s $serial logcat -c
& $adb -s $serial shell "am start -n com.example.fitfuel/.MainActivity --es validate_35_11b true --es validate_mode online"

for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    $logs = & $adb -s $serial logcat -d
    if ($logs -match "COMPLETED PHASE 35\.11B REAL-DEVICE VALIDATION \(mode=online") {
        break
    }
    if ($logs -match "\[PHASE_35_11B_VALIDATION\] ERROR:") {
        Write-Host "Online validation error detected in logs!"
        break
    }
}

$onlineLogs = & $adb -s $serial logcat -d | Select-String -Pattern "PHASE_35_11B_VALIDATION|FoodScanCascade|FoodScanPresentation|FoodScanRoute|FoodScanLocalPerf|FoodScanSafety"
$onlineLogs | ForEach-Object { $_.Line } | Set-Content -Path "c:\projects\FitFuel\tools\benchmarks\food_open_vocabulary\phase_35_11b_online_logcat.txt"
Write-Host "=== ONLINE VALIDATION SUMMARY ==="
Select-String -Path "c:\projects\FitFuel\tools\benchmarks\food_open_vocabulary\phase_35_11b_online_logcat.txt" -Pattern "PHASE_35_11B_VALIDATION|FoodScanPresentation" | ForEach-Object { $_.Line }

Write-Host "5. Running OFFLINE Phase 35.11B Real-Device Validation (Wi-Fi OFF, Mobile Data OFF)..."
try {
    & $adb -s $serial shell "svc wifi disable"
    & $adb -s $serial shell "svc data disable"
    Start-Sleep -Seconds 3

    & $adb -s $serial shell "am force-stop com.example.fitfuel"
    & $adb -s $serial logcat -c
    & $adb -s $serial shell "am start -n com.example.fitfuel/.MainActivity --es validate_35_11b true --es validate_mode offline"

    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 2
        $logs = & $adb -s $serial logcat -d
        if ($logs -match "COMPLETED PHASE 35\.11B REAL-DEVICE VALIDATION \(mode=offline") {
            break
        }
        if ($logs -match "\[PHASE_35_11B_VALIDATION\] ERROR:") {
            Write-Host "Offline validation error detected in logs!"
            break
        }
    }

    $offlineLogs = & $adb -s $serial logcat -d | Select-String -Pattern "PHASE_35_11B_VALIDATION|FoodScanCascade|FoodScanPresentation|FoodScanRoute|FoodScanLocalPerf|FoodScanSafety"
    $offlineLogs | ForEach-Object { $_.Line } | Set-Content -Path "c:\projects\FitFuel\tools\benchmarks\food_open_vocabulary\phase_35_11b_offline_logcat.txt"
    Write-Host "=== OFFLINE VALIDATION SUMMARY ==="
    Select-String -Path "c:\projects\FitFuel\tools\benchmarks\food_open_vocabulary\phase_35_11b_offline_logcat.txt" -Pattern "PHASE_35_11B_VALIDATION|FoodScanPresentation" | ForEach-Object { $_.Line }
} finally {
    Write-Host "6. Re-enabling Wi-Fi and Mobile Data on $serial..."
    & $adb -s $serial shell "svc wifi enable"
    & $adb -s $serial shell "svc data enable"
}
