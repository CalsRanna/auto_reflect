import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:openai_dart/openai_dart.dart';
import '../models/config.dart';

class DoctorCommand extends Command {
  final List<String> _errors = [];
  final _spinner = CliSpin(spinner: CliSpinners.dots5);

  @override
  String get description => 'Check configuration and connection status';

  @override
  String get name => 'doctor';

  @override
  Future<void> run() async {
    _spinner.start();
    var config = await Config.load();
    _checkAPIKey(config);
    _checkBaseUrl(config);
    _checkModel(config);
    await _checkNetwork(config);
    _spinner.stop();
    if (_errors.isNotEmpty) {
      for (var error in _errors) {
        stdout.writeln('\n\x1B[31m• $error\x1B[0m');
      }
      return;
    }
    stdout.writeln('\n✨ No issues found');
  }

  void _checkAPIKey(Config config) {
    var apiKey = config.apiKey;
    if (apiKey.isEmpty) return _fail('API key not set');
    var length = apiKey.length;
    if (length > 13) {
      var prefix = apiKey.substring(0, 7);
      var suffix = apiKey.substring(length - 6, length);
      var encrypted = List.generate(length - 13, (index) => '*');
      apiKey = prefix + encrypted.join() + suffix;
    }
    _spinner.success('API key: $apiKey');
    _spinner.start();
  }

  void _checkBaseUrl(Config config) {
    if (config.baseUrl.isEmpty) return _fail('Base URL not set');
    _spinner.success('Base URL: ${config.baseUrl}');
    _spinner.start();
  }

  void _checkModel(Config config) {
    if (config.model.isEmpty) return _fail('Model not set');
    _spinner.success('Model: ${config.model}');
    _spinner.start();
  }

  Future<void> _checkNetwork(Config config) async {
    _spinner.text = '';
    try {
      await _connect(config);
      _spinner.success('Network connectivity');
    } catch (error) {
      _fail('Network connectivity failed', error: error.toString());
    }
  }

  Future<CreateChatCompletionResponse> _connect(Config config) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/auto_reflect',
      'X-Title': 'Auto Reflect',
    };
    var client = OpenAIClient(
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      headers: headers,
    );
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('hi'),
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [userMessage],
    );
    try {
      return await client.createChatCompletion(request: request);
    } finally {
      client.endSession();
    }
  }

  void _fail(String message, {String? error}) {
    _spinner.fail(message);
    _errors.add(error ?? message);
  }
}
