import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';

/// Web links that open the exact page in the app (Android App Links / "open in app" landing page):
/// m = Mezmur, p = program, c = category, pg = page.
String shareUrl(String kind, int id) => '${Uri.parse(AppConfig.apiBaseUrl).origin}/$kind/$id';

/// The system share sheet — it lists recent chats (direct share) and every chat app.
Future<void> shareLink({required String kind, required int id, required String title, String? text}) {
  final url = shareUrl(kind, id);
  final body = [title, if (text != null && text.trim().isNotEmpty) text.trim(), url].join('\n\n');
  return SharePlus.instance.share(ShareParams(text: body, subject: title));
}
