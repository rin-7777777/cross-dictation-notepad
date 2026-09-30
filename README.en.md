# Cross Dictation Notepad · 跨端听写记事本

[中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

> I make bilingual subtitles myself, but I'm always out and about, so using a PC in those odd
> spare moments was awkward. I wrote this so I could dictate the source text on my phone —
> and it turned out to be handy for my dictation work on the PC too. No more juggling several
> windows and several documents.

Play a **local video** while typing the source text into a **plain-text editor**. One Flutter
codebase for **Android phones and Windows PCs**.

**Deliberately not included**: no subtitle timeline, no bilingual subtitles, no subtitle formats, no
import/export inside the app, no network, no sync, no data migration. Just "one video/audio folder +
one text folder + one plain-text box".

---

## 1. What it is

- You pick **one video/audio folder** and **one text folder**; the app only reads those two.
- Home → "Start working" → pick a video → pick a `.txt`, or type a name to create one.
- Workspace: video on top, text below, with a row of `-5s -3s -1s ⏯ +1s +3s +5s` buttons and
  0.25x–2x speed.
- Type while listening; after you stop typing it saves straight back to that `.txt`. Next launch
  it returns to the same video, position, cursor and light/dark mode.

Typical use: dictating foreign-language source text, drafting bilingual subtitles, transcribing
course or meeting videos line by line.

## 2. Features

| Area | What it does |
| --- | --- |
| Folders | Pick the video/text folder on first launch, paths are remembered, changeable in Settings, with a "check permission" entry |
| Lists | Video/audio folder lists both videos and audio by extension (natural order: `Lesson2` before `Lesson10`); text folder lists only `.txt` |
| New text | Type the file name yourself (`.txt` is appended); if it exists you are asked whether to open it |
| Video | Local playback (media_kit / libmpv); `±1s / ±3s / ±5s` jumps; eight speeds from 0.25x to 2x; a **draggable / tappable** progress bar with `position / duration`; fullscreen button |
| Audio | Plays `mp3 / m4a / flac / wav / ogg / opus / aac / wma / ape` as well; for audio-only files the top area shows a "♪ audio playing" panel instead of a black box, and the seek bar / ± buttons work the same |
| Layout | Top/bottom layout on both phone portrait and wide desktop (video above, editor below), max width 1280 |
| Editing | Type / delete / copy-paste / undo / redo / find & replace (case toggle, replace all) / autosave |
| Status bar | Character count, line count, cursor line:column, save state |
| Sidebar | Undo, redo, find & replace, save, settings, video/audio folder, text folder |
| Restore | Last video + TXT + playback position + speed + cursor + light/dark mode, all in internal config |
| Light/Dark | Sky-blue light theme / near-black-and-deep-blue dark theme, one tap in the app bar |

## 3. Verified status (Flutter 3.47.5 / Dart 3.13.4)

| Step | Result |
| --- | --- |
| `flutter pub get` | ✅ all dependencies resolved (media_kit 1.2.6 / media_kit_video 1.3.1 / file_picker 8.3.7 / permission_handler 11.4.0 / shared_preferences 2.5.5) |
| `flutter analyze` | ✅ **No issues found!** (23 source files + tests, zero error/warning/info) |
| `flutter test` | ✅ **70 / 70 passing** (pure logic, editor session with real file I/O, UI interactions, progress-bar seeking) |
| `flutter build apk --debug` | ✅ succeeded (with `libmpv.so` for three ABIs) |
| `flutter build apk --release` | ✅ succeeded → `dist/dictation-notepad-android-release.apk` (~147 MB) |
| `flutter build windows --release` | ✅ succeeded (exe + all DLLs incl. `libmpv-2.dll`); launch smoke test passed: the process stays alive and the media_kit plugin registers. Requires **VS Build Tools 2022 (C++ workload)** and **symlink support** (Developer Mode, or build elevated) |
| Tapping through the phone / desktop UI | ✅ **done** — verified item by item on an Android phone and on Windows: video & audio playback, drag-to-seek, ±s jumps, speed, fullscreen rotation, IME, undo/redo, find & replace, autosave, restore after killing the app |

> Full notes (including the real problems hit while testing and how they were fixed) are in
> [docs/测试清单.md](docs/测试清单.md) (Chinese).

## 4. Quick start

### Requirements

| Item | Requirement |
| --- | --- |
| Flutter | 3.19 or newer (verified on 3.47.5) |
| Android build | Android SDK (platforms 34 and 36, build-tools 35/36), JDK 17+ |
| Windows build | **Visual Studio 2022** with the "Desktop development with C++" workload + Windows SDK (hard requirement of Flutter) |
| Other | On Windows, building a project with plugins needs **Developer Mode** (symlink support): `start ms-settings:developers` |

### Run it

```bash
flutter pub get
flutter run -d windows          # PC (needs Visual Studio)
flutter devices                 # list phone device ids
flutter run -d <device-id>      # phone
```

The `android/` and `windows/` platform folders are **already in this repository** (generated with
Flutter 3.47.5 and patched). You only need to regenerate them after a major Flutter upgrade or if
they get damaged:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_platforms.ps1
```

The script only writes `android/` and `windows/` — it **never touches `lib/`, `pubspec.yaml` or
your TXT files** — and applies these patches:

| File | Patch |
| --- | --- |
| `AndroidManifest.xml` | Storage permissions (incl. `MANAGE_EXTERNAL_STORAGE`), Chinese app name, `requestLegacyExternalStorage` |
| `android/app/build.gradle.kts` | `minSdk 24`, `packaging.jniLibs.useLegacyPackaging` + `keepDebugSymbols` |
| `android/build.gradle.kts` | Unify `compileSdk` across plugin subprojects (fixes the file_picker vs. lifecycle AAR conflict) |
| `android/gradle.properties` | Writes `android.overridePathCheck=true` when the path contains non-ASCII characters |
| `windows/runner/main.cpp` | Window title and initial size |

### Packaging

```bash
flutter build apk --release       # phone package → build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release   # PC build → build/windows/x64/runner/Release/
```

After a Windows build, one script creates the **desktop shortcut** for you:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
```

## 5. ⚠️ Keep the project path pure ASCII (important)

This is the one that bit us hardest in real testing: **put the project in an all-ASCII path**, for
example `C:\dev\cross-dictation-notepad`. With non-ASCII (e.g. Chinese) characters in the path you
will hit, in order:

1. `flutter analyze` crashes (the analysis server's LSP message gets truncated:
   `FormatException: Unterminated string`);
2. **release builds fail**: the AOT compiler receives a mojibake path and cannot read `app.dill`
   (`Unable to read file: C:\???...app.dill`);
3. if the Flutter SDK itself sits in a non-ASCII path, the shader compiler (impellerc) fails on the
   mojibake path;
4. the Android Gradle Plugin refuses outright
   (`Your project path contains non-ASCII characters`).

The script writes `android.overridePathCheck=true` to work around (4), but (1)–(3) can only be
avoided by moving the project.

## 6. Android permission (read before first use)

So the app can keep reading and writing the folders you picked **even after a restart**, it uses
Android's **"All files access"** (`MANAGE_EXTERNAL_STORAGE`) instead of a one-shot SAF grant:

1. only a real path can be opened directly by libmpv (media_kit); SAF hands out `content://`,
   which the player cannot read;
2. it survives restarts, so you don't re-authorise every time;
3. Android and Windows share the same `dart:io` code path, so behaviour is identical.

When you pick a folder for the first time, **allow "manage all files"**. If you decline, you can
re-enable it under Settings → Apps → Dictation Notepad → Permissions, or tap "check permission"
inside the app. Because of this permission the app **cannot be published on Google Play — install
the APK yourself**.

## 7. Data and restore

- **Internal config** (SharedPreferences) stores: both folder paths, light/dark mode, autosave
  delay, last video and TXT, playback position, speed, cursor position. **Nothing is written into
  your working folders.**
- The TXT contains **only the text** — no metadata; the video/audio folder is never written to.
- On the next launch it restores the last session automatically (can be disabled in Settings).
  Playback resumes paused; press play to continue.
- **Moving to another device**: copy the two folders with your file manager and pick them again on
  the new device. Playback position and cursor **do not travel with them** (by design).

## 8. Project layout

```
├── lib/                     app code (23 files)
│   ├── core/                file-name rules, time formatting, folder/text-file services, config
│   ├── editor/              undo stack, find & replace engine, editor session (autosave)
│   ├── player/              media_kit wrapper (open / seek / rate / position)
│   └── ui/                  theme, home, first-run setup, picker, workspace, settings, widgets
├── test/                    61 cases (incl. real file I/O for the editor session and UI tests)
├── android/ windows/        platform projects (generated and patched)
├── tool/
│   ├── bootstrap_platforms.ps1   regenerate and patch the platform folders
│   └── build_windows.ps1         one-click Windows build + desktop shortcut
├── docs/测试清单.md          test log (Chinese) + manual test checklist
└── dist/                    build artefacts (not committed)
```

## 9. Known limitations

- **Distributing the Windows build means copying the whole folder**: the output is a
  *folder* (exe + several DLLs + `data/`) — distribute the whole folder, not just the exe. Building
  needs Visual Studio 2022 with the C++ desktop workload and **symlink support** (enable Developer
  Mode and reboot, or build elevated).
- **Verified item by item on a real Android phone and on Windows** (2026-10): video & audio
  playback, drag-to-seek, ±s jumps, speed, fullscreen and portrait/landscape switching, IME,
  undo/redo, find & replace, autosave, restore after killing the app.
- **The release APK is signed with the Android debug key** (Flutter's template default): fine for
  sideloading, not for publishing. Configure `signingConfig` in
  `android/app/build.gradle.kts` if you need a store build.
- Without an NDK, `libflutter.so` is not stripped, so the APK is large (release ≈ 147 MB; it would
  normally be 40–60 MB). Install the NDK and delete the `keepDebugSymbols += "**/*.so"` line to
  slim it down.
- Text is always read/written as **UTF-8**; opening a legacy non-UTF-8 file shows mojibake (you can
  still edit and save it as UTF-8).
- The progress bar can be dragged or tapped to seek (it previews the target time while dragging and
  seeks on release); `±1s / ±3s / ±5s` are for fine adjustment. "No timeline" means no *subtitle*
  timeline, not an unseekable bar.

## 10. Troubleshooting

| Symptom | Fix |
| --- | --- |
| `flutter analyze` crashes / release build says `Unable to read file: ...app.dill` | the project path contains non-ASCII characters — move it to an ASCII path |
| Android build: `Your project path contains non-ASCII characters` | same as above; the script already writes `overridePathCheck=true` as a fallback |
| Stuck on `sdkmanager` / NDK errors | install the NDK: `sdkmanager --install "ndk;28.2.13676358"`; or keep `keepDebugSymbols` and skip it |
| `:file_picker:checkDebugAarMetadata` demands compileSdk 36 | the unification patch lives in the root `build.gradle.kts`; re-run the bootstrap script if it was overwritten |
| Packaging error `android:extractNativeLibs is set to "true"` | banned in AGP 8 — use `packaging.jniLibs.useLegacyPackaging` in the build script (already patched here) |
| Phone: folder list is empty after a restart | "All files access" was not really granted — enable it in system settings |
| Windows: `Building with plugins requires symlink support` | enable Developer Mode: `start ms-settings:developers` |
| Video is black but audio plays | reproduce with an H.264/AAC mp4 and report it together with media_kit's error text |
| Phone shows the system "secure keyboard" and cannot type Japanese | fixed in v1.0.3: the editor's `enableSuggestions` must stay true |
| Video position resets to 0 after reopening on a phone | fixed in v1.0.3: the restore path now waits for the duration before seeking |

## 11. License

This project is released under the **MIT License** — see [LICENSE](LICENSE).

Third-party dependencies keep their own licenses (Flutter BSD-3-Clause, media_kit MIT,
file_picker MIT, permission_handler MIT, shared_preferences BSD-3-Clause). Note that the
packaged builds bundle a libmpv (mpv) binary, so distributing them also means complying with
its license (LGPL-2.1-or-later / GPLv2-or-later, depending on the build).