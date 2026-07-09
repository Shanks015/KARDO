import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigState {
  final String serverHost;
  final int serverPort;
  final String selectedModel;
  final bool isDark;

  const ConfigState({
    required this.serverHost,
    required this.serverPort,
    required this.selectedModel,
    this.isDark = true,
  });

  ConfigState copyWith({String? serverHost, int? serverPort, String? selectedModel, bool? isDark}) {
    return ConfigState(
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      selectedModel: selectedModel ?? this.selectedModel,
      isDark: isDark ?? this.isDark,
    );
  }
}

class ConfigNotifier extends StateNotifier<ConfigState> {
  static String get _defaultHost {
    if (kIsWeb) {
      return "localhost";
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "10.0.2.2";
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return "localhost";
      case TargetPlatform.fuchsia:
        return "localhost";
    }
  }

  static int get _defaultPort => 8001;

  ConfigNotifier() : super(ConfigState(serverHost: _defaultHost, serverPort: _defaultPort, selectedModel: "gemma4:31b-cloud")) {
    _loadSync();
  }

  Future<void> _loadSync() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString('serverHost') ?? prefs.getString('serverIp');
    final savedPort = prefs.getInt('serverPort') ?? 8000;
    final normalizedHost = (savedHost == null || savedHost.trim().isEmpty)
        ? _defaultHost
        : savedHost;
    final normalizedPort = savedPort > 0 ? savedPort : _defaultPort;
    final migratedPort = normalizedPort == 8000 ? _defaultPort : normalizedPort;

    state = ConfigState(
      serverHost: normalizedHost == "10.0.2.2" && defaultTargetPlatform != TargetPlatform.android
          ? _defaultHost
          : normalizedHost,
      serverPort: migratedPort,
      selectedModel: prefs.getString('selectedModel') ?? "gemma4:31b-cloud",
      isDark: prefs.getBool('isDark') ?? true,
    );

    if (state.serverHost != normalizedHost) {
      await prefs.setString('serverHost', state.serverHost);
    }
    await prefs.setInt('serverPort', state.serverPort);
    await prefs.setString('serverIp', state.serverHost);
  }

  void setHost(String host) {
    state = state.copyWith(serverHost: host);
    _save();
  }

  void setPort(String portValue) {
    final parsedPort = int.tryParse(portValue.trim());
    if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
      return;
    }

    state = state.copyWith(serverPort: parsedPort);
    _save();
  }

  void toggleTheme() {
    state = state.copyWith(isDark: !state.isDark);
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverHost', state.serverHost);
    await prefs.setString('serverIp', state.serverHost);
    await prefs.setInt('serverPort', state.serverPort);
    await prefs.setBool('isDark', state.isDark);
  }
}

final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  return ConfigNotifier();
});