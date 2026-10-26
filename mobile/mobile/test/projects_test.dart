import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/core/l10n/error_text.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/core/utils/validators.dart';
import 'package:mezmur_zelideta/features/projects/pm_common.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_am.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_en.dart';
import 'package:mezmur_zelideta/models/project.dart';

void main() {
  final am = AppLocalizationsAm();
  final en = AppLocalizationsEn();

  group('PIN', () {
    final v = Validators(en);
    test('4 to 6 digits only — for every account', () {
      expect(Validators.isPin('1234'), isTrue);
      expect(Validators.isPin('12345'), isTrue);
      expect(Validators.isPin('123456'), isTrue);
      expect(Validators.isPin('1234567'), isFalse);
      expect(Validators.isPin('123'), isFalse);
      expect(Validators.isPin('12a4'), isFalse);
      expect(v.pin('1234'), isNull);
      expect(v.pin('123'), en.vInvalidPin);
    });
    test('a new secret is always a PIN (no passwords any more)', () {
      expect(v.pinOrPassword('903172'), isNull);
      expect(v.password('48213'), isNull);
      expect(v.pinOrPassword('Passw0rd123'), en.vInvalidPin);
      expect(v.password('Secret123'), en.vInvalidPin);
    });
    test('server codes are translated', () {
      expect(validationText(am, 'INVALID_PIN'), am.vInvalidPin);
      expect(errorText(am, const ApiException(code: 'TASK_UPDATE_FORBIDDEN')), am.errTaskUpdateForbidden);
    });
  });

  group('Project Management models', () {
    final taskJson = {
      'id': 9,
      'project': {'id': 3, 'title': 'ዓመታዊ ጉባኤ', 'deadline': '2026-12-01T12:00:00Z', 'department_id': 20},
      'department_id': 20,
      'title': 'የጉባኤ ቁሳቁስ',
      'assignees': [
        {'id': 1, 'full_name': 'ዮናስ ታደሰ'},
        {'id': 2, 'full_name': 'ሣራ'},
      ],
      'deadline': '2026-11-20T14:00:00Z',
      'overdue': false,
      'seconds_remaining': 90000,
      'priority': 'high',
      'status': 'pending',
      'status_reason': 'ገንዘብ እየጠበቅን ነው',
      'pending_reason': 'finance',
      'progress': 40,
      'version': 5,
      'program': {'id': 12, 'title': 'ዓመታዊ ጉባኤ 2026'},
      'can': {'update_status': true, 'edit': false},
    };

    test('a task with several responsible people, its reason and program reference', () {
      final t = ProjectTask.fromJson(taskJson);
      expect(t.assignees.map((a) => a.id), [1, 2]);
      expect(t.status, 'pending');
      expect(t.pendingReason, 'finance');
      expect(t.version, 5);
      expect(t.programTitle, 'ዓመታዊ ጉባኤ 2026');
      expect(t.projectDeadline!.toUtc(), DateTime.parse('2026-12-01T12:00:00Z'));
      expect(t.canUpdateStatus, isTrue);
      expect(t.canEdit, isFalse);
      expect(t.isOpen, isTrue);
      expect(pendingReasonLabel(en, t.pendingReason!), en.pmReasonFinance);
      expect(taskStatusLabel(am, 'blocked'), am.pmStBlocked);
    });

    test('a project with budget, counts and permissions', () {
      final p = Project.fromJson({
        'id': 3,
        'department': {'id': 20, 'name': 'ዕቅድ', 'name_en': 'Planning'},
        'title': 'x',
        'status': 'in_progress',
        'progress': 60,
        'tasks': {'total': 10, 'completed': 6, 'overdue': 1},
        'budget': {'currency': 'ETB', 'approved': 100000, 'spent': 65000, 'remaining': 35000, 'utilization': 65},
        'team': [
          {'id': 1, 'full_name': 'a', 'role': 'leader'},
        ],
        'can': {'manage': true, 'manage_department': false, 'report_issue': true, 'budget': true, 'approve': false, 'reports': true},
      });
      expect(p.department.label('en'), 'Planning');
      expect(p.taskCounts['completed'], 6);
      expect(p.budget.remaining, 35000);
      expect(p.budget.utilization, 65);
      expect(p.team.single.role, 'leader');
      expect(p.canManage, isTrue);
      expect(p.canApprove, isFalse);
      expect(p.isOpen, isTrue);
    });

    test('report filters become the categorized query', () {
      final f = PmReportFilters(userIds: {4, 7}, taskStatus: {'pending', 'blocked'}, overdue: true, period: 'custom', from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30), dateField: 'completed', budgetStatus: 'over', minProgress: 50);
      final q = f.toQuery();
      expect(q['user_ids'], '4,7');
      expect(q['task_status'], 'pending,blocked');
      expect(q['overdue'], 'true');
      expect(q['from'], '2026-09-01');
      expect(q['to'], '2026-09-30');
      expect(q['date_field'], 'completed');
      expect(q['budget_status'], 'over');
      expect(q['min_progress'], '50');
      expect(f.count, 6);
      expect(PmReportFilters().toQuery(), isEmpty);
    });

    test('time left / overdue text', () {
      expect(timeLeftText(en, 90000), en.pmTimeLeft('${en.pmDays('1')} ${en.pmHours('1')}'));
      expect(timeLeftText(en, -7200), en.pmOverdueBy(en.pmHours('2')));
      expect(timeLeftText(en, 30), en.pmTimeLeft(en.pmMinutes('1')));
    });

    test('notifications open the right Project Management page', () {
      expect(routeForEntity('project', 3), '/projects/3');
      expect(routeForEntity('project_task', 9), '/projects/tasks/9');
      expect(routeForEntity('project_suggestion', 4), '/projects/suggestions/4');
      expect(routeForEntity('chat', 20), '/settings/chat/20');
    });
  });
}
