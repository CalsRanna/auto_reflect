import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';
import '../models/config.dart';
import '../models/git_commit.dart';
import '../models/ai_analysis.dart';
import '../models/report_limits.dart';
import 'git_service.dart';

class Generator {
  static Future<Map<String, List<String>>> generateProjectWork(
    Map<String, List<GitCommit>> projectCommits, {
    required Config config,
    required GitService gitService,
    void Function(String project, int processed, int total)? onProgress,
  }) async {
    final projectWork = <String, List<String>>{};
    final failures = <String>[];
    var processed = 0;

    for (final entry in projectCommits.entries) {
      final commits = entry.value;
      onProgress?.call(entry.key, ++processed, projectCommits.length);
      if (commits.isEmpty) continue;
      try {
        final diffs = <String, String>{};
        for (final commit in commits.reversed) {
          final diff =
              await gitService.getCommitDiff(commit.hash, commit.projectPath);
          if (diff.trim().isEmpty) {
            throw StateError('Commit ${commit.hash} diff is empty');
          }
          diffs[commit.hash] = diff;
        }
        projectWork[entry.key] = await generateWorkItems(
          entry.key,
          diffs,
          config: config,
          maxCharacters: ReportLimits.workSummary ~/ projectCommits.length,
        );
      } catch (e) {
        failures.add('${entry.key}: $e');
      }
    }

    if (failures.isNotEmpty) {
      throw StateError(
        'Failed to summarize ${failures.length}/${projectCommits.length} projects. '
        'Report was not saved.\n${failures.join('\n')}',
      );
    }
    return projectWork;
  }

  static Future<AIAnalysisResult> analyzeWork(
    Map<String, List<String>> projectWork, {
    required Config config,
    bool prioritizeMistake = false,
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
    var commitsText = _formatWorkForAI(projectWork);

    var writingStyle = _getPersonalWritingStyle(config.language);
    final mistakeRequirement = prioritizeMistake
        ? 'This is a Friday report, the weekly checkpoint for mistakes and failures. '
            'Prioritize identifying at least one concrete, evidence-based mistake '
            'or failure when the supplied work supports it. Do not invent events, blame, or personal admissions '
            'unsupported by the work. If no honest mistake can be identified, '
            'return an empty errorsAndIssues array and generate all other fields normally.'
        : 'errorsAndIssues is optional and may be empty when there is no honest signal.';

    var prompt = '''
$languageInstruction
$writingStyle

You are helping me turn Git commits into a daily self-reflection.

Based on the following work summaries derived from Git diffs, write practical notes that sound like I wrote them after work. Stay grounded in the work and avoid exaggeration or self-praise.

$commitsText

Analyze the commits from multiple dimensions and return the results in the following JSON format:

{
  "errorsAndIssues": ["Mistakes I made. Read commits as confessions — what oversight, shortcut, or poor call do they reveal? Be specific: 'I forgot null check when...' not 'Fixed null pointer'. One real mistake per entry, don't over-slice a single commit."],
  "nextImportantTasks": ["Most important or difficult tasks for next working day. Include incomplete work, planned features, or TODO items mentioned in commits"],
  "learnings": ["What I learned today that helps me win in the future: how I used AI tools, prompts I refined, AI resources or workflows worth keeping, plus concrete techniques I learned or rediscovered from the work itself. This field is required."],
  "beneficialWork": ["What I did today that is good for customers or for the industry. Focus on the long-term interest of the majority of users: bugs that hurt them, features they asked for, performance or reliability they will feel, work others can reuse. Leave empty if today's commits are purely internal chores with no user-facing value."],
  "highlights": ["Strange, unclear, ridiculous, or most troubling things at work. Examples: technical challenges, unclear requirements, difficult bugs, blockers, design trade-offs, unexpected behaviors, or issues unable to solve"]
}

CRITICAL REQUIREMENTS:
0. Character limits apply to each field's ENTIRE array, not each item:
   - learnings: ${ReportLimits.learnings}
   - highlights: ${ReportLimits.highlights}
   - errorsAndIssues: ${ReportLimits.errorsAndIssues}
   - nextImportantTasks: ${ReportLimits.nextImportantTasks}
   - beneficialWork: ${ReportLimits.beneficialWork}
   Count characters, not words, including spaces, punctuation, bullet prefixes, and line breaks. Keep comfortably below these limits by prioritizing and writing concise, complete sentences.

1. "errorsAndIssues" — Write as personal, confessional notes to myself:
   - Read each commit and ask: what did *I* do wrong that this commit reveals?
   - Use natural first-person voice: "I forgot to...", "I left dead code after...", "I over-engineered..."
   - NEVER describe what was fixed — describe what mistake I made.
   - Be honest but don't over-interpret. 1-2 items total is usually enough, not one per changed file.
   - $mistakeRequirement

2. "highlights" field is MANDATORY - You MUST identify:
   - Technical challenges or blockers (difficult bugs, performance issues)
   - Unclear or changing requirements (reverted changes, multiple iterations)
   - Unsolved problems or workarounds (temporary fixes, commented-out code)
   - Interesting edge cases or unexpected behaviors
   - Areas needing improvement or refactoring
   Example: If commits show multiple attempts to fix the same issue, highlight the challenge

3. "learnings" and "highlights" are REQUIRED:
   - Return at least one concrete item for each of these two fields.
   - Do NOT use placeholders such as "", "None", "null", "N/A", or "No items".
   - If there is no obvious AI-tool or industry context, infer the learning from the commit work itself.

4. "beneficialWork" — answer from the customer's side, not mine:
   - Say what a user or the wider industry actually gets out of today's work.
   - Write it as a benefit, not as a task list: "users on old devices stop hitting the crash..." not "fixed crash".
   - It is fine to return an empty array when today's work has no honest customer-facing benefit.

General Guidelines:
- Use natural first-person work-note tone
- Base analysis strictly on commit information
- Infer context from commit patterns (e.g., multiple commits on same file = difficult problem)
- Look for keywords: "feat", "fix", "add", "refactor", "optimize", "experiment", "try", "test"
- "nextImportantTasks" and "beneficialWork" are optional and may be empty when there is no honest signal
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
      for (var attempt = 0;; attempt++) {
        final response = await client.createChatCompletion(request: request);
        final choice = response.choices.first;
        final result = _parseAIResponse(choice.message.content ?? '');
        if (!prioritizeMistake ||
            choice.finishReason != ChatCompletionFinishReason.length ||
            attempt == 2) {
          return result;
        }
        request = request.copyWith(maxTokens: request.maxTokens! * 2);
      }
    } finally {
      client.endSession();
    }
  }

  /// 分析 DailyPost 文件内容，提取 learnings
  ///
  /// 对应日报第 2 项：AI 工具的使用、Prompt 优化、有效 AI 资源的分享
  static Future<List<String>> analyzeDailyPost(
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

1. "learnings" — What did I learn today that helps me win in the future?
   Every item in this array must be written in $targetLanguage. Focus on AI tools, prompt techniques, and effective AI resources I could actually adopt. For example:
   - a new AI tool, coding assistant, or agent I didn't know about
   - a new LLM, framework, or library worth trying, and what it is good at
   - a prompting technique, workflow, or best practice I could reuse
   - an MCP server, integration, or toolchain that could improve my workflow
   - a platform, API, or pricing change that changes which tool I should reach for

CRITICAL RULES:
- The ENTIRE learnings array must fit within ${ReportLimits.learnings} characters, not words, including spaces, punctuation, bullet prefixes, and line breaks. Prioritize the most useful items and write concise, complete sentences.
- Be SELECTIVE: only pick the 3-5 most important items. Quality over quantity. Skip trivial news.
- Write from MY perspective, as personal notes to myself. Every item should feel like something I'd write down for my own reference — natural, conversational, first-person.
- Focus on WHY it matters to me as a developer, not just WHAT the news said.
- Return at least one concrete item when the digest has usable content.
- Do NOT use placeholders such as "", "None", "null", "N/A", or "No items".
- Do NOT mix languages inside prose. The only exceptions are names and technical identifiers.
- Avoid press-release language. If a news item does not clearly affect my work, skip it.
- One sentence per item is ideal. Keep it tight.

Daily Tech News Digest:
$dailyPostContent

Return ONLY a JSON object in the following format, nothing else:
{
  "learnings": ["...", "..."]
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

  static Future<List<String>> generateWorkItems(
    String projectName,
    Map<String, String> diffs, {
    required Config config,
    int maxCharacters = ReportLimits.workSummary,
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

You are helping me summarize one project's commits for my daily work log.

Read all supplied commit diffs together and describe the work completed on this project today.
The input commits are ordered from oldest to newest.

Rules:
1. Write one concise sentence per distinct piece of work completed
2. Be specific about what was implemented, fixed, or changed
3. Use clear, descriptive language - avoid generic descriptions like "updated code"
4. Focus on the substance and purpose of the changes
5. Write like a natural work-log note, not a marketing or architecture review sentence
6. Combine commits that contribute to the same task or fix into one work item. Account for follow-up changes and reversions when describing the outcome.
7. Choose the number of work items based on the actual work, not the number of commits. Do not return commit hashes or a commit-by-commit list.
8. Cover the substantive work without duplicating items or inventing changes or benefits.
9. Keep ALL work items together within $maxCharacters characters, not words, including spaces, punctuation, bullet prefixes, and line breaks. Prioritize substantive work and write concise, complete sentences.

Return ONLY a JSON object in this format, without Markdown fences:
{"workItems": ["One sentence describing completed work", "Another distinct piece of work"]}
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(
        '$userLanguageReminder\n\n${jsonEncode({
              'project': projectName,
              'commits': diffs
            })}',
      ),
    );

    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [systemMessage, userMessage],
      temperature: 0.5,
      maxTokens: 2048 + diffs.length * 256,
    );

    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final response = await client.createChatCompletion(request: request);
          if (response.choices.isEmpty) {
            throw StateError('AI returned no completion');
          }
          final choice = response.choices.first;
          if (choice.finishReason != ChatCompletionFinishReason.stop) {
            throw StateError(
              'AI summary did not finish: ${choice.finishReason?.name ?? 'unknown'}',
            );
          }
          final content = _sanitizeScalarText(choice.message.content ?? '');
          if (content.isEmpty) {
            throw StateError('AI returned an empty work summary');
          }
          final json = jsonDecode(
            content.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), ''),
          );
          final items = json is Map ? json['workItems'] : null;
          if (items is! List || items.isEmpty) {
            throw StateError('AI returned no work items');
          }
          final result = <String>[];
          for (final item in items) {
            if (item is! String || _sanitizeScalarText(item).isEmpty) {
              throw StateError('AI returned an empty work item');
            }
            result.add(_sanitizeScalarText(item));
          }
          return result;
        } catch (_) {
          if (attempt == 2) rethrow;
          request = request.copyWith(maxTokens: request.maxTokens! * 2);
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
      throw StateError('Work summary generation failed');
    } finally {
      client.endSession();
    }
  }

  static String _formatWorkForAI(Map<String, List<String>> projectWork) {
    final buffer = StringBuffer();

    for (final projectName in projectWork.keys) {
      buffer.writeln('Project: $projectName');
      for (final item in projectWork[projectName]!) {
        buffer.writeln('- $item');
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

  static List<String> _parseDailyPostResponse(String content) {
    try {
      final jsonContent =
          content.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();

      final Map<String, dynamic> jsonData = jsonDecode(jsonContent);

      return _readStringList(jsonData['learnings']);
    } catch (e) {
      return <String>[];
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
