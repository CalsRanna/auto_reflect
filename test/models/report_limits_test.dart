import 'package:auto_reflect/models/report_limits.dart';
import 'package:test/test.dart';

void main() {
  test('renderedLength matches the bullet list the report writes', () {
    expect(ReportLimits.renderedLength([]), 0);
    expect(ReportLimits.renderedLength(['a']), '- a'.length);
    expect(ReportLimits.renderedLength(['ab', 'c']), '- ab\n- c'.length);
  });

  test('news and commit learnings share the learnings budget', () {
    expect(ReportLimits.newsLearnings + ReportLimits.commitLearnings,
        ReportLimits.learnings);
  });

  test('bodyBudget reserves the section overhead', () {
    expect(ReportLimits.bodyBudget(100), 100 - ReportLimits.sectionOverhead);
  });
}
