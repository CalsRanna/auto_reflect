import 'dart:io';

import 'package:yaml/yaml.dart';

class Config {
  static const String name = '.auto_reflect.yaml';

  late String apiKey;
  late String baseUrl;
  late String model;
  late String codeDirectory;
  late String outputDirectory;
  late String ignore;
  late String language;
  late String authors;

  Config({
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o',
    this.codeDirectory = '',
    this.outputDirectory = '',
    this.ignore = '',
    this.language = 'en-US',
    this.authors = '',
  });

  Config copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? codeDirectory,
    String? outputDirectory,
    String? ignore,
    String? language,
    String? authors,
  }) {
    return Config(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      codeDirectory: codeDirectory ?? this.codeDirectory,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      ignore: ignore ?? this.ignore,
      language: language ?? this.language,
      authors: authors ?? this.authors,
    );
  }

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
      'ignore: $ignore',
      'language: $language',
      'authors: $authors',
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
      ignore: yaml['ignore']?.toString() ?? '',
      language: yaml['language']?.toString() ?? 'en-US',
      authors: yaml['authors']?.toString() ?? '',
    );
  }

  static Config _createDefaultConfig() {
    return Config(
      apiKey: '',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o',
      codeDirectory: getDefaultCodeDir(),
      outputDirectory: getDefaultOutputDir(),
      ignore: '',
      language: 'en-US',
      authors: '',
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
