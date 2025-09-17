import 'dart:io';

import 'package:yaml/yaml.dart';

class Config {
  static const String name = '.auto_reflect.yaml';

  late String apiKey;
  late String baseUrl;
  late String model;
  late String codeDirectory;
  late String outputDirectory;

  Config({
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o',
    this.codeDirectory = '',
    this.outputDirectory = '',
  });

  String? getConfigPath() {
    var homeDirectory = Platform.environment['HOME'];
    var profileDirectory = Platform.environment['USERPROFILE'];
    var directory = homeDirectory ?? profileDirectory;
    if (directory == null) return null;
    return '$directory/$name';
  }

  Future<void> save() async {
    var currentDirectory = Directory.current;
    var homeDirectory = Platform.environment['HOME'];
    var profileDirectory = Platform.environment['USERPROFILE'];
    var directory = homeDirectory ?? profileDirectory;
    var configPath = directory ?? currentDirectory.path;
    var file = File('$configPath/$name');
    var parts = [
      '# Journal CLI Configuration',
      'api_key: $apiKey',
      'base_url: $baseUrl',
      'model: $model',
      'code_dir: $codeDirectory',
      'output_dir: $outputDirectory',
    ];
    await file.writeAsString(parts.join('\n'));
  }

  static String getDefaultCodeDir() {
    var homeDirectory = Platform.environment['HOME'];
    var profileDirectory = Platform.environment['USERPROFILE'];
    var directory = homeDirectory ?? profileDirectory;
    return directory != null ? '$directory/Code' : 'Code';
  }

  static String getDefaultOutputDir() {
    var homeDirectory = Platform.environment['HOME'];
    var profileDirectory = Platform.environment['USERPROFILE'];
    var directory = homeDirectory ?? profileDirectory;
    return directory != null ? '$directory/Reflect' : 'Reflect';
  }

  static Future<Config> load() async {
    var file = await _findConfigFile();
    if (file == null) return _createDefaultConfig();
    var content = await file.readAsString();
    var yaml = loadYaml(content);
    return Config(
      apiKey: yaml['api_key']?.toString() ?? '',
      baseUrl: yaml['base_url']?.toString() ?? 'https://api.openai.com/v1',
      model: yaml['model']?.toString() ?? 'gpt-4o',
      codeDirectory: yaml['code_dir']?.toString() ?? getDefaultCodeDir(),
      outputDirectory: yaml['output_dir']?.toString() ?? getDefaultOutputDir(),
    );
  }

  static Config _createDefaultConfig() {
    return Config(
      apiKey: '',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o',
      codeDirectory: getDefaultCodeDir(),
      outputDirectory: getDefaultOutputDir(),
    );
  }

  static Future<File?> _findConfigFile() async {
    var currentDirectory = Directory.current;
    var homeDirectory = Platform.environment['HOME'];
    var profileDirectory = Platform.environment['USERPROFILE'];
    var file = File('$currentDirectory/$name');
    if (await file.exists()) return file;
    var globalDirectory = homeDirectory ?? profileDirectory;
    if (globalDirectory == null) return null;
    file = File('$globalDirectory/$name');
    if (await file.exists()) return file;
    return null;
  }
}
