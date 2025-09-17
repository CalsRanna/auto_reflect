import 'dart:io';
import 'package:process_run/process_run.dart';
import 'package:path/path.dart' as path;
import '../models/git_commit.dart';

class GitService {
  final bool verbose;
  String? _currentUserName;
  String? _currentUserEmail;

  GitService({this.verbose = false});

  Future<void> initialize() async {
    await _getCurrentGitUserInfo();
  }

  // 提供公共访问方法
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;

  Future<Map<String, List<GitCommit>>> scanGitProjects(
      Directory codeDir, String date) async {
    final commits = <String, List<GitCommit>>{};

    await for (var entity
        in codeDir.list(recursive: false, followLinks: false)) {
      if (entity is Directory) {
        final gitDir = Directory(path.join(entity.path, '.git'));
        if (await gitDir.exists()) {
          if (verbose) {
            stdout.writeln('Scanning Git project: ${entity.path}');
          }

          final projectCommits = await _getCommitsForDate(entity.path, date);
          if (projectCommits.isNotEmpty) {
            commits[path.basename(entity.path)] = projectCommits;
          }
        }
      }
    }

    return commits;
  }

  Future<void> _getCurrentGitUserInfo() async {
    try {
      var shell = Shell(verbose: false);
      var userResult = await shell.run('git config user.name');
      if (userResult.first.exitCode == 0) {
        _currentUserName = userResult.first.stdout.toString().trim();
      }

      var emailResult = await shell.run('git config user.email');
      if (emailResult.first.exitCode == 0) {
        _currentUserEmail = emailResult.first.stdout.toString().trim();
      }

      if (_currentUserName == null && _currentUserEmail == null) {
        stdout.writeln(
            'Warning: Cannot get Git user configuration, will get all users\' commit records');
      }
    } catch (e) {
      if (verbose) {
        stdout.writeln('Error getting Git user configuration: $e');
      }
    }
  }

  Future<List<GitCommit>> _getCommitsForDate(
      String projectPath, String date) async {
    try {
      var gitCommand = [
        'log',
        '--since="$date 00:00:00"',
        '--until="$date 23:59:59"',
        '--pretty=format:%H|%an|%ae|%s|%ci',
        '--no-merges'
      ];

      if (_currentUserName != null) {
        gitCommand.insert(1, '--author=$_currentUserName');
      }

      if (verbose) {
        stdout.writeln('Project path: $projectPath');
        stdout.writeln('Git command: git ${gitCommand.join(' ')}');
      }

      var shell = Shell(verbose: false, workingDirectory: projectPath);
      var fullCommand = 'git ${gitCommand.join(' ')}';
      var result = await shell.run(fullCommand);

      if (result.first.exitCode != 0) {
        if (verbose) {
          stdout.writeln(
              'Failed to get Git log (${path.basename(projectPath)}): ${result.first.stderr}');
        }
        return [];
      }

      final commits = <GitCommit>[];
      final lines = result.first.stdout.toString().split('\n');

      if (verbose) {
        stdout.writeln(
            'Found ${lines.length - 1} log lines (${path.basename(projectPath)})');
      }

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split('|');
        if (parts.length >= 5) {
          commits.add(GitCommit(
            hash: parts[0],
            author: parts[1],
            email: parts[2],
            message: parts[3],
            date: parts[4],
            projectPath: projectPath,
          ));
        }
      }

      return commits;
    } catch (e) {
      if (verbose) {
        stdout.writeln(
            'Error getting commit records (${path.basename(projectPath)}): $e');
      }
      return [];
    }
  }
}
