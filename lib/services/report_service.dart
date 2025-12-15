import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../models/git_commit.dart';
import '../models/ai_analysis.dart';

class ReportService {
  Future<String> generateReport(Map<String, List<GitCommit>> projectCommits,
      String date, AIAnalysisResult? aiAnalysis) async {
    final buffer = StringBuffer();
    final dateTime = DateFormat('yyyy-MM-dd').parse(date);
    final formattedDate = DateFormat('yyyy/MM/dd').format(dateTime);

    buffer.writeln('# Reflect Today - $formattedDate');
    buffer.writeln('');

    buffer.writeln('## Work Summary');
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

    // Add AI analysis results
    if (aiAnalysis != null && !aiAnalysis.isEmpty()) {
      if (aiAnalysis.learnings.isNotEmpty) {
        buffer.writeln(
            '## What did I learn for the purpose of future winning, what new tools, methods, or AI tools did I use, and what success or new experiments did I have?');
        buffer.writeln('');
        for (final learning in aiAnalysis.learnings) {
          buffer.writeln('- $learning');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.highlights.isNotEmpty) {
        buffer.writeln(
            '## Things at work or in the industry that are strange, unclear, ridiculous, most troubling, or oddly changed since last month? Or issues I\'m unable to solve today?');
        buffer.writeln('');
        for (final highlight in aiAnalysis.highlights) {
          buffer.writeln('- $highlight');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.errorsAndIssues.isNotEmpty) {
        buffer.writeln(
            '##  Small mistakes or failures I made today or in the past few days');
        buffer.writeln('');
        for (final issue in aiAnalysis.errorsAndIssues) {
          buffer.writeln('- $issue');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.nextImportantTasks.isNotEmpty) {
        buffer.writeln(
            '## The most important or difficult tasks for the next working day');
        buffer.writeln('');
        for (final task in aiAnalysis.nextImportantTasks) {
          buffer.writeln('- $task');
        }
        buffer.writeln('');
      }

      if (aiAnalysis.beneficialWork.isNotEmpty) {
        buffer.writeln(
            '## What new development techniques or new app store policies did I learn about today?');
        buffer.writeln('');
        for (final beneficial in aiAnalysis.beneficialWork) {
          buffer.writeln('- $beneficial');
        }
        buffer.writeln('');
      }
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
}
