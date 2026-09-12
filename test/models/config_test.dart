import 'dart:io';

import 'package:auto_reflect/models/config.dart';
import 'package:test/test.dart';

void main() {
  group('Config.load', () {
    late Directory originalWorkingDirectory;
    late Directory tempDirectory;

    setUp(() async {
      originalWorkingDirectory = Directory.current;
      tempDirectory =
          await Directory.systemTemp.createTemp('auto_reflect_config_test_');
      Directory.current = tempDirectory;
    });

    tearDown(() async {
      Directory.current = originalWorkingDirectory;
      await tempDirectory.delete(recursive: true);
    });

    Future<void> writeConfigFile(String content) {
      return File('${tempDirectory.path}/${Config.name}')
          .writeAsString(content);
    }

    test('读取完整的配置字段', () async {
      await writeConfigFile('''
# Journal CLI Configuration
api_key: test-key
base_url: https://example.com/v1
model: test-model
code_dir: /tmp/code
output_dir: /tmp/out
daily_post_dir: /tmp/daily
ignore:
  - 'temp'
  - ' node_modules '
language: zh-CN
authors: alice, bob
''');

      final config = await Config.load();

      expect(config.apiKey, 'test-key');
      expect(config.baseUrl, 'https://example.com/v1');
      expect(config.model, 'test-model');
      expect(config.codeDirectory, '/tmp/code');
      expect(config.outputDirectory, '/tmp/out');
      expect(config.dailyPostDirectory, '/tmp/daily');
      expect(config.ignore, ['temp', 'node_modules']);
      expect(config.language, 'zh-CN');
      expect(config.authors, 'alice, bob');
    });

    test('缺失字段回退到默认值', () async {
      await writeConfigFile('api_key: only-key\n');

      final config = await Config.load();

      expect(config.apiKey, 'only-key');
      expect(config.baseUrl, 'https://api.openai.com/v1');
      expect(config.model, 'gpt-4o');
      expect(config.language, 'en-US');
      expect(config.authors, '');
      expect(config.ignore, isEmpty);
      expect(config.codeDirectory, Config.getDefaultCodeDir());
    });

    test('ignore 为空列表时解析为空', () async {
      await writeConfigFile('ignore: []\n');

      final config = await Config.load();

      expect(config.ignore, isEmpty);
    });

    test('ignore 不是列表时抛出 FormatException', () async {
      await writeConfigFile('ignore: temp,node_modules\n');

      await expectLater(Config.load(), throwsFormatException);
    });

    test('ignore 含非字符串项时抛出 FormatException', () async {
      await writeConfigFile('ignore:\n  - 42\n');

      await expectLater(Config.load(), throwsFormatException);
    });
  });

  test('copyWith 复制 ignore 列表时使用独立副本', () {
    final config = Config(ignore: ['a']);
    final copied = config.copyWith(apiKey: 'new-key');

    expect(copied.apiKey, 'new-key');
    expect(copied.ignore, ['a']);

    copied.ignore.add('b');
    expect(config.ignore, ['a']);
  });
}
