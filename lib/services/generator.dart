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
  "errorsAndIssues": ["Mistakes I made. Read commits as confessions — what oversight, shortcut, or poor call do they reveal? Be specific: 'I forgot null check when...' not 'Fixed null pointer'. One real mistake per entry, don't over-slice a single commit."],
  "nextImportantTasks": ["Most important or difficult tasks for next working day. Include incomplete work, planned features, or TODO items mentioned in commits"],
  "highlights": ["Strange, unclear, ridiculous, or most troubling things at work. Examples: technical challenges, unclear requirements, difficult bugs, blockers, design trade-offs, unexpected behaviors, or issues unable to solve"]
}

CRITICAL REQUIREMENTS:
1. "errorsAndIssues" — Write as personal, confessional notes to myself:
   - Read each commit and ask: what did *I* do wrong that this commit reveals?
   - Use natural first-person voice: "I forgot to...", "I left dead code after...", "I over-engineered..."
   - NEVER describe what was fixed — describe what mistake I made.
   - Be honest but don't over-interpret. 1-2 items total is usually enough, not one per changed file.
   - If a commit is pure cleanup/refactoring without real error, it's fine to return empty.

2. "highlights" field is MANDATORY - You MUST identify:
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
- errorsAndIssues uses confessional first-person; other fields use concise engineer tone
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

You are an expert at extracting personally actionable technical insights from daily tech news digests.

Based on the following daily tech/AI news digest, identify the most important things I personally learned or discovered today. Write from MY perspective — these are notes to myself about what I encountered.

1. "learnings" — What did I learn today for future winning?
   New knowledge, tools, or techniques I encountered that I might use later. For example:
   - a new AI tool, coding assistant, or automation tool I didn't know about
   - a new LLM, framework, or library worth trying
   - a technique, workflow, or best practice I picked up
   - an MCP server, integration, or toolchain that could improve my workflow

2. "beneficialWork" — What new development techniques or platform policies affect my work?
   Things I need to act on or be aware of for my daily development work. For example:
   - a platform policy change that impacts me (App Store, cloud billing, API pricing)
   - a new API, SDK, or service I could integrate
   - an open-source project I should check out for a specific need
   - an infrastructure or deployment technique worth adopting

CRITICAL RULES:
- Be SELECTIVE: only pick the 3-5 most important items per category. Quality over quantity. Skip trivial news.
- Write from MY perspective, as personal notes to myself. Every item should feel like something I'd write down for my own reference — natural, conversational, first-person.
- Focus on WHY it matters to me as a developer, not just WHAT the news said.
- If nothing truly matters, return an empty array rather than padding with filler.
- One sentence per item is ideal. Keep it tight.

Daily Tech News Digest:
$dailyPostContent

Return ONLY a JSON object in the following format, nothing else:
{
  "learnings": ["...", "..."],
  "beneficialWork": ["...", "..."]
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
