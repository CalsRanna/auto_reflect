class GitCommit {
  final String hash;
  final String author;
  final String email;
  final String message;
  final String date;
  final String projectPath;

  GitCommit({
    required this.hash,
    required this.author,
    required this.email,
    required this.message,
    required this.date,
    required this.projectPath,
  });
}
