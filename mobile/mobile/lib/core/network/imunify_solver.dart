import 'dart:convert';
import 'dart:io';

/// Automated resolver for Imunify360 WebShield Anti-Bot challenge.
///
/// When a mobile IP is placed into the challenge pool by OpenResty / Imunify360 WebShield,
/// all API requests receive HTTP 403 ("Access denied by Imunify360 bot-protection") unless
/// the client completes the splash arithmetic challenge and sends the `wssplashchk` cookie.
class ImunifySolver {
  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  static int decodeJsFuckNumber(String expr) {
    final groupRegex = RegExp(r'\(([^)]+)\)');
    final digits = StringBuffer();
    for (final match in groupRegex.allMatches(expr)) {
      final inner = match.group(1)!;
      if (inner.contains('+![]') && !inner.contains('!+[]') && !inner.contains('!![]')) {
        digits.write('0');
      } else {
        final count = RegExp(r'!\+\[\]|!!\[\]').allMatches(inner).length;
        if (count > 0) {
          digits.write(count);
        }
      }
    }
    return int.tryParse(digits.toString()) ?? 0;
  }

  /// Solves the WebShield splash challenge and returns the `wssplashchk=...` cookie string.
  static Future<String?> solve(String baseUrl, {String userAgent = defaultUserAgent}) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      // Step 1: GET splash HTML page
      final challengePageUri = Uri.parse('$baseUrl/api/v1/auth/me');
      final req = await client.getUrl(challengePageUri);
      req.headers.set('User-Agent', userAgent);
      req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();

      if (!body.contains('wsidchk') && !body.contains('One moment, please...')) {
        return null;
      }

      final scripts = RegExp(r'<script>([\s\S]*?)<\/script>').allMatches(body).toList();
      if (scripts.isEmpty) return null;
      final s = scripts.last.group(1)!;

      final eExprMatch = RegExp(r'e=\+\(([\s\S]*?)\),\s*\w+=').firstMatch(s);
      final lExprMatch = RegExp(r'L=\+\(([\s\S]*?)\),\s*\w+=').firstMatch(s);
      final oMatch = RegExp(r"o='(\/[^']+)'").firstMatch(s);
      final tsMatch = RegExp(r"'ts'[^\d]+(\d+)").firstMatch(s);
      final kMatch = RegExp(r"K='([^']+)'").firstMatch(s);

      if (eExprMatch == null || lExprMatch == null || oMatch == null || tsMatch == null) {
        return null;
      }

      final e = decodeJsFuckNumber(eExprMatch.group(1)!);
      final l = decodeJsFuckNumber(lExprMatch.group(1)!);
      final wsidchk = e + l;
      final o = oMatch.group(1)!;
      final ts = tsMatch.group(1)!;
      final k = kMatch?.group(1) ?? Uri.encodeComponent(challengePageUri.toString());

      // Extract ID: prefix (10 hex) + hex10_part2 + hex10_part1 + suffix
      final a0dMatch = RegExp(r'function a0d\(\)\{[\s\S]*?var \w+=\[([\s\S]*?)\];').firstMatch(s);
      final a0dContent = a0dMatch?.group(1) ?? '';
      final hex10Matches = RegExp(r"'([a-f0-9]{10})'").allMatches(a0dContent).map((m) => m.group(1)!).toList();

      final valMatch = RegExp(r"r\['value'\]='([a-f0-9]+)'\+[\s\S]*?'([a-f0-9]+)'").firstMatch(s);
      final prefix = valMatch?.group(1) ?? '7fa3b767c4';
      final suffix = valMatch?.group(2) ?? 'c7';

      String id;
      if (hex10Matches.length >= 2) {
        id = '$prefix${hex10Matches[1]}${hex10Matches[0]}$suffix';
      } else {
        id = '${prefix}60b54a2be4d49030b349$suffix';
      }

      // Step 2: Submit verification GET request
      final verifyUrl = '$baseUrl$o?wsidchk=$wsidchk&pdata=$k&id=$id&ts=$ts&cttl=0';
      final cReq = await client.getUrl(Uri.parse(verifyUrl));
      cReq.headers.set('User-Agent', userAgent);
      cReq.followRedirects = false;
      final cRes = await cReq.close();

      final rawCookies = cRes.headers['set-cookie'] ?? [];
      for (final sc in rawCookies) {
        if (sc.contains('wssplashchk=')) {
          return sc.split(';').first.trim();
        }
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
