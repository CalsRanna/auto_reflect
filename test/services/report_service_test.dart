import 'package:auto_reflect/models/ai_analysis.dart';
import 'package:auto_reflect/models/report_limits.dart';
import 'package:auto_reflect/services/report_service.dart';
import 'package:test/test.dart';

void main() {
  test('sections are written verbatim and never truncated', () async {
    final long = 'x' * (ReportLimits.nextImportantTasks + 50);
    final report = await ReportService().generateReport(
      {'proj': ['did a thing']},
      '2026-09-18',
      AIAnalysisResult(
        errorsAndIssues: [],
        nextImportantTasks: [long],
        beneficialWork: [],
        highlights: ['h'],
        learnings: ['l'],
        rawResponse: '',
      ),
    );
    expect(report, contains('- $long\n'));
    expect(report, isNot(contains('…')));
  });
}
