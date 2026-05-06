import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../models/git_commit.dart';
import '../models/ai_analysis.dart';

class ReportService {
  Future<String> generateReport(Map<String, List<GitCommit>> projectCommits,
      String date, AIAnalysisResult? aiAnalysis,
      {String language = 'en-US'}) async {
    final buffer = StringBuffer();
    final copy = ReportCopy.forLanguage(language);
    final dateTime = DateFormat('yyyy-MM-dd').parse(date);
    final formattedDate = DateFormat('yyyy/MM/dd').format(dateTime);

    buffer.writeln('# ${copy.title} - $formattedDate');
    buffer.writeln('');

    buffer.writeln('## ${copy.workSummary}');
    buffer.writeln('');

    // Add commit records
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

    final learnings = _requiredItems(
      aiAnalysis?.learnings ?? const [],
      projectCommits,
      RequiredSection.learnings,
      copy,
    );
    final highlights = _requiredItems(
      aiAnalysis?.highlights ?? const [],
      projectCommits,
      RequiredSection.highlights,
      copy,
    );
    final beneficialWork = _requiredItems(
      aiAnalysis?.beneficialWork ?? const [],
      projectCommits,
      RequiredSection.beneficialWork,
      copy,
    );
    final errorsAndIssues =
        _meaningfulItems(aiAnalysis?.errorsAndIssues ?? const []);
    final nextImportantTasks =
        _meaningfulItems(aiAnalysis?.nextImportantTasks ?? const []);

    _writeSection(
      buffer,
      copy.learningsTitle,
      learnings,
    );

    _writeSection(
      buffer,
      copy.highlightsTitle,
      highlights,
    );

    if (errorsAndIssues.isNotEmpty) {
      _writeSection(
        buffer,
        copy.errorsTitle,
        errorsAndIssues,
      );
    }

    if (nextImportantTasks.isNotEmpty) {
      _writeSection(
        buffer,
        copy.nextTasksTitle,
        nextImportantTasks,
      );
    }

    _writeSection(
      buffer,
      copy.beneficialWorkTitle,
      beneficialWork,
    );

    return buffer.toString();
  }

  Future<void> saveReport(
      Directory reflectDir, String date, String content) async {
    final fileName = '$date.md';
    final filePath = path.join(reflectDir.path, fileName);

    final file = File(filePath);
    await file.writeAsString(content);
  }

  void _writeSection(StringBuffer buffer, String title, List<String> items) {
    buffer.writeln('## $title');
    buffer.writeln('');
    for (final item in items) {
      buffer.writeln('- $item');
    }
    buffer.writeln('');
  }

  List<String> _requiredItems(
      List<String> items,
      Map<String, List<GitCommit>> projectCommits,
      RequiredSection section,
      ReportCopy copy) {
    final meaningful = _meaningfulItems(items);
    if (meaningful.isNotEmpty) return meaningful;

    final summary = _summarizeWork(projectCommits, copy);
    return [
      switch (section) {
        RequiredSection.learnings => copy.learningFallback(summary),
        RequiredSection.highlights => copy.highlightFallback(summary),
        RequiredSection.beneficialWork => copy.beneficialWorkFallback(summary),
      }
    ];
  }

  List<String> _meaningfulItems(List<String> items) {
    return items.map((item) => item.trim()).where(_isMeaningful).toList();
  }

  bool _isMeaningful(String value) {
    final normalized =
        value.replaceAll(RegExp(r'^[\*\-_`]+|[\*\-_`]+$'), '').trim();
    if (normalized.isEmpty) return false;

    final lower = normalized.toLowerCase();
    return !{
      'none',
      'null',
      'n/a',
      'na',
      'no items',
      'no item',
      'nothing',
      'empty',
    }.contains(lower);
  }

  String _summarizeWork(
      Map<String, List<GitCommit>> projectCommits, ReportCopy copy) {
    final commitMessages = projectCommits.values
        .expand((commits) => commits)
        .map((commit) => commit.message.trim())
        .where(_isMeaningful)
        .map(_shorten)
        .toList();

    if (commitMessages.isEmpty) {
      return copy.emptyWorkSummary;
    }
    if (commitMessages.length == 1) return commitMessages.first;
    if (commitMessages.length == 2) {
      return '${commitMessages.first} and ${commitMessages[1]}';
    }
    return '${commitMessages.first}, ${commitMessages[1]}, and ${commitMessages.length - 2} other work items';
  }

  String _shorten(String value) {
    const maxLength = 120;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}

enum RequiredSection {
  learnings,
  highlights,
  beneficialWork,
}

class ReportCopy {
  final String title;
  final String workSummary;
  final String learningsTitle;
  final String highlightsTitle;
  final String errorsTitle;
  final String nextTasksTitle;
  final String beneficialWorkTitle;
  final String emptyWorkSummary;
  final String Function(String summary) learningFallback;
  final String Function(String summary) highlightFallback;
  final String Function(String summary) beneficialWorkFallback;

  const ReportCopy({
    required this.title,
    required this.workSummary,
    required this.learningsTitle,
    required this.highlightsTitle,
    required this.errorsTitle,
    required this.nextTasksTitle,
    required this.beneficialWorkTitle,
    required this.emptyWorkSummary,
    required this.learningFallback,
    required this.highlightFallback,
    required this.beneficialWorkFallback,
  });

  factory ReportCopy.forLanguage(String language) {
    return switch (language) {
      'zh-CN' => ReportCopy(
          title: '今日复盘',
          workSummary: '工作摘要',
          learningsTitle: '为了以后做得更好，我今天学到了什么、新用了哪些工具/方法/AI 工具，以及有哪些成功尝试或新实验？',
          highlightsTitle: '工作中或行业里有哪些奇怪、不清楚、离谱、最困扰，或最近变化明显的事情？今天有没有暂时解决不了的问题？',
          errorsTitle: '我或团队今天/最近几天犯的小错误或踩过的坑',
          nextTasksTitle: '下一个工作日最重要或最困难的任务',
          beneficialWorkTitle: '今天学到哪些新的开发技术或应用商店/平台政策？',
          emptyWorkSummary: '今天记录到的工作内容',
          learningFallback: (summary) =>
              '我今天主要从“$summary”里得到提醒：类似问题以后要更早识别特殊分支，不要只按通用流程处理。',
          highlightFallback: (summary) =>
              '今天最需要留意的是“$summary”，因为它说明这个边界场景之前没有被完整覆盖，后面可能还会冒出类似情况。',
          beneficialWorkFallback: (summary) =>
              '今天可以沉淀的一点做法是：处理“$summary”这类问题时，把原始响应和明确的错误类型一起保留下来，方便后续定位和展示。',
        ),
      'zh-TW' => ReportCopy(
          title: '今日復盤',
          workSummary: '工作摘要',
          learningsTitle: '為了以後做得更好，我今天學到了什麼、新用了哪些工具/方法/AI 工具，以及有哪些成功嘗試或新實驗？',
          highlightsTitle: '工作中或產業裡有哪些奇怪、不清楚、離譜、最困擾，或最近變化明顯的事情？今天有沒有暫時解不了的問題？',
          errorsTitle: '我或團隊今天/最近幾天犯的小錯或踩過的坑',
          nextTasksTitle: '下一個工作日最重要或最困難的任務',
          beneficialWorkTitle: '今天學到哪些新的開發技術或 App Store/平台政策？',
          emptyWorkSummary: '今天記錄到的工作內容',
          learningFallback: (summary) =>
              '我今天主要從「$summary」裡得到提醒：類似問題以後要更早識別特殊分支，不要只按通用流程處理。',
          highlightFallback: (summary) =>
              '今天最需要留意的是「$summary」，因為它說明這個邊界情境之前沒有被完整覆蓋，後面可能還會冒出類似情況。',
          beneficialWorkFallback: (summary) =>
              '今天可以沉澱的一點做法是：處理「$summary」這類問題時，把原始回應和明確的錯誤類型一起保留下來，方便後續定位和展示。',
        ),
      _ => ReportCopy(
          title: 'Reflect Today',
          workSummary: 'Work Summary',
          learningsTitle:
              'What did I learn for the purpose of future winning, what new tools, methods, or AI tools did I use, and what success or new experiments did I have?',
          highlightsTitle:
              'Things at work or in the industry that are strange, unclear, ridiculous, most troubling, or oddly changed since last month? Or issues I\'m unable to solve today?',
          errorsTitle:
              'Small mistakes or failures I or the team made today or in the past few days',
          nextTasksTitle:
              'The most important or difficult tasks for the next working day',
          beneficialWorkTitle:
              'What new development techniques or new app store policies did I learn about today?',
          emptyWorkSummary: 'the recorded work items for this report',
          learningFallback: (summary) =>
              'I used today\'s work on $summary as the main learning signal, especially for how to make similar changes easier to reason about next time.',
          highlightFallback: (summary) =>
              'The main thing I need to keep an eye on is $summary, because it is the clearest source of follow-up risk in today\'s commits.',
          beneficialWorkFallback: (summary) =>
              'One useful development habit from today is to keep the original response and a clear error type together when handling work like $summary.',
        ),
    };
  }
}
