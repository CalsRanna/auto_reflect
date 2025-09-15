import 'dart:io';
import 'dart:convert';
import 'config.dart';

class AIService {
  final AutoReflectConfig config;

  AIService({required this.config});

  Future<AIAnalysisResult> analyzeCommits(Map<String, List<GitCommit>> projectCommits) async {
    try {
      final commitsText = _formatCommitsForAI(projectCommits);

      final prompt = '''
根据以下Git提交记录，进行工作总结分析。要像工程师写技术笔记一样，用简洁、客观的语气，避免夸张和自我表扬。

$commitsText

请严格按照以下5个方面分析，如果某个方面没有相关内容，就写"无"：

1. 今天或过去几天犯的小错误
2. 下一个工作日最重要或最困难的任务
3. 今天我做了哪些对客户或行业有益的事情？
4. 工作中或行业内出现的奇怪、不明确、荒谬、最令人困扰或自上个月以来发生奇怪变化的事情？或者我今天无法解决的问题？
5. 为了未来的成功，我学到了什么，使用了哪些新工具、方法或人工智能工具，取得了什么成功或进行了哪些新尝试？

要求：
- 用简洁、客观的工程师语气
- 避免自我表扬和夸张语言
- 只基于实际的提交信息进行总结
- 每个方面实事求是，没有就写"无"
- 用第一人称，但不要过度使用"我"字
''';

      final response = await _callOpenAI(prompt);

      return _parseAIResponse(response);
    } catch (e) {
      throw Exception('AI分析失败: $e');
    }
  }

  Future<String> _callOpenAI(String prompt) async {
    final url = Uri.parse('${config.baseUrl}/chat/completions');

    final requestBody = {
      'model': config.model,
      'messages': [
        {
          'role': 'system',
          'content': '你是一个专业的软件开发顾问，擅长分析代码提交记录和提供有价值的工作建议。'
        },
        {
          'role': 'user',
          'content': prompt
        }
      ],
      'temperature': 0.7,
      'max_tokens': 1000
    };

    final client = HttpClient();
    final request = await client.postUrl(url);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer ${config.apiKey}');

    request.add(utf8.encode(jsonEncode(requestBody)));
    final httpResponse = await request.close();
    client.close();

    if (httpResponse.statusCode != 200) {
      throw Exception('API请求失败: ${httpResponse.statusCode}');
    }

    final responseBody = await httpResponse.transform(utf8.decoder).join();
    final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;

    final content = jsonResponse['choices'][0]['message']['content'] as String;
    return content;
  }

  String _formatCommitsForAI(Map<String, List<GitCommit>> projectCommits) {
    final buffer = StringBuffer();

    for (final projectName in projectCommits.keys) {
      buffer.writeln('项目: $projectName');
      final commits = projectCommits[projectName]!;
      for (final commit in commits) {
        buffer.writeln('- ${commit.message}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  AIAnalysisResult _parseAIResponse(String content) {
    final lines = content.split('\n');
    final sections = <String, List<String>>{};

    String? currentSection;

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 检测标题行 - 支持新的5个分析方面
      if (trimmedLine.contains('**') || trimmedLine.contains('##') ||
          trimmedLine.contains('为了未来的成功') || trimmedLine.contains('学到') || trimmedLine.contains('新工具') || trimmedLine.contains('方法') || trimmedLine.contains('人工智能') ||
          trimmedLine.contains('奇怪') || trimmedLine.contains('无法解决') || trimmedLine.contains('困扰') || trimmedLine.contains('荒谬') ||
          trimmedLine.contains('今天或过去几天犯的小错误') || trimmedLine.contains('小错误') || trimmedLine.contains('问题') ||
          trimmedLine.contains('下一个工作日最重要或最困难的任务') || trimmedLine.contains('重要任务') || trimmedLine.contains('困难') ||
          trimmedLine.contains('今天我做了哪些对客户或行业有益的事情') || trimmedLine.contains('有益')) {

        // 根据关键词映射到对应的section - 按照指定的顺序
        if (trimmedLine.contains('为了未来的成功') || trimmedLine.contains('学到') || trimmedLine.contains('新工具') || trimmedLine.contains('方法') || trimmedLine.contains('人工智能')) {
          currentSection = '为了未来的成功，我学到了什么，使用了哪些新工具、方法或人工智能工具，取得了什么成功或进行了哪些新尝试？';
        } else if (trimmedLine.contains('奇怪') || trimmedLine.contains('无法解决') || trimmedLine.contains('困扰') || trimmedLine.contains('荒谬')) {
          currentSection = '工作中或行业内出现的奇怪、不明确、荒谬、最令人困扰或自上个月以来发生奇怪变化的事情？或者我今天无法解决的问题？';
        } else if (trimmedLine.contains('今天或过去几天犯的小错误') || trimmedLine.contains('小错误')) {
          currentSection = '我今天或过去几天犯的小错误';
        } else if (trimmedLine.contains('下一个工作日最重要或最困难的任务') || trimmedLine.contains('重要任务') || trimmedLine.contains('困难')) {
          currentSection = '下一个工作日最重要或最困难的任务';
        } else if (trimmedLine.contains('今天我做了哪些对客户或行业有益的事情') || trimmedLine.contains('有益')) {
          currentSection = '今天我做了哪些对客户或行业有益的事情？';
        } else {
          currentSection = trimmedLine.replaceAll(RegExp(r'[#*\s]+'), '').trim();
        }
        sections[currentSection] = [];
      } else if (currentSection != null) {
        // 内容行
        if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('• ') ||
            trimmedLine.startsWith('1.') || trimmedLine.startsWith('2.') ||
            trimmedLine.startsWith('3.') || trimmedLine.startsWith('4.')) {
          sections[currentSection]!.add(trimmedLine);
        } else if (trimmedLine.isNotEmpty && !trimmedLine.contains('：')) {
          sections[currentSection]!.add(trimmedLine);
        }
      }
    }

    return AIAnalysisResult(
      errorsAndIssues: sections['我今天或过去几天犯的小错误'] ?? sections['今天或过去几天犯的小错误'] ?? sections['今天发现的小问题'] ?? sections['发现的小错误或问题'] ?? sections['小错误'] ?? sections['问题'] ?? [],
      nextImportantTasks: sections['下一个工作日最重要或最困难的任务'] ?? sections['明天要处理的重要任务'] ?? sections['下一个工作日最重要的任务'] ?? sections['重要任务'] ?? sections['挑战'] ?? [],
      beneficialWork: sections['今天我做了哪些对客户或行业有益的事情？'] ?? sections['今天我做了哪些对客户或行业有益的事情'] ?? sections['今天有价值的工作'] ?? sections['对客户或行业有益的事情'] ?? sections['有益'] ?? [],
      highlights: sections['工作中或行业内出现的奇怪、不明确、荒谬、最令人困扰或自上个月以来发生奇怪变化的事情？或者我今天无法解决的问题？'] ?? sections['工作中遇到的奇怪问题或无法解决的事情'] ?? sections['今天做得不错的方面'] ?? sections['工作亮点'] ?? sections['亮点'] ?? [],
      learnings: sections['为了未来的成功，我学到了什么，使用了哪些新工具、方法或人工智能工具，取得了什么成功或进行了哪些新尝试？'] ?? sections['学到的新知识或使用的工具方法'] ?? [],
      rawResponse: content,
    );
  }
}

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