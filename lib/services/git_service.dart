import 'dart:io';
import 'package:process_run/process_run.dart';
import 'package:path/path.dart' as path;
import '../models/git_commit.dart';
import '../models/config.dart';

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
    Directory codeDir,
    String date, {
    required Config config,
    String? ignore,
    List<String>? authors,
  }) async {
    final commits = <String, List<GitCommit>>{};

    await for (var entity
        in codeDir.list(recursive: false, followLinks: false)) {
      if (entity is Directory) {
        final projectName = path.basename(entity.path);

        final gitDir = Directory(path.join(entity.path, '.git'));
        if (await gitDir.exists()) {
          final projectCommits = await _getCommitsForDate(entity.path, date, authors: authors);
          if (projectCommits.isNotEmpty) {
            commits[projectName] = projectCommits;
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
      // 默认显示获取 Git 用户配置的错误信息
      stdout.writeln('Error getting Git user configuration: $e');
    }
  }

  Future<List<GitCommit>> _getCommitsForDate(
      String projectPath, String date, {List<String>? authors}) async {
    try {
      var gitCommand = [
        'log',
        '--since="$date 00:00:00"',
        '--until="$date 23:59:59"',
        '--pretty=format:%H|%an|%ae|%s|%ci',
        '--no-merges'
      ];

      // 确定作者过滤器
      String? authorFilter;
      if (authors != null && authors.isNotEmpty) {
        // 如果指定了多个作者，使用正则表达式匹配：(author1|author2|author3)
        if (authors.length == 1) {
          authorFilter = authors.first;
        } else {
          // 转义特殊字符并构建正则表达式
          final escapedAuthors = authors.map((a) => RegExp.escape(a)).join('|');
          authorFilter = '($escapedAuthors)';
        }
      } else if (_currentUserName != null) {
        // 如果没有指定作者，使用当前用户名
        authorFilter = _currentUserName;
      }

      if (authorFilter != null) {
        gitCommand.insert(1, '--author=$authorFilter');
      }

      var shell = Shell(verbose: false, workingDirectory: projectPath);
      var fullCommand = 'git ${gitCommand.join(' ')}';
      var result = await shell.run(fullCommand);

      if (result.first.exitCode != 0) {
        return [];
      }

      final commits = <GitCommit>[];
      final lines = result.first.stdout.toString().split('\n');

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
      return [];
    }
  }

  /// 获取指定 commit 的 diff
  Future<String> getCommitDiff(String commitHash, String projectPath) async {
    try {
      var shell = Shell(verbose: false, workingDirectory: projectPath);
      var result = await shell.run('git show $commitHash --stat --patch');

      if (result.first.exitCode != 0) {
        return '';
      }

      return result.first.stdout.toString();
    } catch (e) {
      return '';
    }
  }
}
