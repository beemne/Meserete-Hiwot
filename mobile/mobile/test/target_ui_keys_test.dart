import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/features/guidance/target_ui_keys.dart';

void main() {
  group('TargetUiKeyRegistry Tests', () {
    test('Registry validation passes with zero errors (no duplicates, valid keys)', () {
      final errors = TargetUiKeyRegistry.validate();
      expect(errors, isEmpty, reason: 'Registry validation errors: ${errors.join(', ')}');
    });

    test('Registry contains all major modules: shared, mezmur, education, admin', () {
      final modules = TargetUiKeyRegistry.all.map((k) => k.module).toSet();
      expect(modules, containsAll(['shared', 'mezmur', 'education', 'admin']));
    });

    test('Finding a known key returns complete metadata', () {
      final booksKey = TargetUiKeyRegistry.find('education.home.books.shortcut');
      expect(booksKey, isNotNull);
      expect(booksKey!.nameEn, contains('Books'));
      expect(booksKey.route, equals('/edu'));
      expect(booksKey.module, equals('education'));
      expect(booksKey.elementType, equals(TargetElementType.button));

      final mezmurKey = TargetUiKeyRegistry.find('shared.home.module_selector.mezmur');
      expect(mezmurKey, isNotNull);
      expect(mezmurKey!.module, equals('shared'));
      expect(mezmurKey.elementType, equals(TargetElementType.card));
    });

    test('Search filters correctly by module and text query', () {
      final eduResults = TargetUiKeyRegistry.search('shortcut', module: 'education');
      expect(eduResults, isNotEmpty);
      for (final r in eduResults) {
        expect(r.module, equals('education'));
      }

      final adminResults = TargetUiKeyRegistry.search('attendance', module: 'admin');
      expect(adminResults, isNotEmpty);
      for (final r in adminResults) {
        expect(r.module, equals('admin'));
      }
    });
  });
}
