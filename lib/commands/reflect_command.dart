import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:intl/intl.dart';
import 'package:cli_spin/cli_spin.dart';
import '../models/config.dart';
import '../models/ai_analysis.dart';
import '../models/git_commit.dart';
import '../services/git_service.dart';
import '../services/generator.dart';
import '../services/report_service.dart';
import '../utils/logger.dart';
import '../utils/file_utils.dart';

void showSuccess(String message) {
  stdout.writeln('✅ $message');
}

void handleError(String message) {
  stderr.writeln('❌ $message');
  exit(1);
}

// 参考auto_commit的格式显示项目统计信息
Future<String> _getProjectStats(
    Map<String, List<GitCommit>> projectCommits) async {
  var buffer = StringBuffer();
  buffer.write('\n');

  for (var entry in projectCommits.entries) {
    final project = entry.key;
    final commits = entry.value;

    // 更详细的提交类型分析
    final fixCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('fix:') ||
            c.message.toLowerCase().startsWith('fix('))
        .length;

    final featCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('feat:') ||
            c.message.toLowerCase().startsWith('feat('))
        .length;

    final refactorCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('refactor:') ||
            c.message.toLowerCase().startsWith('refactor('))
        .length;

    final testCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('test:') ||
            c.message.toLowerCase().startsWith('test('))
        .length;

    final docsCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('docs:') ||
            c.message.toLowerCase().startsWith('docs('))
        .length;

    final styleCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('style:') ||
            c.message.toLowerCase().startsWith('style('))
        .length;

    final choreCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('chore:') ||
            c.message.toLowerCase().startsWith('chore('))
        .length;

    final buildCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('build:') ||
            c.message.toLowerCase().startsWith('build('))
        .length;

    final ciCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('ci:') ||
            c.message.toLowerCase().startsWith('ci('))
        .length;

    final perfCount = commits
        .where((c) =>
            c.message.toLowerCase().startsWith('perf:') ||
            c.message.toLowerCase().startsWith('perf('))
        .length;

    final otherCount = commits.length -
        fixCount -
        featCount -
        refactorCount -
        testCount -
        docsCount -
        styleCount -
        choreCount -
        buildCount -
        ciCount -
        perfCount;

    // 项目名称用绿色，显示详细的提交类型统计
    var stats = '\x1B[32m$project\x1B[0m';

    if (fixCount > 0) stats += ' \x1B[31mfix $fixCount\x1B[0m';
    if (featCount > 0) stats += ' \x1B[32mfeat $featCount\x1B[0m';
    if (refactorCount > 0) stats += ' refactor $refactorCount';
    if (testCount > 0) stats += ' test $testCount';
    if (docsCount > 0) stats += ' docs $docsCount';
    if (styleCount > 0) stats += ' style $styleCount';
    if (choreCount > 0) stats += ' chore $choreCount';
    if (buildCount > 0) stats += ' build $buildCount';
    if (ciCount > 0) stats += ' ci $ciCount';
    if (perfCount > 0) stats += ' perf $perfCount';
    if (otherCount > 0) stats += ' other $otherCount';

    buffer.write('$stats\n');
  }

  await Future.delayed(const Duration(milliseconds: 500));
  return buffer.toString();
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
  }

  @override
  Future<void> run() async {
    stdout.writeln('\n✧ ────────────── AUTO REFLECT ────────────── ✧\n');

    final verbose = argResults?['verbose'] ?? false;
    final useAI = !(argResults?['no-ai'] ?? false);
    final date = argResults?['date'];
    final codeDir = argResults?['code-dir'];
    final outputDir = argResults?['output-dir'];

    final logger = Logger(verbose: verbose);

    try {
      _spinner.start('Scanning Git projects');
      final gitService = GitService(verbose: verbose);
      await gitService.initialize();
      _spinner.success();

      final config = await Config.load();
      final codeFolderPath = codeDir ?? config.codeDirectory;
      final reflectFolderPath = outputDir ?? config.outputDirectory;

      if (verbose) {
        logger.log('Code directory: $codeFolderPath');
        logger.log('Reflect directory: $reflectFolderPath');
      }

      final today = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (verbose) {
        logger.log('Analysis date: $today');
      }

      final codeDirectory = Directory(codeFolderPath);
      if (!await codeDirectory.exists()) {
        handleError('Code directory does not exist: $codeFolderPath');
      }

      await FileUtils.ensureDirectoryExists(reflectFolderPath);

      final projectCommits =
          await gitService.scanGitProjects(codeDirectory, today);

      if (projectCommits.isEmpty) {
        showSuccess('No Git commits found today');
        return;
      }

      // 显示项目统计信息，参考auto_commit的格式
      var stat = await _getProjectStats(projectCommits);
      stdout.writeln(stat);

      AIAnalysisResult? aiAnalysis;
      if (useAI) {
        final config = await Config.load();
        if (config.apiKey.isEmpty) {
          stdout.writeln(
              '⚠️  AI configuration is invalid or missing, skipping AI analysis');
          stdout.writeln('Please run: journal config');
        } else {
          try {
            _spinner.start('Generating reflect');
            aiAnalysis =
                await Generator.analyzeCommits(projectCommits, config: config);
            _spinner.success();
          } catch (e) {
            _spinner.fail();
            stdout.writeln('❌ AI analysis failed: $e');
          }
        }
      }

      final reportService = ReportService();
      final report = await reportService.generateReport(
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

      final reportPath = FileUtils.joinPath(reflectFolderPath, '$today.md');
      await reportService.saveReport(
          Directory(reflectFolderPath), today, report);

      // 使用新的完成格式
      stdout.writeln('\n✨ Reflect completed ($reportPath)');
    } catch (e) {
      _spinner.fail();
      handleError('Error generating log: $e');
    }
  }
}
