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
  "errorsAndIssues": ["List of bugs fixed, mistakes corrected, or issues encountered from the commits"],
  "nextImportantTasks": ["Identify incomplete work, planned features, or TODO items mentioned in commits"],
  "beneficialWork": ["Summarize meaningful improvements, features added, or value delivered to users/customers"],
  "highlights": ["Identify problems, challenges, or unusual situations. Examples: technical debt discovered, unclear requirements, difficult bugs, blockers, design trade-offs, or industry/technology changes noticed"],
  "learnings": ["Extract knowledge gained and experiments conducted. Examples: new libraries/tools adopted (check commit messages for new dependencies or imports), technical approaches tried (new patterns, architectures), AI/automation tools used, successful experiments, or methodology improvements"]
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

3. "beneficialWork" should summarize the overall impact and value delivered

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
