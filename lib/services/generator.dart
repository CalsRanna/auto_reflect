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
    var userLanguageReminder = _getUserLanguageReminder(config.language);
    var commitsText = _formatCommitsForAI(commits);

    var writingStyle = _getPersonalWritingStyle(config.language);

    var prompt = '''
$languageInstruction
$writingStyle

You are helping me turn Git commits into a daily self-reflection.

Based on the following Git commit records, write practical notes that sound like I wrote them after work. Stay grounded in the commits and avoid exaggeration or self-praise.

$commitsText

Analyze the commits from multiple dimensions and return the results in the following JSON format:

{
  "errorsAndIssues": ["Mistakes I made. Read commits as confessions — what oversight, shortcut, or poor call do they reveal? Be specific: 'I forgot null check when...' not 'Fixed null pointer'. One real mistake per entry, don't over-slice a single commit."],
  "nextImportantTasks": ["Most important or difficult tasks for next working day. Include incomplete work, planned features, or TODO items mentioned in commits"],
  "learnings": ["Concrete things I learned, rediscovered, or experimented with from today's work. This field is required."],
  "beneficialWork": ["Development techniques, workflow improvements, reusable implementation patterns, or platform/API/policy implications that affect my work. This field is required."],
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

3. "learnings", "beneficialWork", and "highlights" are REQUIRED:
   - Return at least one concrete item for each of these three fields.
   - Do NOT use placeholders such as "", "None", "null", "N/A", or "No items".
   - If there is no obvious industry/news context, infer the learning or useful development technique from the commit work itself.

General Guidelines:
- Use natural first-person work-note tone
- Base analysis strictly on commit information
- Infer context from commit patterns (e.g., multiple commits on same file = difficult problem)
- Look for keywords: "feat", "fix", "add", "refactor", "optimize", "experiment", "try", "test"
- "errorsAndIssues" and "nextImportantTasks" are optional and may be empty when there is no honest signal
- DO NOT leave required fields empty
- Avoid corporate or AI-sounding phrases like "reusable pattern", "improving robustness", "clarifies the API contract", "downstream consumers", or "worth watching" unless those exact words are necessary
- errorsAndIssues uses confessional first-person; other fields should still sound like my own notes
- Return strictly in JSON format without other explanatory text
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(
          '$userLanguageReminder\n\n$commitsText'),
    );

    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [systemMessage, userMessage],
      temperature: 0.7,
      maxTokens: 1600,
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
    var userLanguageReminder = _getUserLanguageReminder(config.language);
    var targetLanguage = _languageName(config.language);

    var writingStyle = _getPersonalWritingStyle(config.language);

    var prompt = '''
$languageInstruction
$writingStyle

You are helping me extract personally useful notes from a daily tech news digest.

Based on the following daily tech/AI news digest, identify the most important things I personally learned or discovered today. Write from MY perspective — these are notes to myself about what I encountered.

OUTPUT LANGUAGE FOR DAILY NEWS:
- The news digest may be written in Chinese, English, or mixed languages.
- Your output MUST be written in $targetLanguage, matching the user's configured language.
- Translate and adapt every selected news item into $targetLanguage before returning it.
- Do NOT copy the source news sentence in its original language unless the source language is already $targetLanguage.
- Keep product names, model names, company names, API names, prices, and technical identifiers unchanged when needed.

1. "learnings" — What did I learn today for future winning?
   Every item in this array must be written in $targetLanguage. New knowledge, tools, or techniques I encountered that I might use later. For example:
   - a new AI tool, coding assistant, or automation tool I didn't know about
   - a new LLM, framework, or library worth trying
   - a technique, workflow, or best practice I picked up
   - an MCP server, integration, or toolchain that could improve my workflow

2. "beneficialWork" — What new development techniques or platform policies affect my work?
   Every item in this array must be written in $targetLanguage. Things I need to act on or be aware of for my daily development work. For example:
   - a platform policy change that impacts me (App Store, cloud billing, API pricing)
   - a new API, SDK, or service I could integrate
   - an open-source project I should check out for a specific need
   - an infrastructure or deployment technique worth adopting

CRITICAL RULES:
- Be SELECTIVE: only pick the 3-5 most important items per category. Quality over quantity. Skip trivial news.
- Write from MY perspective, as personal notes to myself. Every item should feel like something I'd write down for my own reference — natural, conversational, first-person.
- Focus on WHY it matters to me as a developer, not just WHAT the news said.
- Both "learnings" and "beneficialWork" are required when the digest has usable content. Return at least one concrete item for each category.
- Do NOT use placeholders such as "", "None", "null", "N/A", or "No items".
- Do NOT mix languages inside prose. The only exceptions are names and technical identifiers.
- Avoid press-release language. If a news item does not clearly affect my work, skip it.
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
      content: ChatCompletionUserMessageContent.string(
          '$userLanguageReminder\n\nDaily Tech News Digest:\n$dailyPostContent'),
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
    var userLanguageReminder = _getUserLanguageReminder(config.language);

    var writingStyle = _getPersonalWritingStyle(config.language);

    var prompt = '''
$languageInstruction
$writingStyle

You are helping me summarize one commit for my daily work log.

Based on the following git diff, generate a concise summary of what I actually did in this commit. Read the diff carefully and describe the actual changes and their purpose.

Rules:
1. Write 1 sentence describing the actual work completed
2. Be specific about what was implemented, fixed, or changed
3. Use clear, descriptive language - avoid generic descriptions like "updated code"
4. Focus on the substance and purpose of the changes
5. Write like a natural work-log note, not a marketing or architecture review sentence

Git Diff:
$diff

Return ONLY the work summary, nothing else.
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(
          '$userLanguageReminder\n\n$diff'),
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
      return _sanitizeScalarText(content);
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
        errorsAndIssues: _readStringList(jsonData['errorsAndIssues']),
        nextImportantTasks: _readStringList(jsonData['nextImportantTasks']),
        beneficialWork: _readStringList(jsonData['beneficialWork']),
        highlights: _readStringList(jsonData['highlights']),
        learnings: _readStringList(jsonData['learnings']),
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
        'learnings': _readStringList(jsonData['learnings']),
        'beneficialWork': _readStringList(jsonData['beneficialWork']),
      };
    } catch (e) {
      return {
        'learnings': <String>[],
        'beneficialWork': <String>[],
      };
    }
  }

  static String _getLanguageInstruction(String language) {
    final languageName = _languageName(language);
    return '''
IMPORTANT LANGUAGE RULE:
- Write every user-visible string in $languageName.
- JSON keys must stay in English, but every JSON string value must be in $languageName.
- If source material is in another language, translate and adapt it into $languageName.
- Do not mix languages unless a product name, API name, class name, error code, or technical identifier must stay as-is.
- Do not use emojis.
''';
  }

  static String _getUserLanguageReminder(String language) {
    final languageName = _languageName(language);
    return '''
Target output language: $languageName.
Translate or rewrite all prose into $languageName before returning the answer.
Keep product names, API names, class names, error codes, file names, and technical identifiers unchanged.
''';
  }

  static String _getPersonalWritingStyle(String language) {
    return switch (language) {
      'zh-CN' => '''
WRITING STYLE:
- 写得像我自己的日终复盘，不要像咨询报告、PR 稿或 AI 总结。
- 句子要具体、朴素、带一点真实工作感；可以用“我今天发现...”“这个地方之后要留意...”。
- 不要使用“提升健壮性”“赋能”“闭环”“最佳实践沉淀”“可复用模式”等套话，除非提交内容真的在说这些。
''',
      'zh-TW' => '''
WRITING STYLE:
- 寫得像我自己的日終復盤，不要像顧問報告、公關稿或 AI 摘要。
- 句子要具體、樸素、帶一點真實工作感；可以用「我今天發現...」「這個地方之後要留意...」。
- 不要使用套話，除非提交內容真的在說那些事情。
''',
      _ => '''
WRITING STYLE:
- Write like my own end-of-day notes, not a consulting report, press release, or AI summary.
- Be concrete and plainspoken. A little first-person is good.
- Avoid buzzwords and inflated claims.
''',
    };
  }

  static String _languageName(String language) {
    return switch (language) {
      'zh-CN' => 'Simplified Chinese (简体中文)',
      'zh-TW' => 'Traditional Chinese (繁體中文)',
      'ja-JP' => 'Japanese (日本語)',
      'ko-KR' => 'Korean (한국어)',
      'es-ES' => 'Spanish (Español)',
      'fr-FR' => 'French (Français)',
      'de-DE' => 'German (Deutsch)',
      'en-US' => 'English',
      _ => language.trim().isEmpty ? 'English' : language,
    };
  }

  static List<String> _readStringList(dynamic value) {
    final rawItems = switch (value) {
      List() => value,
      String() => [value],
      _ => const [],
    };

    return rawItems
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => !_isPlaceholder(item))
        .map(_sanitizeScalarText)
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _sanitizeScalarText(String value) {
    final trimmed = value.trim();
    if (_isPlaceholder(trimmed)) return '';
    return trimmed;
  }

  static bool _isPlaceholder(String value) {
    final normalized =
        value.replaceAll(RegExp(r'^[\*\-_`]+|[\*\-_`]+$'), '').trim();
    if (normalized.isEmpty) return true;

    final lower = normalized.toLowerCase();
    return {
      'none',
      'null',
      'n/a',
      'na',
      'no items',
      'no item',
      'nothing',
      'empty',
    }.contains(lower);
  }
}
