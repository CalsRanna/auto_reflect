import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';
import '../models/config.dart';
import '../models/git_commit.dart';
import '../models/ai_analysis.dart';

class Generator {
  static Future<AIAnalysisResult> analyzeCommits(
    Map<String, List<GitCommit>> commits, {
    required Config config,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/auto_reflect',
      'X-Title': 'Auto Reflect',
    };

    var client = OpenAIClient(
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      headers: headers,
    );

    var languageInstruction = _getLanguageInstruction(config.language);
    var commitsText = _formatCommitsForAI(commits);

    var prompt = '''
$languageInstruction

You are a professional software development consultant who specializes in analyzing code commit records and providing valuable work insights.

Based on the following Git commit records, conduct a comprehensive work analysis. Write like an engineer taking technical notes, using concise and objective tone, avoiding exaggeration and self-praise.

$commitsText

Analyze the commits from multiple dimensions and return the results in the following JSON format:

{
  "errorsAndIssues": ["Small mistakes or failures from the commits. Examples: bugs fixed, incorrect implementations corrected, issues encountered during development"],
  "nextImportantTasks": ["Most important or difficult tasks for next working day. Include incomplete work, planned features, or TODO items mentioned in commits"],
  "highlights": ["Strange, unclear, ridiculous, or most troubling things at work. Examples: technical challenges, unclear requirements, difficult bugs, blockers, design trade-offs, unexpected behaviors, or issues unable to solve"]
}

CRITICAL REQUIREMENTS:
1. "highlights" field is MANDATORY - You MUST identify:
   - Technical challenges or blockers (difficult bugs, performance issues)
   - Unclear or changing requirements (reverted changes, multiple iterations)
   - Unsolved problems or workarounds (temporary fixes, commented-out code)
   - Interesting edge cases or unexpected behaviors
   - Areas needing improvement or refactoring
   Example: If commits show multiple attempts to fix the same issue, highlight the challenge

General Guidelines:
- Use concise, objective engineer tone
- Base analysis strictly on commit information
- Infer context from commit patterns (e.g., multiple commits on same file = difficult problem)
- Look for keywords: "feat", "fix", "add", "refactor", "optimize", "experiment", "try", "test"
- DO NOT leave "errorsAndIssues" or "highlights" empty unless truly no relevant information exists
- Use first person, but don't overuse "I"
- Return strictly in JSON format without other explanatory text
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(commitsText),
    );

    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [systemMessage, userMessage],
      temperature: 0.7,
      maxTokens: 1000,
    );

    try {
      var response = await client.createChatCompletion(request: request);
      var content = response.choices.first.message.content ?? '';
      return _parseAIResponse(content);
    } finally {
      client.endSession();
    }
  }

  /// 分析 DailyPost 文件内容，提取 learnings 和 beneficialWork
  ///
  /// 从 DailyPost 的行业新闻中提取：学到的新工具/方法/AI工具、新的开发技术/政策
  static Future<Map<String, List<String>>> analyzeDailyPost(
    String dailyPostContent, {
    required Config config,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/auto_reflect',
      'X-Title': 'Auto Reflect',
    };

    var client = OpenAIClient(
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      headers: headers,
    );

    var languageInstruction = _getLanguageInstruction(config.language);

    var prompt = '''
$languageInstruction

You are an expert at extracting actionable technical insights from daily tech news digests.

Based on the following daily tech/AI news digest, extract two types of insights:

1. "learnings" - What did I learn today for future winning? Focus on:
   - New AI tools, coding assistants, or automation tools discovered
   - New LLMs, frameworks, or libraries announced
   - Interesting experiments, approaches, or techniques mentioned
   - Development workflows or best practices discovered
   - New MCP servers, integrations, or toolchains

2. "beneficialWork" - What new development techniques, tools, or platform policies? Focus on:
   - New development tools or techniques worth trying
   - Platform policy changes or new requirements (App Store, cloud platforms, etc.)
   - New APIs, SDKs, or services announced
   - New open-source projects that could be useful
   - Infrastructure or deployment improvements discovered

Rules:
- Be specific and actionable (not generic observations)
- Focus on items that are directly useful for a software developer's daily work
- Extract concrete tools, techniques, and insights, not just news summaries
- Write in concise bullet-point style
- If no relevant insights exist for a category, return an empty array

Daily Tech News Digest:
$dailyPostContent

Return ONLY a JSON object in the following format, nothing else:
{
  "learnings": ["insight 1", "insight 2"],
  "beneficialWork": ["technique 1", "technique 2"]
}
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(dailyPostContent),
    );

    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [systemMessage, userMessage],
      temperature: 0.5,
      maxTokens: 600,
    );

    try {
      var response = await client.createChatCompletion(request: request);
      var content = response.choices.first.message.content ?? '';
      return _parseDailyPostResponse(content);
    } finally {
      client.endSession();
    }
  }

  /// 使用 AI 根据 diff 生成工作内容摘要
  ///
  /// 读取每次提交的具体内容（diff），生成描述性工作内容，不再参考 commit message
  static Future<String> rewriteCommitMessage(
    String diff, {
    required Config config,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/auto_reflect',
      'X-Title': 'Auto Reflect',
    };

    var client = OpenAIClient(
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      headers: headers,
    );

    var languageInstruction = _getLanguageInstruction(config.language);

    var prompt = '''
$languageInstruction

You are an expert at analyzing code changes and summarizing the actual work performed.

Based on the following git diff, generate a concise summary of what work was actually done in this commit. Read the diff carefully and describe the actual changes and their purpose.

Rules:
1. Write 1-2 sentences describing the actual work completed
2. Be specific about what was implemented, fixed, or changed
3. Use clear, descriptive language - avoid generic descriptions like "updated code"
4. Focus on the substance and purpose of the changes
5. Write in a professional but natural style, suitable for daily work reports

Git Diff:
$diff

Return ONLY the work summary, nothing else.
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(diff),
    );

    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [systemMessage, userMessage],
      temperature: 0.5,
      maxTokens: 200,
    );

    try {
      var response = await client.createChatCompletion(request: request);
      var content = response.choices.first.message.content ?? '';
      return content.trim();
    } finally {
      client.endSession();
    }
  }

  static String _formatCommitsForAI(
      Map<String, List<GitCommit>> projectCommits) {
    final buffer = StringBuffer();

    for (final projectName in projectCommits.keys) {
      buffer.writeln('Project: $projectName');
      final commits = projectCommits[projectName]!;
      for (final commit in commits) {
        buffer.writeln('- ${commit.message}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  static AIAnalysisResult _parseAIResponse(String content) {
    try {
      // Try to extract JSON part (remove possible markdown markup)
      final jsonContent =
          content.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();

      final Map<String, dynamic> jsonData = jsonDecode(jsonContent);

      return AIAnalysisResult(
        errorsAndIssues: List<String>.from(jsonData['errorsAndIssues'] ?? []),
        nextImportantTasks:
            List<String>.from(jsonData['nextImportantTasks'] ?? []),
        beneficialWork: List<String>.from(jsonData['beneficialWork'] ?? []),
        highlights: List<String>.from(jsonData['highlights'] ?? []),
        learnings: List<String>.from(jsonData['learnings'] ?? []),
        rawResponse: content,
      );
    } catch (e) {
      // If JSON parsing fails, return empty result
      return AIAnalysisResult(
        errorsAndIssues: [],
        nextImportantTasks: [],
        beneficialWork: [],
        highlights: [],
        learnings: [],
        rawResponse: content,
      );
    }
  }

  static Map<String, List<String>> _parseDailyPostResponse(String content) {
    try {
      final jsonContent =
          content.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();

      final Map<String, dynamic> jsonData = jsonDecode(jsonContent);

      return {
        'learnings': List<String>.from(jsonData['learnings'] ?? []),
        'beneficialWork': List<String>.from(jsonData['beneficialWork'] ?? []),
      };
    } catch (e) {
      return {
        'learnings': <String>[],
        'beneficialWork': <String>[],
      };
    }
  }

  static String _getLanguageInstruction(String language) {
    return switch (language) {
      'zh-CN' => 'IMPORTANT: You must respond in Simplified Chinese (简体中文).',
      'zh-TW' => 'IMPORTANT: You must respond in Traditional Chinese (繁體中文).',
      'ja-JP' => 'IMPORTANT: You must respond in Japanese (日本語).',
      'ko-KR' => 'IMPORTANT: You must respond in Korean (한국어).',
      'es-ES' => 'IMPORTANT: You must respond in Spanish (Español).',
      'fr-FR' => 'IMPORTANT: You must respond in French (Français).',
      'de-DE' => 'IMPORTANT: You must respond in German (Deutsch).',
      'en-US' => 'IMPORTANT: You must respond in English (English).', // Default
      _ => '',
    };
  }
}
