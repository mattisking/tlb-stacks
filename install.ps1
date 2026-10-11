[CmdletBinding()]
param(
    [string] $BuildDirectory = (Join-Path $PSScriptRoot 'build'),
    [string] $InstallPrefix = (Join-Path $HOME '.local'),
    [string] $QmlDirectory = 'lib64/qt6/qml',
    [switch] $WithGroup,
    [switch] $SkipGroup,
    [switch] $NoRestart
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    throw 'Python 3 is required for portable profile support.'
}

function Invoke-Checked {
    param([string] $Command, [string[]] $Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE. Deployment stopped."
    }
}

# Always configure: the old cache may still use /usr/local or lack install rules.
Invoke-Checked cmake @('-S', $PSScriptRoot, '-B', $BuildDirectory,
    "-DCMAKE_INSTALL_PREFIX=$InstallPrefix", "-DTLB_QML_INSTALL_DIR:STRING=$QmlDirectory",
    "-DTLB_INSTALL_WIDGET:BOOL=OFF", "-DTLB_INSTALL_GROUP:BOOL=OFF")
Invoke-Checked cmake @('--build', $BuildDirectory)
Invoke-Checked cmake @('--install', $BuildDirectory)

$moduleRoot = if ([IO.Path]::IsPathRooted($QmlDirectory)) {
    $QmlDirectory
} else {
    Join-Path $InstallPrefix $QmlDirectory
}
$moduleDirectory = Join-Path $moduleRoot 'com/mattphilmon/tlbstacks'
$installedPlugin = Join-Path $moduleDirectory 'libtlbstacksplugin.so'
$builtPlugin = Join-Path $BuildDirectory 'qml/com/mattphilmon/tlbstacks/libtlbstacksplugin.so'
if ((Get-FileHash $installedPlugin).Hash -ne (Get-FileHash $builtPlugin).Hash) {
    throw "Installed plugin does not match the build: $installedPlugin"
}
Write-Host "Verified plugin: $installedPlugin"

# The group widget ships the task-management features, so it deploys by default;
# -SkipGroup omits it (e.g. a panel that only uses the standalone widget).
# -WithGroup is accepted as a legacy no-op now that the group is the default.
if ($WithGroup -and $SkipGroup) { throw 'Pass only one of -WithGroup / -SkipGroup.' }
$packageNames = @('package')
if (-not $SkipGroup) { $packageNames += 'package-group' }
$dataRoot = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $HOME '.local/share' }
foreach ($packageName in $packageNames) {
    $package = Join-Path $PSScriptRoot $packageName
    $packageId = (Get-Content (Join-Path $package 'metadata.json') -Raw | ConvertFrom-Json).KPlugin.Id
    $installedPackage = Join-Path $dataRoot "plasma/plasmoids/$packageId"
    $action = if (Test-Path $installedPackage) { '--upgrade' } else { '--install' }
    Invoke-Checked kpackagetool6 @('--type', 'Plasma/Applet', $action, $package)
}

if (-not $NoRestart) {
    # A loaded native plugin remains in memory until the shell exits.
    Invoke-Checked systemctl @('--user', 'restart', 'plasma-plasmashell.service')
    Invoke-Checked systemctl @('--user', 'is-active', 'plasma-plasmashell.service')
} else {
    Write-Host 'Restart plasmashell before testing the new native plugin.'
}
