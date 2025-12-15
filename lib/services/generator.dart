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
  "beneficialWork": ["What new development techniques or app store policies learned today, and what's good for customers. Focus on: new technical methods/tools discovered, app store policy updates learned, technical details improved, product experiences enhanced, value delivered to users"],
  "highlights": ["Strange, unclear, ridiculous, or most troubling things at work. Examples: technical challenges, unclear requirements, difficult bugs, blockers, design trade-offs, unexpected behaviors, or issues unable to solve"],
  "learnings": ["What learned for future winning, what new tools/methods/AI tools used, what success or experiments had. Examples: new libraries/frameworks adopted, technical approaches tried, AI/automation tools used, successful experiments, development skills improved"]
}

CRITICAL REQUIREMENTS:
1. "learnings" field is MANDATORY - You MUST analyze:
   - New tools/libraries/frameworks introduced (check for new imports, package additions, or tool configurations)
   - Technical methods or patterns applied (architectural changes, refactoring patterns)
   - AI tools or automation adopted (CI/CD, code generation, testing tools)
   - Successful experiments or proof-of-concepts
   - Skills developed through the work
   Example: If commits show "feat: add OpenAI integration", extract "Used OpenAI API for AI-powered analysis"

2. "highlights" field is MANDATORY - You MUST identify:
   - Technical challenges or blockers (difficult bugs, performance issues)
   - Unclear or changing requirements (reverted changes, multiple iterations)
   - Unsolved problems or workarounds (temporary fixes, commented-out code)
   - Interesting edge cases or unexpected behaviors
   - Areas needing improvement or refactoring
   Example: If commits show multiple attempts to fix the same issue, highlight the challenge

3. "beneficialWork" should combine technical learning with customer value:
   - New development techniques or patterns discovered
   - App store policies or platform requirements learned
   - Technical details and product experiences improved
   - Work done beyond normal responsibilities
   - Value and benefits delivered to customers
   Example: "Learned new iOS 17 privacy requirements and updated app accordingly to improve user trust"

General Guidelines:
- Use concise, objective engineer tone
- Base analysis strictly on commit information
- Infer context from commit patterns (e.g., multiple commits on same file = difficult problem)
- Look for keywords: "feat", "fix", "add", "refactor", "optimize", "experiment", "try", "test"
- Even small learnings are valuable (e.g., "learned to handle edge case X")
- DO NOT leave "learnings" or "highlights" empty unless truly no relevant information exists
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

  /// 使用 AI 重写 commit 消息
  ///
  /// 根据 commit 的 diff 内容生成更有意义的 commit 消息
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

You are an expert at writing clear, concise git commit messages following the Conventional Commits specification.

Based on the following git diff, generate a single-line commit message that accurately describes what changed and why.

Follow these rules:
1. Use the format: <type>(<scope>): <subject>
2. Types: feat, fix, refactor, style, test, docs, chore, perf
3. Keep the subject line under 72 characters
4. Use imperative mood ("add" not "added" or "adds")
5. Don't capitalize the first letter of the subject
6. No period at the end
7. Be specific and descriptive about what actually changed

Git Diff:
$diff

Return ONLY the commit message, nothing else.
''';

    var systemMessage = ChatCompletionMessage.system(content: prompt);
    var userMessage = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(diff),
    );

    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(config.model),
      messages: [systemMessage, userMessage],
      temperature: 0.5,
      maxTokens: 100,
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
