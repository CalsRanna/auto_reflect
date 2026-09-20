/// Character budgets for each report section, measured on the rendered
/// Markdown (bullet prefixes and line breaks included).
class ReportLimits {
  static const workSummary = 9999;
  static const learnings = 999;
  static const highlights = 999;
  static const errorsAndIssues = 999;
  static const nextImportantTasks = 400;
  static const beneficialWork = 2000;

  /// Learnings are merged from two AI calls (daily news digest and commit
  /// analysis); each gets its own share so the merged list still fits.
  static const newsLearnings = learnings ~/ 2;
  static const commitLearnings = learnings - newsLearnings;

  /// Overhead of a section body: the blank line after the heading and the two
  /// trailing newlines. Must match `ReportService._writeSectionContent`.
  static const sectionOverhead = 3;

  /// Length of the rendered bullet list for [items], exactly as the report
  /// writes it.
  static int renderedLength(List<String> items) =>
      renderBullets(items).length;

  static String renderBullets(List<String> items) =>
      items.map((item) => '- $item').join('\n');

  /// Length of one project block inside the work summary section.
  static int renderedProjectLength(String projectName, List<String> items) =>
      '### $projectName\n\n${renderBullets(items)}\n\n'.length;

  /// Budget available to the bullet list of a section with [limit].
  static int bodyBudget(int limit) => limit - sectionOverhead;
}
