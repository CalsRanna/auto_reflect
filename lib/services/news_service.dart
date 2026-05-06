import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/file_utils.dart';
import '../utils/logger.dart';

class NewsItem {
  final String title;
  final String summary;
  final List<String> bulletPoints;
  final String? sourceUrl;

  NewsItem({
    required this.title,
    this.summary = '',
    this.bulletPoints = const [],
    this.sourceUrl,
  });
}

class NewsService {
  static const _baseUrl = 'https://news.aibase.com';
  static const _dailyList = '/zh/daily';

  final Logger _logger;

  NewsService({Logger? logger}) : _logger = logger ?? Logger(verbose: false);

  String get _cacheDir {
    final home = FileUtils.getHomeDirectory();
    return FileUtils.joinPath(home, '.auto_reflect/cache');
  }

  /// 获取指定日期的 AI 日报内容。先查缓存，缓存未命中则从 aibase.com 抓取。
  Future<String?> fetchDailyNews(String date) async {
    final cachePath = FileUtils.joinPath(_cacheDir, '$date.md');
    final cacheFile = File(cachePath);

    if (await cacheFile.exists()) {
      _logger.log('Using cached AI news for $date');
      return await cacheFile.readAsString();
    }

    _logger.log('Fetching AI news for $date from AIBase...');
    final dailyId = await _findDailyId(date);
    if (dailyId == null) {
      _logger.log('No AIBase daily found for $date');
      return null;
    }

    final items = await _fetchAndParseDaily(dailyId);
    if (items.isEmpty) {
      _logger.log('No news items extracted from daily $dailyId');
      return null;
    }

    final markdown = _generateMarkdown(date, items);

    await FileUtils.ensureDirectoryExists(_cacheDir);
    await cacheFile.writeAsString(markdown);
    _logger.log('Cached AI news to $cachePath');

    return markdown;
  }

  /// 从日报列表页查找指定日期对应的日报 ID
  Future<int?> _findDailyId(String date) async {
    for (var page = 1; page <= 10; page++) {
      final url = page == 1
          ? '$_baseUrl$_dailyList'
          : '$_baseUrl$_dailyList?page=$page';

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;

        final html = utf8.decode(response.bodyBytes);

        // 页面内嵌 JSON 数据格式: {id},"YYYY-MM-DD HH:MM:SS"
        final idDateRe = RegExp(r'(\d+),"(\d{4}-\d{2}-\d{2})\s');
        for (final match in idDateRe.allMatches(html)) {
          final id = int.parse(match.group(1)!);
          final fullDate = match.group(2)!;
          if (fullDate == date) {
            return id;
          }
        }
      } catch (e) {
        _logger.log('Error fetching daily list page $page: $e');
      }
    }

    return null;
  }

  /// 抓取并解析日报详情页
  Future<List<NewsItem>> _fetchAndParseDaily(int id) async {
    final url = '$_baseUrl$_dailyList/$id';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final html = utf8.decode(response.bodyBytes);

    // 提取 article 内容
    final articleRe = RegExp(r'<article[^>]*>(.*?)</article>', dotAll: true);
    final articleMatch = articleRe.firstMatch(html);
    final articleHtml = articleMatch?.group(1) ?? html;

    // 按 <strong> 标签分割，每个新闻条目以 <strong>N、title</strong> 开头
    final sections = articleHtml.split('<strong>');
    final items = <NewsItem>[];

    for (final section in sections.skip(1)) {
      final titleEnd = section.indexOf('</strong>');
      if (titleEnd == -1) continue;

      var title = _stripHtml(section.substring(0, titleEnd)).trim();
      title = title.replaceAll(RegExp(r'^\d+[、.]\s*'), '');

      if (title.length < 10) continue;

      final rest = section.substring(titleEnd + '</strong>'.length);

      // 提取来源链接
      String? sourceUrl;
      final linkRe = RegExp(r'<a[^>]*href="(https?://[^"]+)"[^>]*>');
      final linkMatch = linkRe.firstMatch(rest);
      if (linkMatch != null) {
        sourceUrl = linkMatch.group(1);
      }

      // 分离 blockquote (AiBase提要) 和正文
      final bqRe = RegExp(r'<blockquote>(.*?)</blockquote>', dotAll: true);
      final bqMatch = bqRe.firstMatch(rest);

      String summary;
      List<String> bullets;

      if (bqMatch != null) {
        summary = _stripHtml(rest.substring(0, bqMatch.start)).trim();

        bullets = [];
        final pRe = RegExp(r'<p>(.*?)</p>', dotAll: true);
        for (final pMatch in pRe.allMatches(bqMatch.group(1)!)) {
          final text = _stripHtml(pMatch.group(1)!).trim();
          if (text.contains('AiBase提要')) continue;
          if (text.isNotEmpty) {
            bullets.add(text);
          }
        }
      } else {
        summary = _stripHtml(rest).trim();
        bullets = [];
      }

      summary = summary.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      if (summary.length > 500) {
        summary = summary.substring(0, 500);
      }

      items.add(NewsItem(
        title: title,
        summary: summary,
        bulletPoints: bullets
            .map((b) => b.replaceFirst(
                RegExp(r'^[^\w\u4e00-\u9fff\u3400-\u4dbf\s]{1,4}\s*'), ''))
            .where((b) => b.isNotEmpty)
            .toList(),
        sourceUrl: sourceUrl,
      ));
    }

    return items;
  }

  /// 简单的 HTML 标签剥离
  String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n')
        .replaceAll(RegExp(r'</div>'), '\n')
        .replaceAll(RegExp(r'</li>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  /// 生成 Markdown 格式的日报
  String _generateMarkdown(String date, List<NewsItem> items) {
    final buf = StringBuffer();
    final now = DateTime.now();
    final ts =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    buf.writeln('# AI/LLM Daily Report -- $date');
    buf.writeln();
    buf.writeln('> Source: AIBase (aibase.com)');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.writeln('## AI 今日要闻');
    buf.writeln();

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      buf.writeln('${i + 1}. **${item.title}**');
      buf.writeln();
      if (item.summary.isNotEmpty) {
        buf.writeln('   ${item.summary}');
        buf.writeln();
      }
      for (final bullet in item.bulletPoints) {
        buf.writeln('   - $bullet');
      }
      if (item.bulletPoints.isNotEmpty) {
        buf.writeln();
      }
      if (item.sourceUrl != null) {
        buf.writeln('   [来源](${item.sourceUrl})');
        buf.writeln();
      }
    }

    buf.writeln('---');
    buf.writeln();
    buf.writeln('*Report generated at $ts*');

    return buf.toString();
  }
}
