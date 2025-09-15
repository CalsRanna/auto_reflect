import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../lib/config.dart';
import '../lib/ai_service.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: '显示帮助信息')
    ..addFlag('verbose', abbr: 'v', help: '详细输出')
    ..addFlag('no-ai', help: '不使用AI分析')
    ..addOption('date', help: '指定日期 (格式: YYYY-MM-DD)')
    ..addOption('code-dir', help: 'Code文件夹路径')
    ..addOption('output-dir', help: 'Reflect输出文件夹路径')
    ..addCommand('config')
    ..addCommand('show-config');

  try {
    final results = parser.parse(arguments);

    if (results['help']) {
      print(_buildUsage(parser));
      exit(0);
    }

    // 处理config命令
    if (results.command?.name == 'config') {
      await _handleConfigCommand(parser, results);
      return;
    }

    // 处理show-config命令
    if (results.command?.name == 'show-config') {
      await _handleShowConfigCommand();
      return;
    }

    final reflector = GitCommitReflector(
      verbose: results['verbose'],
      date: results['date'],
      codeDir: results['code-dir'],
      outputDir: results['output-dir'],
      useAI: !results['no-ai'],
    );

    await reflector.generateDailyLog();
  } catch (e) {
    print('错误: $e');
    print(_buildUsage(parser));
    exit(1);
  }
}

String _buildUsage(ArgParser parser) {
  return '''
Auto Reflect - 自动Git工作日志生成器

使用方法:
  ${parser.usage}

命令:
  config        配置AI设置
  show-config   显示当前配置

示例:
  # 基本使用
  dart run bin/auto_reflect.dart

  # 使用AI分析
  dart run bin/auto_reflect.dart --verbose

  # 不使用AI分析
  dart run bin/auto_reflect.dart --no-ai

  # 配置AI
  dart run bin/auto_reflect.dart config

  # 显示当前配置
  dart run bin/auto_reflect.dart show-config
''';
}

Future<void> _handleConfigCommand(ArgParser parser, ArgResults results) async {
  print('AI配置设置');
  print('=' * 40);

  stdout.write('请输入Base URL (例如: https://api.openai.com/v1): ');
  final baseUrl = stdin.readLineSync()?.trim() ?? '';

  stdout.write('请输入Model (例如: gpt-3.5-turbo 或 gpt-4): ');
  final model = stdin.readLineSync()?.trim() ?? '';

  stdout.write('请输入API Key: ');
  final apiKey = stdin.readLineSync()?.trim() ?? '';

  if (baseUrl.isEmpty || model.isEmpty || apiKey.isEmpty) {
    print('错误: 所有字段都不能为空');
    exit(1);
  }

  try {
    final config = AutoReflectConfig(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
    );

    await ConfigManager.saveConfig(config);
    print('✅ 配置已保存到: ${ConfigManager.getConfigPath()}');
    print('文件权限已设置为仅用户可读写');
  } catch (e) {
    print('❌ 保存配置失败: $e');
    exit(1);
  }
}

Future<void> _handleShowConfigCommand() async {
  final config = await ConfigManager.loadConfig();

  if (config == null) {
    print('⚠️  未找到配置文件，请先运行: dart run bin/auto_reflect.dart config');
    exit(1);
  }

  print('当前AI配置:');
  print('=' * 40);
  print('Base URL: ${config.baseUrl}');
  print('Model: ${config.model}');
  print('API Key: ${config.apiKey.substring(0, 8)}...');
  print('配置文件: ${ConfigManager.getConfigPath()}');

  if (!config.isValid()) {
    print('❌ 配置不完整，请重新配置');
    exit(1);
  }

  print('✅ 配置有效');
}

class GitCommitReflector {
  final bool verbose;
  final String? date;
  final String? codeDir;
  final String? outputDir;
  final bool useAI;
  String? _currentUserName;
  String? _currentUserEmail;

  GitCommitReflector({
    this.verbose = false,
    this.date,
    this.codeDir,
    this.outputDir,
    this.useAI = true,
  });

  Future<void> generateDailyLog() async {
    try {
      await _getCurrentGitUserInfo();

      if (verbose) {
        print('当前Git用户: $_currentUserName ($_currentUserEmail)');
      }

      final homeDir = Platform.environment['HOME']!;
      final codeFolderPath = this.codeDir ?? path.join(homeDir, 'Code');
      final reflectFolderPath = this.outputDir ?? path.join(homeDir, 'Reflect');

      if (verbose) {
        print('Code文件夹: $codeFolderPath');
        print('Reflect文件夹: $reflectFolderPath');
      }

      final today = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (verbose) {
        print('分析日期: $today');
      }

      final codeDir = Directory(codeFolderPath);
      if (!await codeDir.exists()) {
        print('错误: Code文件夹不存在: $codeFolderPath');
        return;
      }

      final reflectDir = Directory(reflectFolderPath);
      if (!await reflectDir.exists()) {
        await reflectDir.create(recursive: true);
        if (verbose) {
          print('创建Reflect文件夹: $reflectFolderPath');
        }
      }

      final projectCommits = await _scanGitProjects(codeDir, today);

      if (projectCommits.isEmpty) {
        print('今天没有找到任何Git提交记录');
        return;
      }

      AIAnalysisResult? aiAnalysis;
      if (useAI) {
        final config = await ConfigManager.loadConfig();
        if (config == null || !config.isValid()) {
          print('⚠️  AI配置无效或不存在，将跳过AI分析');
          print('请运行: dart run bin/auto_reflect.dart config');
        } else {
          try {
            if (verbose) {
              print('正在进行AI分析...');
            }
            final aiService = AIService(config: config);
            aiAnalysis = await aiService.analyzeCommits(projectCommits);
            if (verbose) {
              print('AI分析完成');
            }
          } catch (e) {
            print('❌ AI分析失败: $e');
          }
        }
      }

      final report = await _generateReport(
          projectCommits,
          today,
          aiAnalysis ??
              AIAnalysisResult(
                errorsAndIssues: [],
                nextImportantTasks: [],
                beneficialWork: [],
                highlights: [],
                learnings: [],
                rawResponse: '',
              ));
      await _saveReport(reflectDir, today, report);

      print('工作日志已生成: ${path.join(reflectFolderPath, '$today.md')}');
    } catch (e) {
      print('生成日志时出错: $e');
    }
  }

  Future<Map<String, List<GitCommit>>> _scanGitProjects(
      Directory codeDir, String date) async {
    final commits = <String, List<GitCommit>>{};

    await for (var entity
        in codeDir.list(recursive: false, followLinks: false)) {
      if (entity is Directory) {
        final gitDir = Directory(path.join(entity.path, '.git'));
        if (await gitDir.exists()) {
          if (verbose) {
            print('扫描Git项目: ${entity.path}');
          }

          final projectCommits = await _getCommitsForDate(entity.path, date);
          if (projectCommits.isNotEmpty) {
            commits[path.basename(entity.path)] = projectCommits;
          }
        }
      }
    }

    return commits;
  }

  Future<void> _getCurrentGitUserInfo() async {
    try {
      final userResult = await Process.run('git', ['config', 'user.name']);
      if (userResult.exitCode == 0) {
        _currentUserName = userResult.stdout.toString().trim();
      }

      final emailResult = await Process.run('git', ['config', 'user.email']);
      if (emailResult.exitCode == 0) {
        _currentUserEmail = emailResult.stdout.toString().trim();
      }

      if (_currentUserName == null && _currentUserEmail == null) {
        print('警告: 无法获取Git用户配置，将获取所有用户的提交记录');
      }
    } catch (e) {
      if (verbose) {
        print('获取Git用户配置时出错: $e');
      }
    }
  }

  Future<List<GitCommit>> _getCommitsForDate(
      String projectPath, String date) async {
    try {
      var gitCommand = [
        'log',
        '--since=$date 00:00:00',
        '--until=$date 23:59:59',
        '--pretty=format:%H|%an|%ae|%s|%ci',
        '--no-merges'
      ];

      if (_currentUserName != null) {
        gitCommand.insert(1, '--author=$_currentUserName');
      }

      final result = await Process.run(
        'git',
        gitCommand,
        workingDirectory: projectPath,
      );

      if (result.exitCode != 0) {
        if (verbose) {
          print('获取Git日志失败 (${path.basename(projectPath)}): ${result.stderr}');
        }
        return [];
      }

      final commits = <GitCommit>[];
      final lines = result.stdout.toString().split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split('|');
        if (parts.length >= 5) {
          commits.add(GitCommit(
            hash: parts[0],
            author: parts[1],
            email: parts[2],
            message: parts[3],
            date: parts[4],
            projectPath: projectPath,
          ));
        }
      }

      return commits;
    } catch (e) {
      if (verbose) {
        print('获取提交记录时出错 (${path.basename(projectPath)}): $e');
      }
      return [];
    }
  }

  Future<String> _generateReport(Map<String, List<GitCommit>> projectCommits,
      String date, AIAnalysisResult? aiAnalysis) async {
    final buffer = StringBuffer();
    final dateTime = DateFormat('yyyy-MM-dd').parse(date);
    final formattedDate = DateFormat('yyyy/MM/dd').format(dateTime);

    buffer.writeln('# Reflect Today - $formattedDate');
    buffer.writeln('');

    buffer.writeln('## 工作总结');
    buffer.writeln('');

    // 添加commit记录
    if (projectCommits.isNotEmpty) {
      final sortedProjects = projectCommits.keys.toList()..sort();

      for (final projectName in sortedProjects) {
        final commits = projectCommits[projectName]!;
        buffer.writeln('### $projectName');
        buffer.writeln('');

        for (final commit in commits) {
          buffer.writeln('- ${commit.message}');
        }
        buffer.writeln('');
      }
    }

    // 添加AI分析结果
    if (aiAnalysis != null && !aiAnalysis.isEmpty()) {
      if (aiAnalysis.learnings.isNotEmpty) {
        buffer
            .writeln('## 为了未来的成功，我学到了什么，使用了哪些新工具、方法或人工智能工具，取得了什么成功或进行了哪些新尝试？');
        buffer.writeln('');
        for (final learning in aiAnalysis.learnings) {
          buffer.writeln('- $learning');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.highlights.isNotEmpty) {
        buffer.writeln(
            '## 工作中或行业内出现的奇怪、不明确、荒谬、最令人困扰或自上个月以来发生奇怪变化的事情？或者我今天无法解决的问题？');
        buffer.writeln('');
        for (final highlight in aiAnalysis.highlights) {
          buffer.writeln('- $highlight');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.errorsAndIssues.isNotEmpty) {
        buffer.writeln('## 我今天或过去几天犯的小错误');
        buffer.writeln('');
        for (final issue in aiAnalysis.errorsAndIssues) {
          buffer.writeln('- $issue');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.nextImportantTasks.isNotEmpty) {
        buffer.writeln('## 下一个工作日最重要或最困难的任务');
        buffer.writeln('');
        for (final task in aiAnalysis.nextImportantTasks) {
          buffer.writeln('- $task');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.beneficialWork.isNotEmpty) {
        buffer.writeln('## 今天我做了哪些对客户或行业有益的事情？');
        buffer.writeln('');
        for (final beneficial in aiAnalysis.beneficialWork) {
          buffer.writeln('- $beneficial');
        }
        buffer.writeln('');
      }
    }

    return buffer.toString();
  }

  Future<void> _saveReport(
      Directory reflectDir, String date, String content) async {
    final fileName = '$date.md';
    final filePath = path.join(reflectDir.path, fileName);

    final file = File(filePath);
    await file.writeAsString(content);
  }
}
