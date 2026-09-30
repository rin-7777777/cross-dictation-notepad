#Requires -Version 5.1
# 注意：本文件必须保存为「UTF-8 带 BOM」，否则 Windows PowerShell 5.1 会把中文读成乱码。
<#
.SYNOPSIS
    一键编译「跨端听写记事本」的 Windows 桌面版，并在桌面创建快捷方式。

.DESCRIPTION
    做三件事：
      1. flutter pub get
      2. flutter build windows --release
      3. 在桌面创建「听写记事本」快捷方式，指向产出的 exe

    前置要求：本机装了 Flutter（>= 3.19）和 Visual Studio 2022（含「使用 C++ 的桌面开发」
    工作负载与 Windows SDK）。Flutter 的 Windows 目标只支持 MSVC，MinGW/GCC 不行。

.PARAMETER ProjectRoot
    项目根目录（含 pubspec.yaml）。默认是脚本上一级目录。

.PARAMETER ShortcutName
    桌面快捷方式的名字，默认「听写记事本」。

.PARAMETER SkipBuild
    只创建快捷方式，不重新编译（产物已经存在时用）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$ShortcutName = '听写记事本',
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Text) Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn2 { param([string]$Text) Write-Host "    [!!] $Text" -ForegroundColor Yellow }

# ------------------------------------------------------------ 项目根目录
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        throw '无法确定脚本所在目录，请显式传入 -ProjectRoot <项目根目录>。'
    }
    $ProjectRoot = Split-Path -Parent $scriptDir
}
$pubspec = Join-Path $ProjectRoot 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspec)) {
    throw "在 $ProjectRoot 里没有找到 pubspec.yaml，请用 -ProjectRoot 指定正确的项目根目录。"
}

# 从 pubspec.yaml 里读 name（决定 exe 文件名）
$appName = 'dictation_notepad'
foreach ($line in Get-Content -LiteralPath $pubspec -Encoding UTF8) {
    if ($line -match '^\s*name\s*:\s*(\S+)\s*$') { $appName = $Matches[1]; break }
}
Write-Host ''
Write-Host '跨端听写记事本 - Windows 桌面版打包' -ForegroundColor White
Write-Host "项目根目录：$ProjectRoot"
Write-Host "应用名　　：$appName"
Write-Host ''

# ---------------------------------------------------------------- Flutter
if (-not $SkipBuild) {
    Write-Step '检查 Flutter'
    $flutterExe = $null
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -ne $flutterCmd) {
        $flutterExe = $flutterCmd.Source
    } elseif (-not [string]::IsNullOrWhiteSpace($env:FLUTTER_ROOT)) {
        $candidate = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
        if (Test-Path -LiteralPath $candidate) { $flutterExe = $candidate }
    }
    if ($null -eq $flutterExe) {
        throw 'PATH 里没有 flutter，也没有可用的 FLUTTER_ROOT。请先安装 Flutter（>= 3.19）。'
    }
    Write-Ok $flutterExe

    Push-Location $ProjectRoot
    try {
        Write-Step 'flutter pub get'
        & $flutterExe pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get 失败（退出码 $LASTEXITCODE）。" }

        Write-Step 'flutter build windows --release'
        & $flutterExe build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw @"
flutter build windows 失败（退出码 $LASTEXITCODE）。
最常见的原因是没装 Visual Studio：需要 2022 版 + 「使用 C++ 的桌面开发」工作负载 + Windows SDK。
装好后重跑本脚本即可。
"@
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Step '跳过编译（-SkipBuild）'
}

# ------------------------------------------------------------ 找产物 exe
$releaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$exePath = Join-Path $releaseDir "$appName.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    # 兜底：Release 目录里唯一的 exe
    $found = Get-ChildItem -LiteralPath $releaseDir -Filter '*.exe' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'flutter_windows*' } |
        Select-Object -First 1
    if ($null -eq $found) {
        throw "没找到编译产物：$exePath。请先成功执行 flutter build windows --release。"
    }
    $exePath = $found.FullName
}
Write-Ok "产物：$exePath"

# ------------------------------------------------------------ 建桌面快捷方式
Write-Step '创建桌面快捷方式'
$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop)) {
    throw '取不到桌面目录，无法创建快捷方式。'
}
$lnkPath = Join-Path $desktop ($ShortcutName + '.lnk')

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($lnkPath)
$shortcut.TargetPath = $exePath
# 关键：工作目录必须是 exe 所在目录，Flutter 的 Windows 产物依赖同目录的 dll 与 data 文件夹
$shortcut.WorkingDirectory = (Split-Path -Parent $exePath)
$shortcut.Description = '播放本地视频 + 纯文本听写'
$shortcut.IconLocation = "$exePath,0"
$shortcut.Save()
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)

if (Test-Path -LiteralPath $lnkPath) {
    Write-Ok "桌面快捷方式：$lnkPath"
} else {
    Write-Warn2 "快捷方式似乎没创建成功：$lnkPath"
}

Write-Host ''
Write-Host '完成。双击桌面上的「' -NoNewline
Write-Host $ShortcutName -NoNewline -ForegroundColor Green
Write-Host '」即可启动。'
Write-Host ''
Write-Host '提示：如果整个 Release 目录要拷给别人，记得把目录里所有文件一起拷' -ForegroundColor DarkGray
Write-Host '      （exe 需要同目录的 DLL 和 data 文件夹），只拷 exe 是跑不起来的。' -ForegroundColor DarkGray
Write-Host ''
