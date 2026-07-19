param(
  [Parameter(Mandatory = $true)][int]$AppID,
  [Parameter(Mandatory = $true)][string]$SteamSDKPath,
  [Parameter(Mandatory = $true)][string]$SupabaseURL,
  [Parameter(Mandatory = $true)][string]$SupabasePublishableKey
)

$ErrorActionPreference = "Stop"
$steamAPI = Join-Path $SteamSDKPath "redistributable_bin\win64\steam_api64.dll"
if (-not (Test-Path $steamAPI)) {
  throw "Missing Steamworks runtime: $steamAPI"
}

dart run tool/sync_policy_assets.dart
flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release --target lib/main_steam.dart `
  "--dart-define=KOLKHOZ_STEAM_APP_ID=$AppID" `
  "--dart-define=KOLKHOZ_SUPABASE_URL=$SupabaseURL" `
  "--dart-define=KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"

$bundle = Resolve-Path "build/windows/x64/runner/Release"
Copy-Item $steamAPI $bundle -Force

foreach ($required in @(
  "kolkhoz_app.exe",
  "kolkhoz_c_engine.dll",
  "steam_api64.dll",
  "data/flutter_assets/assets/policies/hard_policy.json"
)) {
  if (-not (Test-Path (Join-Path $bundle $required))) {
    throw "Steam build is missing $required"
  }
}

@(
  "Kolkhoz Steam Windows Release"
  "AppID: $AppID"
  "Built UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
  "Architecture: x64"
) | Set-Content (Join-Path $bundle "BUILD_INFO.txt")

Write-Output $bundle
