import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/utils/share_links.dart';
import 'package:mezmur_zelideta/features/admin/drafts.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('share links point at the server that serves the landing pages (and the app claims that host)', () {
    expect(shareUrl('m', 12), 'https://app.hersolan.pro/m/12');
    expect(shareUrl('pg', 3), 'https://app.hersolan.pro/pg/3');
  });

  test('banners parse their files and links', () {
    final b = Banner.fromJson({
      'id': 1,
      'title': 'ሠርግ',
      'target': {'type': 'program', 'id': 4},
      'attachments': [
        {'id': 7, 'kind': 'file', 'title': 'ፕሮግራም', 'url': 'https://x/files/a.pdf', 'mime': 'application/pdf'},
        {'id': 8, 'kind': 'link', 'url': 'https://maps.example.com'},
      ],
    });
    expect(b.attachments, hasLength(2));
    expect(b.attachments.first.isPdf, isTrue);
    expect(b.attachments.last.kind, 'link');
    expect(Banner.fromJson({'id': 2, 'title': 'x'}).attachments, isEmpty);
  });

  test('drafts keep unsaved changes and drop them once saved', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await LocalPrefs.load();
    final d = DraftKeeper(prefs, 'mezmur:5')..setBaseline({'title': 'ሀ'});
    d.changed({'title': 'ሀለ'});
    d.flush();
    expect(prefs.draft('mezmur:5'), isNotNull);

    final again = DraftKeeper(prefs, 'mezmur:5')..setBaseline({'title': 'ሀ'});
    expect(again.pending(), {'title': 'ሀለ'});

    await again.clear(baseline: {'title': 'ሀለ'});
    expect(prefs.draft('mezmur:5'), isNull);

    // A draft equal to the saved version is not kept.
    final same = DraftKeeper(prefs, 'mezmur:6')..setBaseline({'title': 'x'});
    same.changed({'title': 'x'});
    same.flush();
    expect(prefs.draft('mezmur:6'), isNull);
  });
}
