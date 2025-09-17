import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';
import '../models/config.dart';
import '../models/git_commit.dart';
import '../models/ai_analysis.dart';

class Generator {
  static Future<AIAnalysisResult> analyzeCommits(
    Map<String, List<GitCommit>> projectCommits, {
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

    var commitsText = _formatCommitsForAI(projectCommits);

    var prompt = '''
You are a professional software development consultant who specializes in analyzing code commit records and providing valuable work advice.

Based on the following Git commit records, conduct a work summary analysis. Write like an engineer taking technical notes, using concise and objective tone, avoiding exaggeration and self-praise.

$commitsText

Please return the analysis results in the following JSON format. If there is no relevant content for a certain aspect, use an empty array:

{
  "errorsAndIssues": ["List of small mistakes or failures I made today or in the past few days"],
  "nextImportantTasks": ["List of the most important or difficult tasks for the next working day"],
  "beneficialWork": ["List of what things I did today are good for customers or industry"],
  "highlights": ["List of things at work or in the industry that are strange, unclear, ridiculous, most troubling, or oddly changed since last month? Or issues I'm unable to solve today"],
  "learnings": ["List of what did I learn for the purpose of future winning, what new tools, methods, or AI tools did I use, and what success or new experiments did I have"]
}

Requirements:
- Use concise, objective engineer tone
- Avoid self-praise and exaggerated language
- Summarize based only on actual commit information
- Be realistic for each aspect, use empty array [] if none
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
}
