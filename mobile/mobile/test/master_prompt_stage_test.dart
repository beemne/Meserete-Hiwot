import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/features/edu/edu_screens.dart' show eduScheduleDayText;
import 'package:mezmur_zelideta/features/mezmurs/youtube_view.dart' show youtubeIdOf;
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/widgets/file_preview.dart' show fileKindOf;

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('file previews', () {
    test('the kind comes from the MIME type or the extension', () {
      expect(fileKindOf('a.JPG', null), 'image');
      expect(fileKindOf('scan', 'application/pdf'), 'pdf');
      expect(fileKindOf('voice.m4a', null), 'audio');
      expect(fileKindOf('clip', 'video/mp4'), 'video');
      expect(fileKindOf('notes.csv', null), 'text');
      expect(fileKindOf('song.lrc', 'text/plain'), 'lrc');
      expect(fileKindOf('archive.zip', 'application/zip'), 'other');
    });
  });

  group('Mezmurs: in-app YouTube and the category queue', () {
    test('YouTube links give a video id; other links do not', () {
      expect(youtubeIdOf('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(youtubeIdOf('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(youtubeIdOf(''), isNull);
      expect(youtubeIdOf(null), isNull);
    });

    test('a Mezmur carries its category queue from the server', () {
      final m = Mezmur.fromJson({
        'id': 1,
        'title': 'ሀ',
        'queue': [
          {'id': 1, 'title': 'ሀ'},
          {'id': 2, 'title': 'ለ'},
        ],
      });
      expect(m.queue.map((x) => x.id), [1, 2]);
    });
  });

  group('course schedules and contributions wording', () {
    test('weekly and monthly schedule days', () {
      expect(eduScheduleDayText(en, {'weekday': 6}), en.weekday6);
      expect(eduScheduleDayText(en, {'weekday': 7, 'frequency': 'monthly', 'week_of_month': 5}), '${en.eduWeekLast} ${en.weekday7} of the month');
    });

    test('yearly contribution summary', () {
      expect(en.paymentsYearPartial('2018', '7', '5'), '2018 Ethiopian Year\nPaid: 7 months\nUnpaid: 5 months');
      expect(en.paymentsYearFull('2018'), contains('✓ All months paid'));
      expect(en.monthlyPayments, 'Monthly Contributions');
    });
  });
}
