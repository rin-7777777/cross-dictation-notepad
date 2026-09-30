# 跨端听写记事本 · Cross Dictation Notepad

[中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

> 因为自己要做双语字幕，但是平时天天要往外跑碎片时间不太方便使用电脑，于是为了方便自己在手机上听写原文而写了这个东西，正好也方便了自己在电脑上的听写工作，以后再也不用开好几个窗口和好几个文档了。

播放**本地视频**，同时在**纯文本编辑区**把原文听写下来。Android 手机 + Windows 电脑，一套 Flutter 代码。

**刻意不做的事**：没有字幕时间轴、没有双语字幕、没有字幕格式、软件内没有导入导出、不联网、不做同步、不做数据迁移。只有「一个视频/音频文件夹 + 一个文本文件夹 + 一块纯文本」。

---

## 一、它是什么

- 你指定**一个视频/音频文件夹**和**一个文本文件夹**，软件只读这两个文件夹；
- 首页点「开始工作」→ 选视频 → 选一个 `.txt`，或者输入文件名新建一个；
- 进入工作区：上面放视频，下面写文本，视频下面一排 `-5s -3s -1s ⏯ +1s +3s +5s` 和 0.25x~2x 倍速；
- 边听边敲，停止输入后自动存回那个 `.txt`；下次打开自动回到上次的视频、进度、光标和日夜模式。

典型用法：听写外语原文、做双语字幕初稿、把课程/会议视频逐句敲下来。

## 二、功能一览

| 区域 | 能力 |
| --- | --- |
| 文件夹 | 首次启动分别选「视频/音频文件夹」「文本文件夹」，路径记住；设置里随时可改；带「检查权限」入口 |
| 列表 | 视频/音频文件夹按扩展名列出视频与音频（自然序：`第2课` 排在 `第10课` 前），文本文件夹只列 `.txt` |
| 新建文本 | 自己输入文件名（自动补 `.txt`），同名会问是否直接打开 |
| 视频 | 本地播放（media_kit / libmpv）；`±1s / ±3s / ±5s` 跳转；0.25x–2x 八档倍速；**可拖动 / 可点击跳转**的进度条 + `当前时间 / 总时长`；全屏按钮 |
| 音频 | `mp3 / m4a / flac / wav / ogg / opus / aac / wma / ape` 等一样能播；纯音频时上方显示「♪ 音频播放中 + 文件名」的面板，而不是一块黑框，进度条与 ±秒 按钮照常可用 |
| 布局 | 手机竖屏与电脑宽屏都是上下结构（上视频、下编辑），宽度上限 1280 |
| 编辑 | 输入 / 删除 / 复制粘贴 / 撤销 / 重做 / 查找替换（大小写开关、全部替换）/ 自动保存 |
| 状态栏 | 字符数、行数、光标行列、保存状态 |
| 侧边栏 | 撤销、重做、查找替换、保存、设置、视频/音频文件夹、文本文件夹 |
| 恢复 | 上次视频 + TXT + 播放进度 + 倍速 + 光标位置 + 日夜模式，全存在软件内部配置里 |
| 日夜 | 日间天蓝浅色 / 夜间黑深蓝；顶栏右上角一键切换 |

## 三、实测状态（Flutter 3.47.5 / Dart 3.13.4）

| 项目 | 结果 |
| --- | --- |
| `flutter pub get` | ✅ 依赖全部解析（media_kit 1.2.6 / media_kit_video 1.3.1 / file_picker 8.3.7 / permission_handler 11.4.0 / shared_preferences 2.5.5） |
| `flutter analyze` | ✅ **No issues found!**（23 个源文件 + 测试，零 error/warning/info） |
| `flutter test` | ✅ **70 / 70 全绿**（纯逻辑、编辑会话真文件读写、界面交互、进度条拖动跳转） |
| `flutter build apk --debug` | ✅ 成功（含 libmpv.so 三个 ABI） |
| `flutter build apk --release` | ✅ 成功，产物 `dist/dictation-notepad-android-release.apk`（约 147 MB） |
| `flutter build windows --release` | ✅ 成功（exe + 全部 DLL，含 `libmpv-2.dll`），启动冒烟测试通过：进程存活、media_kit 插件注册正常。构建需要 **VS Build Tools 2022（C++ 工作负载）** 和**符号链接权限**（开发者模式，或直接提权构建） |
| 真机 / 桌面 UI 逐项点测 | ✅ **已逐项点测通过**（Android 手机 + Windows 电脑）：视频与音频播放、进度条拖动跳转、±秒 跳转、倍速、全屏横竖屏切换、输入法、撤销/重做、查找替换、自动保存、杀掉重开恢复上次工作 |

> 详细记录（含实测踩到的真实问题与修法）见 [docs/测试清单.md](docs/测试清单.md)。

## 四、快速开始

### 环境要求

| 项目 | 要求 |
| --- | --- |
| Flutter | 3.19 及以上（实测 3.47.5） |
| Android 构建 | Android SDK（platform 34 与 36、build-tools 35/36）、JDK 17+ |
| Windows 构建 | **Visual Studio 2022** + 「使用 C++ 的桌面开发」工作负载 + Windows SDK（Flutter 硬性要求） |
| 其它 | Windows 上构建带插件的项目需要**开启开发者模式**（符号链接）：`start ms-settings:developers` |

### 跑起来

```bash
flutter pub get
flutter run -d windows          # 电脑（需要 Visual Studio）
flutter devices                 # 看手机设备 id
flutter run -d <设备id>          # 手机
```

`android/` 和 `windows/` 平台目录**已经在仓库里**（用 Flutter 3.47.5 生成并打好补丁）。
只有升级 Flutter 大版本、或平台目录被改坏时，才需要重新生成：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_platforms.ps1
```

脚本只写 `android/` 与 `windows/`，**绝不碰 `lib/`、`pubspec.yaml` 和你的 TXT**，并自动打上：

| 改哪里 | 改什么 |
| --- | --- |
| `AndroidManifest.xml` | 存储权限（含 `MANAGE_EXTERNAL_STORAGE`）、中文应用名、`requestLegacyExternalStorage` |
| `android/app/build.gradle.kts` | `minSdk 24`、`packaging.jniLibs.useLegacyPackaging` + `keepDebugSymbols` |
| `android/build.gradle.kts` | 统一所有插件子工程的 `compileSdk`（解决 file_picker 与 lifecycle 的 AAR 冲突） |
| `android/gradle.properties` | 路径含非 ASCII 字符时写入 `android.overridePathCheck=true` |
| `windows/runner/main.cpp` | 窗口标题与初始尺寸 |

### 打包

```bash
flutter build apk --release       # 手机安装包 → build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release   # 电脑版 → build/windows/x64/runner/Release/
```

Windows 桌面版编好后，用仓库脚本一步生成**桌面快捷方式**：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
```

## 五、⚠️ 项目路径必须是纯 ASCII（重要）

实测踩出来的、最容易让人卡住的一条：**把项目放在纯英文路径下**，例如
`C:\dev\cross-dictation-notepad`。放在含中文的路径下会依次遇到：

1. `flutter analyze` 的分析服务器崩溃（LSP 消息被截断：`FormatException: Unterminated string`）；
2. **release 构建失败**（Android 与 Windows 都会）：AOT 编译器拿到乱码路径、读不到 `app.dill`
   （`Unable to read file: C:\锟斤拷...app.dill`）；
3. Flutter SDK 若也在中文路径下，着色器编译器（impellerc）取到乱码路径而失败；
4. Android Gradle 插件直接拒绝（`Your project path contains non-ASCII characters`）。

脚本会自动写 `android.overridePathCheck=true` 兜底第 4 条，前三条只能靠换路径解决。

## 六、Android 权限（第一次用必读）

软件要在**重启之后**仍然按真实路径读写你选的文件夹，所以用的是 Android 的
**「所有文件访问」**（`MANAGE_EXTERNAL_STORAGE`），而不是 SAF 的一次性授权：

1. 只有真实路径才能被 libmpv（media_kit）直接打开，SAF 给的是 `content://`，播放器读不了；
2. 重启后依然有效，不用每次重新授权；
3. Android 与 Windows 共用同一套 `dart:io` 代码，行为一致。

首次选文件夹时会弹出授权页，**请打开「允许管理所有文件」**；误点拒绝可以到
「系统设置 → 应用 → 听写记事本 → 权限」里补，也可以在设置里点「检查权限」。
因为这个权限，**它不适合上架 Google Play，请自行安装 APK 使用**。

## 七、数据与恢复

- **软件内部配置**（SharedPreferences）里存：两个文件夹路径、日夜模式、自动保存间隔、
  上次的视频与 TXT、播放进度、倍速、光标位置。**不会写进你的工作文件夹**。
- TXT 里**只有正文**，没有任何元数据；视频/音频文件夹不会被写入任何文件。
- 下次启动自动恢复上次工作（可在设置里关掉）。视频恢复后是暂停状态，点播放继续。
- **换设备**：用系统文件管理器把两个文件夹拷过去，在新设备上重新选一次文件夹即可。
  播放进度与光标**不跟着走**（这是刻意的）。

## 八、目录结构

```
├── lib/                     业务代码（23 个文件）
│   ├── core/                文件名规则、时间格式、文件夹与文本文件服务、内部配置
│   ├── editor/              撤销栈、查找替换引擎、编辑会话（自动保存）
│   ├── player/              media_kit 封装（打开 / 跳转 / 调速 / 进度）
│   └── ui/                  主题、首页、初始设置、选择页、工作区、设置面板、各种控件
├── test/                    61 个用例（含真文件读写的编辑会话测试与界面测试）
├── android/ windows/        平台工程（已生成并打好补丁）
├── tool/
│   ├── bootstrap_platforms.ps1   重新生成并修补平台目录
│   └── build_windows.ps1         一键编译 Windows 版 + 建桌面快捷方式
├── docs/测试清单.md          实测记录 + 手工测试清单
└── dist/                    打包产物（不提交进 git）
```

## 九、已知限制

- **分发 Windows 版要拷整个文件夹**：产物是「一个文件夹」（exe + 若干 DLL + `data/`），
  分发时要整个文件夹一起拷。构建需要 Visual Studio 2022 的 C++ 桌面开发工作负载，
  以及**符号链接权限**（开启开发者模式并重启，或者以管理员身份构建）。
- **已在 Android 手机与 Windows 电脑上逐项点测通过**（2026-10）：视频与音频播放、进度条拖动、
  ±秒 跳转、倍速、全屏与横竖屏切换、输入法、撤销/重做、查找替换、自动保存、杀掉重开恢复上次工作。
- **release APK 用的是 Android 调试证书签名**（Flutter 模板默认）：可以直装，但不能上架。
  上架请自行配置 `android/app/build.gradle.kts` 里的 `signingConfig`。
- 没装 NDK 时 `libflutter.so` 不会被剥离符号，APK 偏大（release 约 147 MB；正常 40–60 MB）。
  装了 NDK 后删掉 `keepDebugSymbols += "**/*.so"` 这一行即可显著瘦身。
- 文本一律按 **UTF-8** 读写；打开非 UTF-8 的旧文件会显示乱码（仍可编辑并保存为 UTF-8）。
- 进度条可以拖动或点击跳转（拖动时显示预览时间，松手才真正跳），`±1s / ±3s / ±5s` 用于精调。

## 十、常见问题

| 现象 | 处理 |
| --- | --- |
| `flutter analyze` 崩溃 / release 报 `Unable to read file: ...app.dill` | 项目路径含中文，换成纯英文路径 |
| Android 构建报 `Your project path contains non-ASCII characters` | 同上；脚本已写 `overridePathCheck=true` 兜底 |
| 卡在 `sdkmanager` / 提示缺 NDK | 装 NDK：`sdkmanager --install "ndk;28.2.13676358"`；不想装就保留 `keepDebugSymbols` |
| `:file_picker:checkDebugAarMetadata` 要求 compileSdk 36 | 根 `build.gradle.kts` 里的统一补丁已在仓库；被覆盖时重跑 bootstrap 脚本 |
| 打包报 `android:extractNativeLibs is set to "true"` | AGP 8 已禁止，改用构建脚本里的 `packaging.jniLibs.useLegacyPackaging`（仓库里已改好） |
| 手机上选完文件夹、重启后列表为空 | 「所有文件访问」没真的打开，去系统设置里开 |
| Windows 提示 `Building with plugins requires symlink support` | 开启开发者模式：`start ms-settings:developers` |
| 视频黑屏只有声音 | 换一个 H.264/AAC 的 mp4 复现，并把 media_kit 的报错文本一起提 issue |
| 手机上是系统「安全键盘」、打不出日文 | 已修（v1.0.3）：编辑框的 `enableSuggestions` 必须是 true |
| 手机重开后视频进度回到 0 | 已修（v1.0.3）：恢复进度时等时长解析出来再 seek |

## 十一、许可

本项目采用 **MIT 许可证**，全文见 [LICENSE](LICENSE)。

第三方依赖保留各自的许可证（Flutter BSD-3-Clause、media_kit MIT、file_picker MIT、
permission_handler MIT、shared_preferences BSD-3-Clause）。另外提醒：打包产物里含有
libmpv（mpv）二进制，分发时请一并遵守它的许可证（LGPL-2.1-or-later / GPLv2-or-later，
以实际构建为准）。