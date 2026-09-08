import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../models/ai_analysis.dart';

class ReportService {
  Future<String> generateReport(Map<String, List<String>> projectWork,
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

    // Add project work items
    if (projectWork.isNotEmpty) {
      final sortedProjects = projectWork.keys.toList()..sort();

      for (final projectName in sortedProjects) {
        final workItems = projectWork[projectName]!;
        buffer.writeln('### $projectName');
        buffer.writeln('');

        for (final item in workItems) {
          buffer.writeln('- $item');
        }
        buffer.writeln('');
      }
    }

    final learnings = _requiredItems(
      aiAnalysis?.learnings ?? const [],
      projectWork,
      RequiredSection.learnings,
      copy,
    );
    final highlights = _requiredItems(
      aiAnalysis?.highlights ?? const [],
      projectWork,
      RequiredSection.highlights,
      copy,
    );
    final beneficialWork =
        _meaningfulItems(aiAnalysis?.beneficialWork ?? const []);
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

    if (beneficialWork.isNotEmpty) {
      _writeSection(
        buffer,
        copy.beneficialWorkTitle,
        beneficialWork,
      );
    }

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
      Map<String, List<String>> projectWork,
      RequiredSection section,
      ReportCopy copy) {
    final meaningful = _meaningfulItems(items);
    if (meaningful.isNotEmpty) return meaningful;

    final summary = _summarizeWork(projectWork, copy);
    return [
      switch (section) {
        RequiredSection.learnings => copy.learningFallback(summary),
        RequiredSection.highlights => copy.highlightFallback(summary),
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
      Map<String, List<String>> projectWork, ReportCopy copy) {
    final workItems = projectWork.values
        .expand((items) => items)
        .map((item) => item.trim())
        .where(_isMeaningful)
        .map(_shorten)
        .toList();

    if (workItems.isEmpty) {
      return copy.emptyWorkSummary;
    }
    if (workItems.length == 1) return workItems.first;
    if (workItems.length == 2) {
      return '${workItems.first} and ${workItems[1]}';
    }
    return '${workItems.first}, ${workItems[1]}, and ${workItems.length - 2} other work items';
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
  });

  factory ReportCopy.forLanguage(String language) {
    return switch (language) {
      'zh-CN' => ReportCopy(
          title: '今日复盘',
          workSummary: '工作摘要',
          learningsTitle:
              '为了赢在未来我学到了什么：AI 工具的使用、Prompt 优化，以及有效 AI 资源的分享（沉淀成自己有价值的智慧）',
          highlightsTitle:
              '工作中或行业里有哪些奇怪、不清楚、离谱、最困扰，或与上个月相比变化异常的事情？或今天我无法解决的问题？',
          errorsTitle: '我或团队今天或最近几天犯的小错误或小失败',
          nextTasksTitle: '下一个工作日最重要或最困难的任务',
          beneficialWorkTitle: '我今天做的哪些事对客户或行业有好处？',
          emptyWorkSummary: '今天记录到的工作内容',
          learningFallback: (summary) =>
              '我今天主要从“$summary”里得到提醒：类似问题以后要更早识别特殊分支，不要只按通用流程处理。',
          highlightFallback: (summary) =>
              '今天最需要留意的是“$summary”，因为它说明这个边界场景之前没有被完整覆盖，后面可能还会冒出类似情况。',
        ),
      'zh-TW' => ReportCopy(
          title: '今日復盤',
          workSummary: '工作摘要',
          learningsTitle:
              '為了贏在未來我學到了什麼：AI 工具的使用、Prompt 優化，以及有效 AI 資源的分享（沉澱成自己有價值的智慧）',
          highlightsTitle:
              '工作中或產業裡有哪些奇怪、不清楚、離譜、最困擾，或與上個月相比變化異常的事情？或今天我無法解決的問題？',
          errorsTitle: '我或團隊今天或最近幾天犯的小錯誤或小失敗',
          nextTasksTitle: '下一個工作日最重要或最困難的任務',
          beneficialWorkTitle: '我今天做的哪些事對客戶或產業有好處？',
          emptyWorkSummary: '今天記錄到的工作內容',
          learningFallback: (summary) =>
              '我今天主要從「$summary」裡得到提醒：類似問題以後要更早識別特殊分支，不要只按通用流程處理。',
          highlightFallback: (summary) =>
              '今天最需要留意的是「$summary」，因為它說明這個邊界情境之前沒有被完整覆蓋，後面可能還會冒出類似情況。',
        ),
      _ => ReportCopy(
          title: 'Reflect Today',
          workSummary: 'Work summary',
          learningsTitle:
              'What I Learned to Win in the Future: Use of AI Tools, Prompt Optimization, and Sharing of Effective AI Resources',
          highlightsTitle:
              'Things at work or in the industry that are strange, unclear, ridiculous, most troubling, or oddly changed since last month? Or issues I\'m unable to solve today?',
          errorsTitle:
              'Small mistakes or failures I or the team made today or in the past few days',
          nextTasksTitle:
              'The most important or difficult tasks for the next working day',
          beneficialWorkTitle:
              'What things I did today are good for customers or industry?',
          emptyWorkSummary: 'the recorded work items for this report',
          learningFallback: (summary) =>
              'I used today\'s work on $summary as the main learning signal, especially for how to make similar changes easier to reason about next time.',
          highlightFallback: (summary) =>
              'The main thing I need to keep an eye on is $summary, because it is the clearest source of follow-up risk in today\'s commits.',
        ),
    };
  }
}
