import 'dart:io';

import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 恢复上次工作需要的最小信息集合。
///
/// 只从软件内部配置（SharedPreferences）读出来，绝不写进用户的工作文件夹。
class ResumeData {
  const ResumeData({
    required this.videoPath,
    required this.textPath,
    required this.videoPositionMs,
    required this.rate,
    required this.selectionBase,
    required this.selectionExtent,
  });

  final String videoPath;
  final String textPath;
  final int videoPositionMs;
  final double rate;
  final int selectionBase;
  final int selectionExtent;
}

/// 软件内部配置：两个文件夹路径、日夜模式、自动保存间隔、上次工作状态。
///
/// 是一个 [ChangeNotifier]，界面通过 `SettingsScope` 监听它，改动后立即生效。
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs);

  static const String _kVideoFolder = 'video_folder';
  static const String _kTextFolder = 'text_folder';
  static const String _kThemeMode = 'theme_mode';
  static const String _kAutoSaveMillis = 'auto_save_millis';
  static const String _kRestoreLastSession = 'restore_last_session';
  static const String _kVideoCompatibilityMode = 'video_compatibility_mode';
  static const String _kLastVideoPath = 'last_video_path';
  static const String _kLastTextPath = 'last_text_path';
  static const String _kLastVideoPosMs = 'last_video_pos_ms';
  static const String _kLastRate = 'last_rate';
  static const String _kLastSelBase = 'last_sel_base';
  static const String _kLastSelExtent = 'last_sel_extent';

  /// 自动保存的可选档位：慢 / 标准 / 快（毫秒）。
  static const List<int> autoSaveOptions = <int>[2000, 1200, 600];
  static const int defaultAutoSaveMillis = 1200;

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }

  // ---------------------------------------------------------------- 文件夹

  String? get videoFolder => _nullIfBlank(_prefs.getString(_kVideoFolder));
  String? get textFolder => _nullIfBlank(_prefs.getString(_kTextFolder));

  bool get hasBothFolders => videoFolder != null && textFolder != null;

  Future<void> setVideoFolder(String? path) async {
    await _writeString(_kVideoFolder, path);
    notifyListeners();
  }

  Future<void> setTextFolder(String? path) async {
    await _writeString(_kTextFolder, path);
    notifyListeners();
  }

  // ------------------------------------------------------------ 界面与行为

  ThemeMode get themeMode {
    switch (_prefs.getInt(_kThemeMode) ?? ThemeMode.system.index) {
      case 0:
        return ThemeMode.system;
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  /// 在当前明暗之间切换（跟随系统时按当前实际亮度切）。
  Future<void> toggleBrightness(Brightness current) async {
    await setThemeMode(
      current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  int get autoSaveMillis {
    final value = _prefs.getInt(_kAutoSaveMillis) ?? defaultAutoSaveMillis;
    return autoSaveOptions.contains(value) ? value : defaultAutoSaveMillis;
  }

  Future<void> setAutoSaveMillis(int millis) async {
    await _prefs.setInt(_kAutoSaveMillis, millis);
    notifyListeners();
  }

  bool get restoreLastSession =>
      _prefs.getBool(_kRestoreLastSession) ?? true;

  Future<void> setRestoreLastSession(bool value) async {
    await _prefs.setBool(_kRestoreLastSession, value);
    notifyListeners();
  }

  /// 视频渲染兼容模式：默认**关闭**（即默认走硬件加速）。
  ///
  /// 只在极少数「有声音但画面全黑」的环境里需要打开（改用 CPU 软件渲染）。
  /// 注意：画面全黑最常见的原因不是这里，而是 media_kit_video 版本与 Flutter
  /// 版本不匹配（见 pubspec.yaml 里的说明）。
  bool get videoCompatibilityMode =>
      _prefs.getBool(_kVideoCompatibilityMode) ?? false;

  Future<void> setVideoCompatibilityMode(bool value) async {
    await _prefs.setBool(_kVideoCompatibilityMode, value);
    notifyListeners();
  }

  // ---------------------------------------------------------------- 会话

  String? get lastVideoPath => _nullIfBlank(_prefs.getString(_kLastVideoPath));
  String? get lastTextPath => _nullIfBlank(_prefs.getString(_kLastTextPath));
  int get lastVideoPositionMs => _prefs.getInt(_kLastVideoPosMs) ?? 0;
  double get lastRate => _prefs.getDouble(_kLastRate) ?? 1.0;
  int get lastSelectionBase => _prefs.getInt(_kLastSelBase) ?? 0;
  int get lastSelectionExtent => _prefs.getInt(_kLastSelExtent) ?? 0;

  /// 上次视频与 TXT 都还在磁盘上时，返回可恢复的数据。
  Future<ResumeData?> resumeData() async {
    final video = lastVideoPath;
    final text = lastTextPath;
    if (video == null || text == null) return null;
    if (!await File(video).exists()) return null;
    if (!await File(text).exists()) return null;
    return ResumeData(
      videoPath: video,
      textPath: text,
      videoPositionMs: lastVideoPositionMs,
      rate: lastRate,
      selectionBase: lastSelectionBase,
      selectionExtent: lastSelectionExtent,
    );
  }

  Future<void> saveSession({
    required String videoPath,
    required String textPath,
    required int videoPositionMs,
    required double rate,
    required int selectionBase,
    required int selectionExtent,
  }) async {
    await _prefs.setString(_kLastVideoPath, videoPath);
    await _prefs.setString(_kLastTextPath, textPath);
    await _prefs.setInt(_kLastVideoPosMs, videoPositionMs < 0 ? 0 : videoPositionMs);
    await _prefs.setDouble(_kLastRate, rate);
    await _prefs.setInt(_kLastSelBase, selectionBase < 0 ? 0 : selectionBase);
    await _prefs.setInt(_kLastSelExtent, selectionExtent < 0 ? 0 : selectionExtent);
  }

  Future<void> clearSession() async {
    await _prefs.remove(_kLastVideoPath);
    await _prefs.remove(_kLastTextPath);
    await _prefs.remove(_kLastVideoPosMs);
    await _prefs.remove(_kLastRate);
    await _prefs.remove(_kLastSelBase);
    await _prefs.remove(_kLastSelExtent);
    notifyListeners();
  }

  // ---------------------------------------------------------------- 工具

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _writeString(String key, String? value) async {
    final normalized = _nullIfBlank(value);
    if (normalized == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, normalized);
    }
  }
}
