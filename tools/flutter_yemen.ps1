[CmdletBinding()]
param(
  [ValidateSet('help', 'doctor', 'setup', 'analyze', 'test', 'run', 'build')]
  [string]$Command = 'help',
  [ValidateSet('all', 'customer', 'creator')]
  [string]$App = 'all',
  [ValidateSet('web', 'android', 'ios', 'apk', 'appbundle')]
  [string]$Target = 'web',
  [ValidateSet('debug', 'profile', 'release')]
  [string]$Mode = 'debug'
)

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $PSScriptRoot
$DefinesFile = if ($env:FLUTTER_DEFINES_FILE) { $env:FLUTTER_DEFINES_FILE } else { Join-Path $RootDir 'config/flutter_defines.json' }
$FlutterBin = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'flutter' }

function Fail([string]$Message) {
  Write-Error "ERROR: $Message"
  exit 1
}

function Show-Help {
  @'
Usage:
  .\tools\flutter_yemen.ps1 setup -App all
  .\tools\flutter_yemen.ps1 doctor
  .\tools\flutter_yemen.ps1 analyze -App all
  .\tools\flutter_yemen.ps1 test -App all
  .\tools\flutter_yemen.ps1 run -App customer -Target web -Mode debug
  .\tools\flutter_yemen.ps1 build -App customer -Target web -Mode release
  .\tools\flutter_yemen.ps1 build -App customer -Target appbundle -Mode release

Copy config/flutter_defines.example.json to config/flutter_defines.json first.
The file is local-only and must contain public compile-time values only.
'@
}

function Get-AppDir([string]$SelectedApp) {
  switch ($SelectedApp) {
    'customer' { return (Join-Path $RootDir 'flutter_app') }
    'creator' { return (Join-Path $RootDir 'creator_app') }
    default { Fail "Unknown app '$SelectedApp'. Use customer or creator." }
  }
}

function Invoke-Flutter([string]$AppDir, [string[]]$Arguments) {
  Push-Location $AppDir
  try { & $FlutterBin @Arguments; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
  finally { Pop-Location }
}

function Assert-Defines {
  if (-not (Test-Path -LiteralPath $DefinesFile)) {
    Fail "Missing $DefinesFile. Copy config/flutter_defines.example.json to config/flutter_defines.json and fill the public Supabase values."
  }
  $content = Get-Content -Raw -LiteralPath $DefinesFile
  if ($content -match '(?i)service[_-]?role|SUPABASE_SERVICE_ROLE_KEY|AI_PROVIDER_API_KEY|BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY|private_key') {
    Fail 'Refusing to use a configuration file containing service-role, provider, or private-key material.'
  }
}

function Invoke-ForApp([scriptblock]$Action) {
  if ($App -eq 'all') { & $Action 'customer'; & $Action 'creator' } else { & $Action $App }
}

switch ($Command) {
  'help' { Show-Help }
  'doctor' { & $FlutterBin doctor -v }
  'setup' { Invoke-ForApp { param($SelectedApp) Invoke-Flutter (Get-AppDir $SelectedApp) @('pub', 'get') } }
  'analyze' { Invoke-ForApp { param($SelectedApp) Invoke-Flutter (Get-AppDir $SelectedApp) @('analyze') } }
  'test' { Invoke-ForApp { param($SelectedApp) Invoke-Flutter (Get-AppDir $SelectedApp) @('test') } }
  'run' {
    if ($Target -eq 'apk' -or $Target -eq 'appbundle') { Fail 'Use build for apk or appbundle targets.' }
    if ($Mode -eq 'release') { Fail 'Use build for release artifacts.' }
    Assert-Defines
    $device = if ($Target -eq 'web') { 'chrome' } elseif ($Target -eq 'android') { 'android' } else { 'ios' }
    $modeFlag = "--$Mode"
    Invoke-Flutter (Get-AppDir $App) @('run', '-d', $device, $modeFlag, "--dart-define-from-file=$DefinesFile")
  }
  'build' {
    Assert-Defines
    $flutterTarget = if ($Target -eq 'ios') { 'ipa' } else { $Target }
    if ($Target -eq 'appbundle' -and $Mode -ne 'release') { Fail 'appbundle is a release-only artifact.' }
    Invoke-Flutter (Get-AppDir $App) @('build', $flutterTarget, "--$Mode", "--dart-define-from-file=$DefinesFile")
  }
}
