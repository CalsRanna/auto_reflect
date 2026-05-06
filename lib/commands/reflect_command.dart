import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:intl/intl.dart';
import 'package:cli_spin/cli_spin.dart';
import '../models/config.dart';
import '../models/ai_analysis.dart';
import '../models/git_commit.dart';
import '../services/git_service.dart';
import '../services/generator.dart';
import '../services/news_service.dart';
import '../services/report_service.dart';
import '../utils/logger.dart';
import '../utils/file_utils.dart';

void showSuccess(String message) {
  stdout.writeln('[OK] $message');
}

void handleError(String message) {
  stderr.writeln('[ERROR] $message');
  exit(1);
}

// 参考auto_commit的格式显示项目统计信息
Future<String> _getProjectStats(Map<String, List<GitCommit>> projectCommits,
    Map<String, List<GitCommit>> ignoredProjectsWithCommits) async {
  var buffer = StringBuffer();
  buffer.write('\n');

  // 计算最长的项目路径长度，用于对齐
  int maxPathLength = 0;

  // 检查有commit的项目路径
  for (var entry in projectCommits.entries) {
    final commits = entry.value;
    final projectPath = commits.isNotEmpty ? commits.first.projectPath : '';
    if (projectPath.length > maxPathLength) {
      maxPathLength = projectPath.length;
    }
  }

  // 检查被忽略的项目路径
  for (var entry in ignoredProjectsWithCommits.entries) {
    final commits = entry.value;
    final projectPath = commits.isNotEmpty ? commits.first.projectPath : '';
    if (projectPath.length > maxPathLength) {
      maxPathLength = projectPath.length;
    }
  }

  // 创建一个统一的列表，包含所有项目（有commit的和被忽略的）
  final allItems = <Map<String, dynamic>>[];

  // 添加有commit的项目
  for (var entry in projectCommits.entries) {
    final project = entry.key;
    final commits = entry.value;
    final projectPath = commits.isNotEmpty ? commits.first.projectPath : '';

    allItems.add({
      'path': projectPath,
      'name': project,
      'type': 'commit',
      'commits': commits.length,
    });
  }

  // 添加被忽略的项目
  for (var entry in ignoredProjectsWithCommits.entries) {
    final project = entry.key;
    final commits = entry.value;
    final projectPath = commits.isNotEmpty ? commits.first.projectPath : '';

    allItems.add({
      'path': projectPath,
      'name': project,
      'type': 'ignored',
      'commits': commits.length,
    });
  }

  // 按项目名排序
  allItems.sort((a, b) => a['name'].compareTo(b['name']));

  // 统一输出
  for (var item in allItems) {
    final projectPath = item['path'] as String;
    final type = item['type'] as String;

    // 计算需要的空格数量来实现对齐
    final padding = maxPathLength - projectPath.length + 2; // +2 是为了增加一些间距

    if (type == 'commit') {
      final commits = item['commits'] as int;
      // 输出项目路径和对齐的commit总数
      buffer.write(
          '  $projectPath${' ' * padding}\x1B[32m$commits commits\x1B[0m\n');
    } else {
      final commits = item['commits'] as int;
      // 输出被忽略的项目路径和对齐的ignored标记，同时显示实际commit数量
      buffer.write(
          '  $projectPath${' ' * padding}\x1B[90m$commits commits (ignored)\x1B[0m\n');
    }
  }

  await Future.delayed(const Duration(milliseconds: 500));
  return buffer.toString();
}

// 合并ignore列表的工具方法
List<String> _mergeIgnoreLists(
    List<String> configIgnore, String? commandLineIgnore) {
  final ignoreSet = <String>{};

  ignoreSet.addAll(configIgnore);

  // 添加命令行参数中的 ignore
  if (commandLineIgnore != null && commandLineIgnore.isNotEmpty) {
    final commandIgnores = commandLineIgnore
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty);
    ignoreSet.addAll(commandIgnores);
  }

  return ignoreSet.toList();
}

// 合并authors列表的工具方法
List<String>? _mergeAuthorLists(
    String configAuthors, List<String>? commandLineAuthors) {
  // 如果命令行指定了 authors，优先使用命令行的（不合并）
  if (commandLineAuthors != null && commandLineAuthors.isNotEmpty) {
    return commandLineAuthors;
  }

  // 否则，使用配置文件中的 authors
  if (configAuthors.isNotEmpty) {
    return configAuthors
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }

  // 如果都没有，返回 null（GitService 将使用当前用户）
  return null;
}

List<String> _mergeAnalysisItems(
    List<String> preferredItems, List<String> fallbackItems) {
  final merged = <String>[];
  final seen = <String>{};

  for (final item in [...preferredItems, ...fallbackItems]) {
    final trimmed = item.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    merged.add(trimmed);
  }

  return merged;
}

class ReflectCommand extends Command {
  final _spinner = CliSpin(spinner: CliSpinners.dots5);

  @override
  String get description => 'Generate daily Git work log';

  @override
  String get name => 'reflect';

  ReflectCommand() {
    argParser.addFlag('verbose', abbr: 'v', help: 'Verbose output');
    argParser.addFlag('no-ai', help: 'Disable AI analysis');
    argParser.addOption('date', help: 'Specify date (format: YYYY-MM-DD)');
    argParser.addOption('code-dir', help: 'Code directory path');
    argParser.addOption('output-dir', help: 'Reflect output directory path');
    argParser.addOption(
      'ignore',
      help:
          'Ignore specific folders (comma-separated, e.g., "temp,node_modules")',
    );
    argParser.addOption(
      'language',
      abbr: 'l',
      help: 'Language for report generation (e.g., "zh-CN", "en-US", "ja-JP")',
    );
    argParser.addMultiOption(
      'author',
      abbr: 'a',
      help:
          'Filter commits by author name(s). Can be specified multiple times. (overrides default current user)',
    );
  }

  @override
  Future<void> run() async {
    stdout.writeln('\n--- AUTO REFLECT ---\n');

    final verbose = argResults?['verbose'] ?? false;
    final useAI = !(argResults?['no-ai'] ?? false);
    final date = argResults?['date'];
    final codeDir = argResults?['code-dir'];
    final outputDir = argResults?['output-dir'];
    final ignore = argResults?['ignore'];
    final language = argResults?['language'];
    final authors = argResults?['author'] as List<String>?;

    final logger = Logger(verbose: verbose);

    try {
      _spinner.start('Scanning repositories');
      final gitService = GitService(verbose: verbose);
      await gitService.initialize();
      _spinner.success();

      final config = await Config.load();
      final codeFolderPath = codeDir ?? config.codeDirectory;
      final reflectFolderPath = outputDir ?? config.outputDirectory;

      // 默认显示配置信息
      logger.log('Code directory: $codeFolderPath');
      logger.log('Reflect directory: $reflectFolderPath');

      final today = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      // 默认显示分析日期
      logger.log('Analysis date: $today');

      final codeDirectory = Directory(codeFolderPath);
      if (!await codeDirectory.exists()) {
        handleError('Code directory does not exist: $codeFolderPath');
      }

      await FileUtils.ensureDirectoryExists(reflectFolderPath);

      // 合并全局配置和命令行参数的 authors 设置
      final mergedAuthors = _mergeAuthorLists(config.authors, authors);

      final allProjectCommits = await gitService.scanGitProjects(
          codeDirectory, today,
          config: config, ignore: ignore, authors: mergedAuthors);

      // 合并全局配置和命令行参数的 ignore 设置
      final allIgnores = _mergeIgnoreLists(config.ignore, ignore);

      // 分离被忽略和未被忽略的项目
      final projectCommits = <String, List<GitCommit>>{};
      final ignoredProjectsWithCommits = <String, List<GitCommit>>{};

      for (var entry in allProjectCommits.entries) {
        final projectName = entry.key;
        final commits = entry.value;

        if (allIgnores.contains(projectName)) {
          ignoredProjectsWithCommits[projectName] = commits;
        } else {
          projectCommits[projectName] = commits;
        }
      }

      if (projectCommits.isEmpty && ignoredProjectsWithCommits.isEmpty) {
        showSuccess('No Git commits found today');
        return;
      }

      //  显示项目统计信息，参考auto_commit的格式
      var stat =
          await _getProjectStats(projectCommits, ignoredProjectsWithCommits);
      stdout.writeln(stat);

      AIAnalysisResult? aiAnalysis;
      if (useAI) {
        var aiConfig = await Config.load();
        if (language != null) {
          aiConfig = aiConfig.copyWith(language: language);
        }

        if (aiConfig.apiKey.isEmpty) {
          stdout.writeln(
              '[WARN] AI configuration is invalid or missing, skipping AI analysis');
          stdout.writeln('Please run: journal config');
        } else {
          // 统计所有需要处理的 commit 数量，用于进度显示
          var totalCommits = 0;
          for (var commits in projectCommits.values) {
            totalCommits += commits.length;
          }

          // 基于 diff 生成工作内容摘要（默认行为）
          if (projectCommits.isNotEmpty && totalCommits > 0) {
            var processedCount = 0;
            _spinner.start(
                'Generating work summaries from commit diffs (1/$totalCommits)');

            try {
              for (var projectName in projectCommits.keys) {
                final commits = projectCommits[projectName]!;
                final rewrittenCommits = <GitCommit>[];

                for (var commit in commits) {
                  processedCount++;
                  _spinner.text =
                      'Generating work summaries from commit diffs ($processedCount/$totalCommits)';

                  final diff = await gitService.getCommitDiff(
                      commit.hash, commit.projectPath);

                  if (diff.isEmpty) {
                    rewrittenCommits.add(commit);
                    continue;
                  }

                  final newMessage = await Generator.rewriteCommitMessage(
                    diff,
                    config: aiConfig,
                  );

                  rewrittenCommits.add(GitCommit(
                    hash: commit.hash,
                    author: commit.author,
                    email: commit.email,
                    message:
                        newMessage.isNotEmpty ? newMessage : commit.message,
                    date: commit.date,
                    projectPath: commit.projectPath,
                  ));
                }

                projectCommits[projectName] = rewrittenCommits;
              }
              _spinner.success();
            } catch (e) {
              _spinner.fail();
              stdout.writeln('[WARN] Failed to generate work summaries: $e');
            }
          }

          // AI 多维分析 + DailyPost 分析 并发执行
          final commitFuture = Generator.analyzeCommits(
            projectCommits,
            config: aiConfig,
          );

          // 用 NewsService 自动抓取 AI 日报
          final newsService = NewsService(logger: logger);
          final newsFuture = newsService.fetchDailyNews(today);

          _spinner.start('Generating reflect');

          var analysisOk = true;
          try {
            aiAnalysis = await commitFuture;
          } catch (e) {
            analysisOk = false;
            stdout.writeln('[ERROR] AI analysis failed: $e');
          }

          // 等待新闻抓取完成，然后进行 AI 分析
          try {
            final dailyNewsContent = await newsFuture;
            if (dailyNewsContent != null) {
              final dailyPostAnalysis = await Generator.analyzeDailyPost(
                dailyNewsContent,
                config: aiConfig,
              );
              final learnings = dailyPostAnalysis['learnings'] ?? [];
              final beneficial = dailyPostAnalysis['beneficialWork'] ?? [];
              if (learnings.isEmpty && beneficial.isEmpty) {
                stdout.writeln('[INFO] DailyPost analysis returned no items');
              }
              if (aiAnalysis != null) {
                aiAnalysis = AIAnalysisResult(
                  errorsAndIssues: aiAnalysis.errorsAndIssues,
                  nextImportantTasks: aiAnalysis.nextImportantTasks,
                  beneficialWork: _mergeAnalysisItems(
                      beneficial, aiAnalysis.beneficialWork),
                  highlights: aiAnalysis.highlights,
                  learnings:
                      _mergeAnalysisItems(learnings, aiAnalysis.learnings),
                  rawResponse: aiAnalysis.rawResponse,
                );
              } else {
                aiAnalysis = AIAnalysisResult(
                  errorsAndIssues: [],
                  nextImportantTasks: [],
                  beneficialWork: beneficial,
                  highlights: [],
                  learnings: learnings,
                  rawResponse: '',
                );
              }
            }
          } catch (e) {
            analysisOk = false;
            stdout.writeln('[WARN] DailyPost analysis failed: $e');
          }

          analysisOk ? _spinner.success() : _spinner.fail();
        }
      }

      final reportService = ReportService();
      final report = await reportService.generateReport(
          projectCommits, // 只使用未被忽略的项目生成报告
          today,
          aiAnalysis ??
              AIAnalysisResult(
                errorsAndIssues: [],
                nextImportantTasks: [],
                beneficialWork: [],
                highlights: [],
                learnings: [],
                rawResponse: '',
              ),
          language: language ?? config.language);

      final reportPath = FileUtils.joinPath(reflectFolderPath, '$today.md');
      await reportService.saveReport(
          Directory(reflectFolderPath), today, report);

      // 使用新的完成格式
      stdout.writeln('\nReflect completed ($reportPath)');
    } catch (e) {
      _spinner.fail();
      handleError('Error generating log: $e');
    }
  }
}
