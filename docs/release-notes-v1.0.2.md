# v1.0.2 — 跨端听写记事本 / Cross Dictation Notepad

## 新增：进度条可以拖动了 / New: the progress bar is now draggable

以前只能靠 `-5s / -3s / -1s / +1s / +3s / +5s` 一下下点，想跳到很后面的位置要点很多次，很难用。
现在：

- **拖动**进度条（手机手指 / 电脑鼠标）即可跳转，**点击**进度条上任意位置也能直接跳过去；
- 拖动过程中会**实时预览**目标时间（显示 `松手跳到 03:24`），**松手才真正 seek** ——
  避免拖动过程中一路疯狂 seek 卡顿；
- 进度条上多了一个小圆点滑块，一眼能看出"这个可以拖"；
- `±1s / ±3s / ±5s` 按钮**保留**，用于听写时逐句精调。

Previously you could only nudge with the ±1/3/5s buttons. Now the bar is draggable and clickable,
previews the target time while dragging, and seeks on release; the ± buttons remain for fine tuning.

> 「不要时间轴」原本的诉求是**不做字幕时间轴**，并不是"进度条不能拖" —— 这次按实际使用体验修正了。

## 其它 / Other

- 版本号 1.0.1+2 → 1.0.2+3。
- 测试数 61 → **65**（新增 4 个进度条交互用例：拖动到一半松手才 seek、点击 3/4 处跳转、
  拖动中不 seek、时长为 0 时不崩也不回调）。
  整个项目 `flutter analyze` 零问题、`flutter test` 65/65 全绿。
- 进度条被重写成**不依赖播放器的纯组件**（`PlaybackProgress`，位置/时长/回调由外部传入），
  所以这些交互才能用单元测试覆盖。

## 下载 / Downloads

| 平台 | 文件 |
| --- | --- |
| Android 手机 | `dictation-notepad-android-release.apk` |
| Windows 电脑 | `dictation-notepad-windows-x64.zip`（解压后双击 `dictation_notepad.exe`，整目录一起用） |
