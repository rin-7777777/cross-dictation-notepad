# クロスプラットフォーム聴写ノート · 跨端听写记事本

[中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

> 自分でバイリンガル字幕を作っているのですが、普段は外に出ていることが多く、スキマ時間に
> PC を使うのが面倒でした。そこで、スマホで原文を聴写するために作ったのがこれです。
> おかげで PC での聴写作業も楽になり、もう複数のウィンドウと複数のドキュメントを
> 開かなくて済みます。

**ローカル動画**を再生しながら、**プレーンテキスト欄**に原文を聴写するアプリです。
Android スマホと Windows PC を 1 つの Flutter コードでカバーします。

**あえて入れていないもの**：字幕タイムライン、バイリンガル字幕、字幕フォーマット、アプリ内の
インポート/エクスポート、ネットワーク、同期、データ移行。あるのは「動画フォルダ 1 つ +
テキストフォルダ 1 つ + プレーンテキスト欄」だけです。

---

## 1. これは何か

- **動画フォルダ**と**テキストフォルダ**を 1 つずつ指定すると、アプリはその 2 つだけを読みます。
- ホームで「開始」→ 動画を選ぶ → `.txt` を選ぶ、またはファイル名を入力して新規作成。
- ワークスペース：上が動画、下がテキスト。動画の下に `-5s -3s -1s ⏯ +1s +3s +5s` のボタン列と
  0.25x〜2x の速度選択。
- 聞きながら入力し、入力が止まると自動でその `.txt` に保存。次回起動時は前回の動画・再生位置・
  カーソル位置・ライト/ダークモードまで復元します。

主な用途：外国語原文の聴写、バイリンガル字幕の下書き、講義や会議の動画を 1 文ずつ書き起こす、など。

## 2. 機能一覧

| 領域 | 内容 |
| --- | --- |
| フォルダ | 初回起動で「動画フォルダ」「テキストフォルダ」を選択。パスは記憶され、設定でいつでも変更可。「権限を確認」も用意 |
| 一覧 | 動画フォルダは拡張子で動画のみ（自然順：`第2課` が `第10課` より前）、テキストフォルダは `.txt` のみ |
| 新規テキスト | ファイル名を自分で入力（`.txt` は自動付与）。同名があれば開くか確認 |
| 動画 | ローカル再生（media_kit / libmpv）、`±1s / ±3s / ±5s` ジャンプ、0.25x〜2x の 8 段階、**ドラッグ / タップでシークできる**進捗バーと `現在位置 / 全体`、全画面ボタン |
| レイアウト | スマホ縦持ちでもワイドな PC でも上下レイアウト（上：動画、下：エディタ）、最大幅 1280 |
| 編集 | 入力 / 削除 / コピー＆ペースト / 元に戻す / やり直し / 検索と置換（大文字小文字の切り替え、すべて置換）/ 自動保存 |
| ステータスバー | 文字数、行数、カーソル位置（行:列）、保存状態 |
| サイドバー | 元に戻す、やり直し、検索と置換、保存、設定、動画フォルダ、テキストフォルダ |
| 復元 | 前回の動画 + TXT + 再生位置 + 速度 + カーソル位置 + ライト/ダークモード。すべてアプリ内部の設定に保存 |
| ライト/ダーク | ライトは空色、ダークは黒〜濃紺。アプリバー右上でワンタップ切り替え |

## 3. 検証状況（Flutter 3.47.5 / Dart 3.13.4）

| 項目 | 結果 |
| --- | --- |
| `flutter pub get` | ✅ 依存関係すべて解決（media_kit 1.2.6 / media_kit_video 1.3.1 / file_picker 8.3.7 / permission_handler 11.4.0 / shared_preferences 2.5.5） |
| `flutter analyze` | ✅ **No issues found!**（ソース 23 ファイル + テスト、error/warning/info ゼロ） |
| `flutter test` | ✅ **65 / 65 すべて成功**（純粋なロジック、実ファイル入出力を伴うエディタセッション、UI 操作、進捗バーのシーク） |
| `flutter build apk --debug` | ✅ 成功（3 ABI 分の `libmpv.so` を含む） |
| `flutter build apk --release` | ✅ 成功 → `dist/dictation-notepad-android-release.apk`（約 147 MB） |
| `flutter build windows --release` | ✅ 成功（exe + すべての DLL、`libmpv-2.dll` を含む）。起動スモークテストも通過：プロセスが生存し、media_kit プラグインが登録される。ビルドには **VS Build Tools 2022（C++ ワークロード）** と**シンボリックリンク権限**（開発者モード、または管理者としてビルド）が必要 |
| スマホ / デスクトップ UI の通し操作 | ⚠️ **未実施**：開発マシンに実機もエミュレータもなし。デスクトップ版は起動スモークテストのみで、UI を一通り操作してはいません |

> 詳細（テスト中に実際に踏んだ問題と対処）は [docs/测试清单.md](docs/测试清单.md)（中国語）にあります。

## 4. はじめかた

### 必要な環境

| 項目 | 要件 |
| --- | --- |
| Flutter | 3.19 以上（3.47.5 で検証） |
| Android ビルド | Android SDK（platform 34 と 36、build-tools 35/36）、JDK 17 以上 |
| Windows ビルド | **Visual Studio 2022** の「C++ によるデスクトップ開発」ワークロード + Windows SDK（Flutter の必須要件） |
| その他 | Windows でプラグイン入りプロジェクトをビルドするには**開発者モード**（シンボリックリンク）が必要：`start ms-settings:developers` |

### 実行

```bash
flutter pub get
flutter run -d windows          # PC（Visual Studio が必要）
flutter devices                 # スマホのデバイス ID を確認
flutter run -d <デバイスID>      # スマホ
```

`android/` と `windows/` のプラットフォームフォルダは**このリポジトリに含まれています**
（Flutter 3.47.5 で生成し、パッチ済み）。再生成が必要なのは Flutter のメジャーアップグレード後か、
プラットフォームフォルダを壊してしまったときだけです：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_platforms.ps1
```

このスクリプトは `android/` と `windows/` だけを書き換え、**`lib/`、`pubspec.yaml`、
あなたの TXT には一切触れません**。適用されるパッチ：

| 対象 | 内容 |
| --- | --- |
| `AndroidManifest.xml` | ストレージ権限（`MANAGE_EXTERNAL_STORAGE` を含む）、中国語のアプリ名、`requestLegacyExternalStorage` |
| `android/app/build.gradle.kts` | `minSdk 24`、`packaging.jniLibs.useLegacyPackaging` + `keepDebugSymbols` |
| `android/build.gradle.kts` | プラグインのサブプロジェクトの `compileSdk` を統一（file_picker と lifecycle の AAR 衝突を解消） |
| `android/gradle.properties` | パスに非 ASCII 文字がある場合 `android.overridePathCheck=true` を書き込み |
| `windows/runner/main.cpp` | ウィンドウタイトルと初期サイズ |

### パッケージング

```bash
flutter build apk --release       # スマホ用 → build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release   # PC 用 → build/windows/x64/runner/Release/
```

Windows 版をビルドしたあと、次のスクリプトで**デスクトップショートカット**を作れます：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
```

## 5. ⚠️ プロジェクトのパスは ASCII のみに（重要）

実機検証でいちばん厄介だった点です。**プロジェクトは純粋な英数字パス**（例：
`C:\dev\cross-dictation-notepad`）に置いてください。中国語などの非 ASCII 文字がパスに入ると、
順番に次の問題が起きます：

1. `flutter analyze` がクラッシュ（解析サーバーの LSP メッセージが切れる：
   `FormatException: Unterminated string`）；
2. **release ビルドが失敗**：AOT コンパイラが文字化けしたパスを受け取り `app.dill` を読めない
   （`Unable to read file: C:\???...app.dill`）；
3. Flutter SDK 自体が非 ASCII パスにあると、シェーダコンパイラ（impellerc）が文字化けパスで失敗；
4. Android Gradle Plugin が明確に拒否
   （`Your project path contains non-ASCII characters`）。

スクリプトは 4 を回避するために `android.overridePathCheck=true` を書き込みますが、
1〜3 はパスを移す以外に解決できません。

## 6. Android の権限（初回利用の前に）

再起動後も選んだフォルダを**実パスで**読み書きし続けるため、SAF の一時的な許可ではなく
Android の**「すべてのファイルへのアクセス」**（`MANAGE_EXTERNAL_STORAGE`）を使います：

1. libmpv（media_kit）が直接開けるのは実パスだけで、SAF が渡す `content://` は読めない；
2. 再起動後も有効で、毎回の再許可が不要；
3. Android と Windows が同じ `dart:io` のコードを共有でき、挙動が一致する。

初回のフォルダ選択時に権限画面が出るので、**「すべてのファイルの管理を許可」をオン**にして
ください。拒否した場合は「設定 → アプリ → 聴写ノート → 権限」で戻すか、アプリ内の
「権限を確認」から再要求できます。この権限のため **Google Play での配信には向きません。
APK を直接インストールして使ってください**。

## 7. データと復元

- **アプリ内部の設定**（SharedPreferences）に保存：2 つのフォルダパス、ライト/ダークモード、
  自動保存の間隔、前回の動画と TXT、再生位置、速度、カーソル位置。
  **作業フォルダには何も書き込みません**。
- TXT には**本文だけ**が入ります（メタデータなし）。動画フォルダにも一切書き込みません。
- 次回起動時に前回の作業を自動復元（設定でオフにできます）。動画は一時停止状態で復元されるので、
  再生ボタンで続きから。
- **端末の引っ越し**：ファイルマネージャで 2 つのフォルダをコピーし、新しい端末で選び直すだけ。
  再生位置とカーソルは**引き継ぎません**（意図的な仕様）。

## 8. ディレクトリ構成

```
├── lib/                     アプリ本体（23 ファイル）
│   ├── core/                ファイル名規則、時刻整形、フォルダ/テキストファイル処理、内部設定
│   ├── editor/              元に戻すスタック、検索置換エンジン、編集セッション（自動保存）
│   ├── player/              media_kit ラッパー（オープン / シーク / 速度 / 進捗）
│   └── ui/                  テーマ、ホーム、初回設定、選択画面、ワークスペース、設定、各種ウィジェット
├── test/                    61 ケース（実ファイル入出力を含むエディタセッション、UI テスト）
├── android/ windows/        プラットフォームプロジェクト（生成済み・パッチ済み）
├── tool/
│   ├── bootstrap_platforms.ps1   プラットフォームフォルダの再生成とパッチ
│   └── build_windows.ps1         Windows 版のワンクリックビルド + デスクトップショートカット
├── docs/测试清单.md          検証記録（中国語）+ 手動テストチェックリスト
└── dist/                    ビルド成果物（git には含めません）
```

## 9. 既知の制限

- **Windows デスクトップ版はビルドできますが、UI の通し操作は未実施**：成果物は
  「フォルダ 1 つ」（exe + 複数の DLL + `data/`）なので、配布時はフォルダごとコピーしてください。
  ビルドには Visual Studio 2022 の C++ デスクトップワークロードと**シンボリックリンク権限**
  （開発者モードを有効化して再起動、または管理者としてビルド）が必要です。
- **スマホ版は実機で動かしていません**（開発マシンに実機もエミュレータもなし）：
  APK はビルドでき `apksigner` の検証も通りますが、UI を実際に操作してはいません。
  初回の実機確認は [docs/测试清单.md](docs/测试清单.md) の第 4 節に沿って行ってください。
- **release APK は Android のデバッグ鍵で署名されています**（Flutter テンプレートの既定）：
  直接インストールは可能ですが、ストア配信には使えません。必要なら
  `android/app/build.gradle.kts` の `signingConfig` を設定してください。
- NDK が無いと `libflutter.so` のシンボルが削除されず APK が大きくなります
  （release で約 147 MB、本来は 40〜60 MB）。NDK を入れて
  `keepDebugSymbols += "**/*.so"` の行を消せば小さくなります。
- テキストは常に **UTF-8** で読み書きします。非 UTF-8 の古いファイルは文字化けして表示されますが、
  編集して UTF-8 として保存できます。
- 進捗バーはドラッグまたはタップでシークできます（ドラッグ中は移動先の時刻をプレビューし、離した時にシーク）。

## 10. トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| `flutter analyze` がクラッシュ / release で `Unable to read file: ...app.dill` | パスに非 ASCII 文字があります。ASCII のみのパスへ移動 |
| Android ビルドで `Your project path contains non-ASCII characters` | 同上。スクリプトが `overridePathCheck=true` を書き込みますが根本解決はパス移動 |
| `sdkmanager` で止まる / NDK が無いと言われる | NDK を導入：`sdkmanager --install "ndk;28.2.13676358"`。入れたくない場合は `keepDebugSymbols` を残す |
| `:file_picker:checkDebugAarMetadata` が compileSdk 36 を要求 | ルート `build.gradle.kts` の統一パッチが入っています。上書きされたら bootstrap スクリプトを再実行 |
| パッケージ時に `android:extractNativeLibs is set to "true"` | AGP 8 では禁止。ビルドスクリプトの `packaging.jniLibs.useLegacyPackaging` を使用（本リポジトリは対応済み） |
| スマホでフォルダ選択後に再起動すると一覧が空 | 「すべてのファイルへのアクセス」が実際には許可されていません。システム設定で有効化 |
| Windows で `Building with plugins requires symlink support` | 開発者モードを有効化：`start ms-settings:developers` |
| 映像が真っ黒で音だけ聞こえる | H.264/AAC の mp4 で再現確認し、media_kit のエラー文言と一緒に issue で報告 |

## 11. ライセンス

現時点でオープンソースライセンスは付けていません。公開する場合は `LICENSE`（MIT など）を
追加することをおすすめします — 判断はお任せします。
