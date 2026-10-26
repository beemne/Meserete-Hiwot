import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/app/router.dart' show forcedPinRedirect;
import 'package:mezmur_zelideta/core/l10n/error_text.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/core/utils/share_links.dart';
import 'package:mezmur_zelideta/features/admin/notification_admin.dart' show deliveryLabel;
import 'package:mezmur_zelideta/features/members/profile_changes.dart' show profileFieldLabel;
import 'package:mezmur_zelideta/features/settings/notification_settings_screen.dart' show notificationTopicLabel;
import 'package:mezmur_zelideta/l10n/app_localizations.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  group('registration shows the exact fields, not a general message', () {
    test('every rejected field is listed with its label and reason', () {
      const e = ApiException(code: 'VALIDATION_ERROR', status: 422, fieldErrors: {'profile.birth_date': 'INVALID_DATE', 'email': 'INVALID_EMAIL'});
      final s = fieldErrorsSummary(l, e, (f) => profileFieldLabel(l, f.startsWith('profile.') ? f.substring(8) : f))!;
      final lines = s.split('\n');
      expect(lines, hasLength(2));
      expect(lines[0], startsWith(profileFieldLabel(l, 'birth_date')));
      expect(lines[1], startsWith(l.email));
      expect(s, isNot(contains(l.errorValidation)));
    });

    test('no field errors → null (the general message is used)', () {
      expect(fieldErrorsSummary(l, const ApiException(code: 'NETWORK_ERROR'), (f) => f), isNull);
    });
  });

  group('deep links', () {
    test('shared links use the host that serves the landing pages', () {
      expect(shareUrl('p', 7), 'https://app.hersolan.pro/p/7');
    });

    test('email / notification links open the same screens as push taps', () {
      expect(routeForEntity('project_task', 4), '/projects/tasks/4');
      expect(routeForEntity('borrowing', 9), '/settings/borrowings/9');
      expect(routeForEntity('user', 3), '/settings/me');
      expect(routeForEntity('department', 2), '/settings/chat/2');
      expect(routeForEntity('notification', 0), '/notifications');
    });
  });

  group('labels', () {
    test('delivery states and topics', () {
      expect(deliveryLabel(l, 'sent'), l.deliverySent);
      expect(deliveryLabel(l, 'skipped'), l.deliverySkipped);
      expect(deliveryLabel(l, null), l.deliveryNone);
      expect(notificationTopicLabel(l, 'property'), l.topicProperty);
      expect(notificationTopicLabel(l, 'unknown'), l.topicSystem);
    });
  });

  group('forced PIN change', () {
    test('stays on the change page instead of looping to the hub', () {
      expect(forcedPinRedirect('/change-password'), isNull);
      expect(forcedPinRedirect('/hub'), '/change-password');
      expect(forcedPinRedirect('/splash'), '/change-password');
      expect(forcedPinRedirect('/admin'), '/change-password');
    });
  });
}
