# v1.0.3 — 跨端听写记事本 / Cross Dictation Notepad

## 修复 1：Android 上输入法被换成「安全键盘」（搜狗 / 日文输入法调不出来）

**现象**：在 App 的编辑区点一下，弹出的不是自己装的输入法（比如搜狗），
而是系统那种「输密码时才会出现」的受限键盘，而且**打不出日文**。

**原因**：编辑框上设了 `enableSuggestions: false`。Android 上这个设置会给输入框打上
「不要建议 / 不要个性化学习」的标记，第三方输入法和日文输入法会被系统判定为
「不该在这儿工作」，于是退回受限键盘。

- Flutter 官方文档化过这个坑：[flutter/flutter#192714](https://github.com/flutter/flutter/pull/192714)
- 相关引擎改动：[flutter/engine#46037](https://github.com/flutter/engine/pull/46037)

**修复**：`enableSuggestions` 改回 `true`（并在代码里写了注释，防止以后又被"优化"掉）。
`autocorrect` 仍然是 `false` —— 听写时不希望输入法自动改写用词，而且它不影响输入法本身能否调起。

## 修复 2：重开 App 后视频进度回到 0

**现象**：杀掉 App 再打开，虽然回到了上次的工作页面（视频、TXT、光标、日夜模式都在），
但视频进度是从 0 开始的。

**原因**：`open()` 之后紧接着 `seek()`，在 Android 上这次 seek 有时会被丢掉
（时长/视频输出还没就绪）。保存那半边是好的（每 3 秒存一次 + 切后台/退出时存），
问题只在恢复时那次 seek 没生效。

**修复**：恢复进度时先等时长解析出来再 seek，seek 完再核对一次位置，没到位就补一次
（最多补 5 次，每次间隔 200ms）。

## 其它 / Other

- 版本号 1.0.2+3 → 1.0.3+4。
- `flutter analyze` 零问题、`flutter test` **65/65** 全绿。

## 下载 / Downloads

| 平台 | 文件 |
| --- | --- |
| Android 手机 | `dictation-notepad-android-release.apk` |
| Windows 电脑 | `dictation-notepad-windows-x64.zip`（解压后双击 `dictation_notepad.exe`，整目录一起用） |
