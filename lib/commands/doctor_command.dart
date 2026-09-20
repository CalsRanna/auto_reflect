import 'package:args/command_runner.dart';
import 'package:auto_reflect/utils/string_buffer_extensions.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:openai_dart/openai_dart.dart';

import '../models/config.dart';

class DoctorCommand extends Command {
  DoctorCommand() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed diagnostic information',
      negatable: false,
    );
  }

  @override
  String get description => 'Check configuration and connection status';

  @override
  String get name => 'doctor';

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final verbose = argResults!['verbose'] as bool;

    await _runNormalDoctor(verbose);
  }

  Future<void> _runNormalDoctor(bool verbose) async {
    print('Doctor summary (to see all details, run journal doctor -v):');

    final issuesCount = <String, int>{};
    final config = await Config.load();

    await _checkAndDisplay('api_key', verbose, issuesCount, config);
    await _checkAndDisplay('base_url', verbose, issuesCount, config);
    await _checkAndDisplay('model', verbose, issuesCount, config);
    await _checkAndDisplay('ignore', verbose, issuesCount, config);
    await _checkAndDisplay('network', verbose, issuesCount, config);

    final totalIssues = issuesCount.values.fold(0, (sum, count) => sum + count);
    if (totalIssues == 0) {
      final buffer = StringBuffer()..writeBullet('No issues found!');
      print('\n$buffer');
    } else {
      final message = '$totalIssues issue${totalIssues > 1 ? 's' : ''} found!';
      final buffer = StringBuffer()..writeWarning(message);
      print('\n$buffer');
    }
  }

  Future<void> _checkAndDisplay(
    String component,
    bool verbose,
    Map<String, int> issuesCount,
    Config config,
  ) async {
    final spinner = CliSpin()..start();

    Map<String, dynamic> result;

    try {
      result = await _checkDoctorComponent(component, config);
    } catch (error) {
      result = <String, dynamic>{
        'valid': false,
        'issues': ['Failed to check $component: $error'],
      };
    } finally {
      spinner.stop();
    }

    final issueCount = (result['issues'] as List).length;
    issuesCount[component] = issueCount;

    _displayComponentResult(component, result, verbose);
  }

  Future<Map<String, dynamic>> _checkDoctorComponent(
    String component,
    Config config,
  ) async {
    switch (component) {
      case 'api_key':
        return _checkAPIKey(config);
      case 'base_url':
        return _checkBaseUrl(config);
      case 'model':
        return _checkModel(config);
      case 'ignore':
        return _checkIgnore(config);
      case 'network':
        return await _checkNetwork(config);
      default:
        return <String, dynamic>{
          'valid': false,
          'issues': ['Unknown component: $component'],
        };
    }
  }

  Map<String, dynamic> _checkAPIKey(Config config) {
    final apiKey = _maskSecret(config.apiKey);
    if (config.apiKey.isEmpty) {
      return <String, dynamic>{
        'valid': false,
        'issues': ['API key not set'],
      };
    }
    return <String, dynamic>{
      'valid': true,
      'issues': <String>[],
      'value': apiKey,
    };
  }

  Map<String, dynamic> _checkBaseUrl(Config config) {
    if (config.baseUrl.isEmpty) {
      return <String, dynamic>{
        'valid': false,
        'issues': ['Base URL not set'],
      };
    }
    return <String, dynamic>{
      'valid': true,
      'issues': <String>[],
      'value': config.baseUrl,
    };
  }

  Map<String, dynamic> _checkModel(Config config) {
    if (config.model.isEmpty) {
      return <String, dynamic>{
        'valid': false,
        'issues': ['Model not set'],
      };
    }
    return <String, dynamic>{
      'valid': true,
      'issues': <String>[],
      'value': config.model,
    };
  }

  Map<String, dynamic> _checkIgnore(Config config) {
    return <String, dynamic>{
      'valid': true,
      'issues': <String>[],
      'items': List<String>.from(config.ignore),
    };
  }

  Future<Map<String, dynamic>> _checkNetwork(Config config) async {
    try {
      await _connect(config);
      return <String, dynamic>{
        'valid': true,
        'issues': <String>[],
      };
    } catch (error) {
      return <String, dynamic>{
        'valid': false,
        'issues': [error.toString()],
      };
    }
  }

  void _displayComponentResult(
    String component,
    Map<String, dynamic> result,
    bool verbose,
  ) {
    switch (component) {
      case 'api_key':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          final buffer = StringBuffer()
            ..writeSuccess('API key (${result['value']})');
          print(buffer.toString());
          if (verbose) {
            final buffer2 = StringBuffer()
              ..writeBullet('    API key: ${result['value']}');
            print(buffer2.toString());
          }
        } else {
          final buffer = StringBuffer()..writeWarning('API key');
          print(buffer.toString());
          if (verbose) {
            for (final issue in result['issues']) {
              print('    $issue');
            }
            print('    Fix: journal config --set-api-key "<your-api-key>"');
          }
        }
        break;

      case 'base_url':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          final buffer = StringBuffer()
            ..writeSuccess('Base URL (${result['value']})');
          print(buffer.toString());
          if (verbose) {
            final buffer2 = StringBuffer()
              ..writeBullet('    Base URL: ${result['value']}');
            print(buffer2.toString());
          }
        } else {
          final buffer = StringBuffer()..writeWarning('Base URL');
          print(buffer.toString());
          if (verbose) {
            for (final issue in result['issues']) {
              print('    $issue');
            }
            print(
              '    Fix: journal config --set-base-url "https://api.openai.com/v1"',
            );
          }
        }
        break;

      case 'model':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          final buffer = StringBuffer()
            ..writeSuccess('Model (${result['value']})');
          print(buffer.toString());
          if (verbose) {
            final buffer2 = StringBuffer()
              ..writeBullet('    Model: ${result['value']}');
            print(buffer2.toString());
          }
        } else {
          final buffer = StringBuffer()..writeWarning('Model');
          print(buffer.toString());
          if (verbose) {
            for (final issue in result['issues']) {
              print('    $issue');
            }
            print('    Fix: journal config --set-model "gpt-4o"');
          }
        }
        break;

      case 'ignore':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          final items = result['items'] as List<String>;
          final summary = 'Ignore folders (${items.length} Folders)';
          final buffer = StringBuffer()..writeSuccess(summary);
          print(buffer.toString());
          if (verbose) {
            if (items.isEmpty) {
              print('    - (none)');
            } else {
              for (final item in items) {
                print('    - $item');
              }
            }
          }
        } else {
          final buffer = StringBuffer()..writeWarning('Ignore folders');
          print(buffer.toString());
          if (verbose) {
            for (final issue in result['issues']) {
              print('    $issue');
            }
          }
        }
        break;

      case 'network':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          final buffer = StringBuffer()..writeSuccess('Network connectivity');
          print(buffer.toString());
          if (verbose) {
            final buffer2 = StringBuffer()
              ..writeBullet('    OpenAI-compatible endpoint: accessible');
            print(buffer2.toString());
          }
        } else {
          final buffer = StringBuffer()..writeWarning('Network connectivity');
          print(buffer.toString());
          if (verbose) {
            for (final issue in result['issues']) {
              print('    $issue');
            }
            print(
              '    Fix: verify your API key, base URL, model, and network access',
            );
          }
        }
        break;
    }
  }

  String _maskSecret(String secret) {
    var value = secret;
    if (value.isEmpty) return value;
    final length = value.length;
    if (length > 13) {
      final prefix = value.substring(0, 7);
      final suffix = value.substring(length - 6, length);
      final encrypted = List.generate(length - 13, (index) => '*');
      value = prefix + encrypted.join() + suffix;
    }
    return value;
  }

  Future<ChatCompletion> _connect(Config config) async {
    final client = OpenAIClient(
      config: OpenAIConfig(
        authProvider: ApiKeyProvider(config.apiKey),
        baseUrl: config.baseUrl,
        defaultHeaders: const {
          'HTTP-Referer': 'https://github.com/CalsRanna/auto_reflect',
          'X-Title': 'Auto Reflect',
        },
      ),
    );
    final request = ChatCompletionCreateRequest(
      model: config.model,
      messages: [ChatMessage.user('hi')],
    );
    try {
      return await client.chat.completions.create(request);
    } finally {
      client.close();
    }
  }
}
