import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:auto_reflect/models/config.dart';

void handleError(String message) {
  stderr.writeln('[ERROR] $message');
  exit(1);
}

void showSuccess(String message) {
  stdout.writeln('[OK] $message');
}

class ConfigCommand extends Command {
  ConfigCommand() {
    argParser
      ..addOption('set-api-key', help: 'Set API key')
      ..addOption('set-base-url', help: 'Set API base url')
      ..addOption('set-model', help: 'Set model')
      ..addOption('set-code-directory', help: 'Set code directory path')
      ..addOption('set-output-directory', help: 'Set output directory path')
      ..addOption(
        'set-daily-post-directory',
        help: 'Set DailyPost directory path',
      )
      ..addOption(
        'set-ignore',
        help: 'Set ignore folders (comma-separated, saved as YAML list)',
      )
      ..addOption(
        'set-language',
        help:
            'Set default language for reports (e.g., "zh-CN", "en-US", "ja-JP")',
      )
      ..addOption(
        'set-authors',
        help: 'Set default authors (comma-separated, e.g., "John,Jane")',
      )
      ..addFlag('show', help: 'Show current configuration', negatable: false);
  }

  @override
  String get description => 'Configure AI settings';

  @override
  String get name => 'config';

  @override
  Future<void> run() async {
    var config = await Config.load();
    if (argResults?['set-api-key'] != null) return _setAPIKey(config);
    if (argResults?['set-base-url'] != null) return _setBaseUrl(config);
    if (argResults?['set-model'] != null) return _setModel(config);
    if (argResults?['set-code-directory'] != null)
      return _setCodeDirectory(config);
    if (argResults?['set-output-directory'] != null)
      return _setOutputDirectory(config);
    if (argResults?['set-daily-post-directory'] != null)
      return _setDailyPostDirectory(config);
    if (argResults?['set-ignore'] != null) return _setIgnore(config);
    if (argResults?['set-language'] != null) return _setLanguage(config);
    if (argResults?['set-authors'] != null) return _setAuthors(config);
    if (argResults?['show'] == true) return _show(config);
    return _interactiveSetup();
  }

  Future<void> _interactiveSetup() async {
    stdout.writeln('AI Configuration Setup');
    stdout.writeln('=' * 40);

    stdout.write('Enter Base URL (e.g., https://api.openai.com/v1): ');
    final baseUrl = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Enter Model (e.g., gpt-3.5-turbo or gpt-4): ');
    final model = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Enter API Key: ');
    final apiKey = stdin.readLineSync()?.trim() ?? '';

    final defaultConfig = Config(
      codeDirectory: Config.getDefaultCodeDir(),
      outputDirectory: Config.getDefaultOutputDir(),
    );

    stdout.write(
        'Enter Code Directory (default: ${defaultConfig.codeDirectory}): ');
    var codeDirInput = stdin.readLineSync()?.trim() ?? '';
    if (codeDirInput.isEmpty) {
      codeDirInput = defaultConfig.codeDirectory;
    }

    stdout.write(
        'Enter Output Directory (default: ${defaultConfig.outputDirectory}): ');
    var outputDirInput = stdin.readLineSync()?.trim() ?? '';
    if (outputDirInput.isEmpty) {
      outputDirInput = defaultConfig.outputDirectory;
    }

    stdout.write(
        'Enter DailyPost Directory (default: ${defaultConfig.dailyPostDirectory}): ');
    var dailyPostDirInput = stdin.readLineSync()?.trim() ?? '';
    if (dailyPostDirInput.isEmpty) {
      dailyPostDirInput = defaultConfig.dailyPostDirectory;
    }

    stdout.write('Enter Ignore Folders (comma-separated, optional): ');
    var ignoreInput = stdin.readLineSync()?.trim() ?? '';

    stdout
        .write('Enter Language (e.g., zh-CN, en-US, ja-JP, default: en-US): ');
    var languageInput = stdin.readLineSync()?.trim() ?? '';
    if (languageInput.isEmpty) {
      languageInput = 'en-US';
    }

    stdout.write('Enter Default Authors (comma-separated, optional): ');
    var authorsInput = stdin.readLineSync()?.trim() ?? '';

    if (baseUrl.isEmpty || model.isEmpty || apiKey.isEmpty) {
      handleError('API Key, Base URL, and Model are required');
    }

    try {
      final config = Config(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        codeDirectory: codeDirInput,
        outputDirectory: outputDirInput,
        dailyPostDirectory: dailyPostDirInput,
        ignore: _parseCsvList(ignoreInput),
        language: languageInput,
        authors: authorsInput,
      );

      await config.save();
      showSuccess('Configuration saved to: ${config.getConfigPath()}');
    } catch (e) {
      handleError('Failed to save configuration: $e');
    }
  }

  Future<void> _setAPIKey(Config config) async {
    config.apiKey = argResults!['set-api-key'].toString();
    await config.save();
    stdout.writeln('\nAPI key set successfully');
    _show(config);
  }

  Future<void> _setBaseUrl(Config config) async {
    config.baseUrl = argResults!['set-base-url'].toString();
    await config.save();
    stdout.writeln('\nBase URL set successfully');
    _show(config);
  }

  Future<void> _setCodeDirectory(Config config) async {
    config.codeDirectory = argResults!['set-code-directory'].toString();
    await config.save();
    stdout.writeln('\nCode directory set successfully');
    _show(config);
  }

  Future<void> _setModel(Config config) async {
    config.model = argResults!['set-model'].toString();
    await config.save();
    stdout.writeln('\nModel set successfully');
    _show(config);
  }

  Future<void> _setOutputDirectory(Config config) async {
    config.outputDirectory = argResults!['set-output-directory'].toString();
    await config.save();
    stdout.writeln('\nOutput directory set successfully');
    _show(config);
  }

  Future<void> _setIgnore(Config config) async {
    config.ignore = _parseCsvList(argResults!['set-ignore'].toString());
    await config.save();
    stdout.writeln('\nIgnore folders set successfully');
    _show(config);
  }

  Future<void> _setLanguage(Config config) async {
    config.language = argResults!['set-language'].toString();
    await config.save();
    stdout.writeln('\nLanguage set successfully');
    _show(config);
  }

  Future<void> _setAuthors(Config config) async {
    config.authors = argResults!['set-authors'].toString();
    await config.save();
    stdout.writeln('\nDefault authors set successfully');
    _show(config);
  }

  Future<void> _setDailyPostDirectory(Config config) async {
    config.dailyPostDirectory =
        argResults!['set-daily-post-directory'].toString();
    await config.save();
    stdout.writeln('\nDailyPost directory set successfully');
    _show(config);
  }

  void _show(Config config) {
    stdout.writeln('Journal CLI Configuration\n');
    var apiKey = config.apiKey;
    var length = apiKey.length;
    if (length > 13) {
      var prefix = apiKey.substring(0, 7);
      var suffix = apiKey.substring(length - 6, length);
      var encrypted = List.generate(length - 13, (index) => '*');
      apiKey = prefix + encrypted.join() + suffix;
    }
    stdout.writeln('API Key: $apiKey');
    stdout.writeln('Base URL: ${config.baseUrl}');
    stdout.writeln('Model: ${config.model}');
    stdout.writeln('Code Directory: ${config.codeDirectory}');
    stdout.writeln('Output Directory: ${config.outputDirectory}');
    stdout.writeln('DailyPost Directory: ${config.dailyPostDirectory}');
    if (config.ignore.isEmpty) {
      stdout.writeln('Ignore Folders: (none)');
    } else {
      stdout.writeln('Ignore Folders:');
      for (final item in config.ignore) {
        stdout.writeln('  - $item');
      }
    }
    stdout.writeln('Language: ${config.language}');
    stdout.writeln(
        'Default Authors: ${config.authors.isEmpty ? '(none)' : config.authors}\n');
  }

  List<String> _parseCsvList(String input) {
    return input
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
