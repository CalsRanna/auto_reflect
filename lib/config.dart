import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class AutoReflectConfig {
  final String baseUrl;
  final String model;
  final String apiKey;

  AutoReflectConfig({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'model': model,
      'apiKey': apiKey,
    };
  }

  factory AutoReflectConfig.fromJson(Map<String, dynamic> json) {
    return AutoReflectConfig(
      baseUrl: json['baseUrl'] ?? '',
      model: json['model'] ?? '',
      apiKey: json['apiKey'] ?? '',
    );
  }

  bool isValid() {
    return baseUrl.isNotEmpty && model.isNotEmpty && apiKey.isNotEmpty;
  }
}

class ConfigManager {
  static const String _configFileName = '.auto_reflect';

  static String get _configPath {
    final homeDir = Platform.environment['HOME']!;
    return path.join(homeDir, _configFileName);
  }

  static Future<AutoReflectConfig?> loadConfig() async {
    try {
      final configFile = File(_configPath);
      if (!await configFile.exists()) {
        return null;
      }

      final content = await configFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return AutoReflectConfig.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveConfig(AutoReflectConfig config) async {
    try {
      final configFile = File(_configPath);
      final json = jsonEncode(config.toJson());
      await configFile.writeAsString(json);

      // 设置文件权限为仅用户可读写 (在某些平台上可能不支持)
      // configFile.setMode(0o600);
    } catch (e) {
      throw Exception('保存配置文件失败: $e');
    }
  }

  static Future<void> deleteConfig() async {
    try {
      final configFile = File(_configPath);
      if (await configFile.exists()) {
        await configFile.delete();
      }
    } catch (e) {
      throw Exception('删除配置文件失败: $e');
    }
  }

  static String? getConfigPath() {
    return _configPath;
  }
}