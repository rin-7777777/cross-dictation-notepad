#Requires -Version 5.1
# 注意：本文件必须保存为「UTF-8 带 BOM」。Windows PowerShell 5.1 读 .ps1 时
# 默认按系统代码页解码，没有 BOM 会把下面的中文读成乱码并直接语法报错。
<#
.SYNOPSIS
    为「跨端听写记事本」生成 Android / Windows 平台目录，并打上本项目需要的平台改动。

.DESCRIPTION
    手写的 android/ 和 windows/ 目录容易与你本机 Flutter 版本的模板对不上
    （gradle wrapper、AGP 版本、图标等二进制/版本相关内容没法凭空生成）。
    所以这里用 `flutter create` 在临时目录里生成一份与你 Flutter 版本完全匹配的
    平台脚手架，再拷进项目，最后只做几处必要的文本改动：

      Android
        * AndroidManifest.xml：加上长期访问文件夹需要的权限、中文应用名、
          requestLegacyExternalStorage；
        * build.gradle / build.gradle.kts：minSdk 提到 24（media_kit 的要求）。
      Windows
        * runner/main.cpp：窗口标题与初始窗口大小。

    脚本只写 android/ 和 windows/ 两个平台目录，绝不碰 lib/、pubspec.yaml 和你的 TXT。

.PARAMETER ProjectRoot
    项目根目录（含 pubspec.yaml）。默认是脚本上一级目录。

.PARAMETER Org
    Android applicationId 的组织前缀，默认 com.dictation。

.PARAMETER ProjectName
    Flutter 包名，默认 dictation_notepad。要和 pubspec.yaml 里的 name 一致。

.PARAMETER SkipFlutterCreate
    跳过 flutter create，只对已有的 android/ windows/ 打补丁。用于模板已经生成好的情况。

.PARAMETER KeepGenerated
    保留临时生成目录，方便对照检查。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_platforms.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$Org = 'com.dictation',
    [string]$ProjectName = 'dictation_notepad',
    [switch]$SkipFlutterCreate,
    [switch]$KeepGenerated
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 注意：不能在参数默认值里用 $PSScriptRoot —— Windows PowerShell 5.1 在
# `powershell -File 脚本.ps1` 这种调用方式下，求值参数默认值时它还可能是个空串。
# 所以放到这里再算，并且多留一条 $MyInvocation 的退路。
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

$AppLabel = '听写记事本'
$WindowTitle = 'Dictation Notepad'
$MinSdk = 24

function Write-Step { param([string]$Text) Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Skip { param([string]$Text) Write-Host "    [--] $Text" -ForegroundColor DarkGray }
function Write-Warn2 { param([string]$Text) Write-Host "    [!!] $Text" -ForegroundColor Yellow }

function Read-TextFile {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFile {
    param([string]$Path, [string]$Text)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

# ----------------------------------------------------------------- Android

function Update-AndroidManifest {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warn2 "没找到 $Path，跳过。"
        return
    }

    $text = Read-TextFile -Path $Path
    $changed = $false
    $nl = "`r`n"

    # 1) manifest 标签上补 xmlns:tools
    if ($text -notmatch 'xmlns:tools') {
        $text = [regex]::Replace(
            $text,
            '(<manifest\s+[^>]*xmlns:android="http://schemas\.android\.com/apk/res/android")',
            ('$1' + $nl + '    xmlns:tools="http://schemas.android.com/tools"'),
            1)
        $changed = $true
    }

    # 2) 权限
    if ($text -notmatch 'MANAGE_EXTERNAL_STORAGE') {
        $permissions = @'
    <!-- 长期按真实路径读写用户选定的「视频文件夹」「文本文件夹」：
         只有真实路径才能同时被 dart:io 和 libmpv(media_kit) 使用，
         并且重启之后依然有效。 -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
        tools:ignore="ScopedStorage" />
    <!-- Android 10 及以下 / 旧版本兼容声明 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="29" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

'@
        $anchor = '(<manifest[^>]*>\s*\r?\n)'
        if ($text -match $anchor) {
            $text = [regex]::Replace($text, $anchor, ('$1' + $permissions), 1)
            $changed = $true
        } else {
            Write-Warn2 'AndroidManifest.xml 里没找到 <manifest> 开始标签，权限没有加上。'
        }
    } else {
        Write-Skip 'AndroidManifest.xml 已经有存储权限声明。'
    }

    # 3) 应用名改中文
    if ($text -match 'android:label="[^"]*"') {
        $newText = [regex]::Replace($text, 'android:label="[^"]*"', ('android:label="' + $AppLabel + '"'), 1)
        if ($newText -ne $text) {
            $text = $newText
            $changed = $true
            Write-Ok "应用名改为 $AppLabel"
        }
    } else {
        $text = [regex]::Replace(
            $text,
            '(<application)',
            ('$1' + $nl + '        android:label="' + $AppLabel + '"'),
            1)
        $changed = $true
        Write-Ok "应用名改为 $AppLabel"
    }

    # 4) Android 10 的 legacy 存储开关 + libmpv 需要的本地库解包
    if ($text -notmatch 'requestLegacyExternalStorage') {
        $text = [regex]::Replace(
            $text,
            '(<application\s+)',
            ('$1android:requestLegacyExternalStorage="true"' + $nl + '        '),
            1)
        $changed = $true
    }
    if ($text -notmatch 'extractNativeLibs') {
        # media_kit 的 libmpv 以 .so 形式打包，解包安装最稳。
        $text = [regex]::Replace(
            $text,
            '(<application\s+)',
            ('$1android:extractNativeLibs="true"' + $nl + '        '),
            1)
        $changed = $true
    }

    if ($changed) {
        Write-TextFile -Path $Path -Text $text
        Write-Ok "已更新 $Path"
    } else {
        Write-Skip "$Path 不需要改动。"
    }
}

function Update-AndroidGradle {
    param([string]$AndroidDir)

    $candidates = @(
        (Join-Path $AndroidDir 'app\build.gradle'),
        (Join-Path $AndroidDir 'app\build.gradle.kts')
    )
    $patched = $false
    foreach ($file in $candidates) {
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $text = Read-TextFile -Path $file
        $original = $text
        $text = $text -replace 'minSdkVersion\s+flutter\.minSdkVersion', "minSdkVersion $MinSdk"
        $text = $text -replace 'minSdk\s*=\s*flutter\.minSdkVersion', "minSdk = $MinSdk"
        if ($text -ne $original) {
            Write-TextFile -Path $file -Text $text
            Write-Ok "minSdk 设为 $MinSdk（$file）"
            $patched = $true
        } elseif ($text -match "minSdk(Version)?\s*=?\s*$MinSdk") {
            Write-Skip "minSdk 已经是 $MinSdk（$file）"
            $patched = $true
        } else {
            Write-Warn2 "没在 $file 里找到 minSdkVersion flutter.minSdkVersion，请手动确认 minSdk >= $MinSdk。"
        }
    }
    if (-not $patched) {
        Write-Warn2 '没找到 android/app/build.gradle(.kts)，请手动确认 minSdk >= 24（media_kit 要求）。'
    }
}

# ------------------------------------------------- Android 路径检查（AGP）

function Update-AndroidGradleProperties {
    param([string]$AndroidDir, [string]$RootToCheck)

    if ($RootToCheck -notmatch '[^\x00-\x7F]') {
        Write-Skip '项目路径是纯 ASCII，不需要 android.overridePathCheck。'
        return
    }

    Write-Warn2 '项目路径里有非 ASCII 字符（例如中文目录名）。'
    Write-Warn2 'Android Gradle 插件默认会因此直接拒绝构建，这里写入 android.overridePathCheck=true 让它先跑起来。'
    Write-Warn2 '官方提示这种路径「多半仍会构建失败」；最稳的做法是把整个项目放到纯英文路径，例如 C:\dev\dictation_notepad。'

    $gradleProperties = Join-Path $AndroidDir 'gradle.properties'
    $line = 'android.overridePathCheck=true'
    $header = '# 项目路径含非 ASCII 字符时为 AGP 关掉路径检查（详见 README「已知限制」）'

    if (-not (Test-Path -LiteralPath $gradleProperties)) {
        Write-TextFile -Path $gradleProperties -Text ($header + "`r`n" + $line + "`r`n")
        Write-Ok "已新建 gradle.properties 并写入 $line"
        return
    }
    $text = Read-TextFile -Path $gradleProperties
    if ($text -match 'overridePathCheck') {
        Write-Skip 'gradle.properties 里已经有 overridePathCheck。'
        return
    }
    Write-TextFile -Path $gradleProperties -Text ($text.TrimEnd() + "`r`n" + $header + "`r`n" + $line + "`r`n")
    Write-Ok "已写入 $line"
}

# ----------------------------------------------------------------- Windows

function Update-WindowsRunner {
    param([string]$WindowsDir)

    $mainCpp = Join-Path $WindowsDir 'runner\main.cpp'
    if (-not (Test-Path -LiteralPath $mainCpp)) {
        Write-Warn2 "没找到 $mainCpp，跳过窗口标题设置。"
        return
    }
    $text = Read-TextFile -Path $mainCpp
    $original = $text

    # 窗口标题（保持 ASCII：MSVC 默认按系统代码页读源码，中文宽字面量会乱码）
    $text = [regex]::Replace($text, 'window\.Create\(L"[^"]*"', ('window.Create(L"' + $WindowTitle + '"'))

    # 初始窗口大小
    $text = $text -replace 'Win32Window::Size\s+size\([0-9]+,\s*[0-9]+\)', 'Win32Window::Size size(1180, 820)'

    if ($text -ne $original) {
        Write-TextFile -Path $mainCpp -Text $text
        Write-Ok "窗口标题/大小已设置（$mainCpp）"
    } else {
        Write-Skip "$mainCpp 不需要改动。"
    }
}

# -------------------------------------------------------------------- main

Write-Host ''
Write-Host '跨端听写记事本 - 平台脚手架引导' -ForegroundColor White
Write-Host "项目根目录：$ProjectRoot"
Write-Host ''

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml'))) {
    throw "在 $ProjectRoot 里没有找到 pubspec.yaml，请用 -ProjectRoot 指定正确的项目根目录。"
}

if (-not $SkipFlutterCreate) {
    Write-Step '检查 Flutter'
    # 优先用 PATH 里的 flutter；没配 PATH 但设了 FLUTTER_ROOT 也能跑。
    $flutterExe = $null
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -ne $flutterCmd) {
        $flutterExe = $flutterCmd.Source
    } elseif (-not [string]::IsNullOrWhiteSpace($env:FLUTTER_ROOT)) {
        $candidate = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
        if (Test-Path -LiteralPath $candidate) {
            $flutterExe = $candidate
        }
    }
    if ($null -eq $flutterExe) {
        throw 'PATH 里没有 flutter，也没有可用的 FLUTTER_ROOT。请先安装 Flutter（>= 3.19）并确保 flutter --version 能跑通。'
    }
    Write-Ok $flutterExe
    & $flutterExe --version

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("dictation_notepad_boot_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    Write-Step "在临时目录生成平台脚手架：$tempDir"
    & $flutterExe create --platforms=android,windows --org $Org --project-name $ProjectName $tempDir
    if ($LASTEXITCODE -ne 0) {
        throw "flutter create 失败（退出码 $LASTEXITCODE）。"
    }

    foreach ($dir in @('android', 'windows')) {
        $src = Join-Path $tempDir $dir
        if (-not (Test-Path -LiteralPath $src)) {
            throw "临时目录里没有生成 $dir。"
        }
        $dst = Join-Path $ProjectRoot $dir
        if (Test-Path -LiteralPath $dst) {
            Remove-Item -LiteralPath $dst -Recurse -Force
        }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        Write-Ok "已复制 $dir/"
    }

    foreach ($file in @('.metadata', '.gitignore')) {
        $src = Join-Path $tempDir $file
        $dst = Join-Path $ProjectRoot $file
        if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst)) {
            Copy-Item -LiteralPath $src -Destination $dst -Force
            Write-Ok "已复制 $file"
        }
    }

    if ($KeepGenerated) {
        Write-Ok "保留临时目录：$tempDir"
    } else {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Step '跳过 flutter create（-SkipFlutterCreate）'
}

Write-Step '打平台补丁'
Update-AndroidManifest -Path (Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml')
Update-AndroidGradle -AndroidDir (Join-Path $ProjectRoot 'android')
Update-AndroidGradleProperties -AndroidDir (Join-Path $ProjectRoot 'android') -RootToCheck $ProjectRoot
Update-WindowsRunner -WindowsDir (Join-Path $ProjectRoot 'windows')

Write-Host ''
Write-Host '完成。接下来：' -ForegroundColor White
Write-Host '  flutter pub get'
Write-Host '  flutter run -d windows          # Windows 桌面'
Write-Host '  flutter run -d <android设备ID>  # Android 手机（先开 USB 调试）'
Write-Host ''
Write-Host 'Android 首次进入后，选择文件夹时会申请「所有文件访问」权限，请务必允许，' -ForegroundColor DarkGray
Write-Host '否则重启后无法再按路径访问你选的文件夹。' -ForegroundColor DarkGray
Write-Host ''
