class AIAnalysisResult {
  final List<String> errorsAndIssues;
  final List<String> nextImportantTasks;
  final List<String> beneficialWork;
  final List<String> highlights;
  final List<String> learnings;
  final String rawResponse;

  AIAnalysisResult({
    required this.errorsAndIssues,
    required this.nextImportantTasks,
    required this.beneficialWork,
    required this.highlights,
    required this.learnings,
    required this.rawResponse,
  });

  bool isEmpty() {
    return errorsAndIssues.isEmpty &&
        nextImportantTasks.isEmpty &&
        beneficialWork.isEmpty &&
        highlights.isEmpty &&
        learnings.isEmpty;
  }
}
