import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit（libmpv）必须在创建 Player 之前初始化。
  MediaKit.ensureInitialized();
  final store = await SettingsStore.load();
  runApp(DictationApp(store: store));
}
