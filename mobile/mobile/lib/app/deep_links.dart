/// Where a notification about an entity should take the user.
String routeForEntity(String? type, int? id, {String? extra}) {
  if (type == 'sinksar' || type == 'holy_day') {
    if (extra != null && extra.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(extra)) {
      return '/sinksar/$extra';
    }
    return '/sinksar';
  }

  if (id == null) {
    return switch (type) {
      'reminders' => '/programs',
      'program' || 'program_reminder' => '/programs',
      'alarm' || 'program_alarm' => '/programs',
      'attendance' => '/programs',
      'choir' => '/settings/me',
      'payment' || 'receipt' || 'payment_receipt' || 'contribution' => '/settings/payments',
      'sinksar' || 'holy_day' => '/sinksar',
      'edu' || 'education' => '/edu',
      'edu_score' || 'edu_grading' => '/edu/progress',
      'edu_certificate' => '/edu/more',
      'chat' => '/settings',
      'project' => '/projects',
      _ => '/notifications',
    };
  }

  switch (type) {
    // Programs & Alarms
    case 'program':
    case 'program_reminder':
    case 'program_update':
    case 'program_cancellation':
    case 'attendance':
    case 'attendance_request':
    case 'attendance_status':
    case 'attendance_record':
    case 'attendance_session':
      return '/programs/$id';

    case 'alarm':
    case 'program_alarm':
      return '/alarm/$id';

    // Mezmur
    case 'mezmur':
    case 'audio':
    case 'lyrics':
      return '/home/mezmur/$id';
    case 'category':
      return '/home/category/$id';
    case 'page':
    case 'advertisement':
      return '/home/page/$id';

    // Chat & Communications
    case 'chat':
    case 'department':
    case 'message':
      return '/settings/chat/$id';

    // Finance & Contributions
    case 'payment':
    case 'receipt':
    case 'payment_receipt':
    case 'contribution':
      return '/settings/payments';

    // Projects & Tasks
    case 'project':
      return '/projects/$id';
    case 'project_task':
    case 'task':
      return '/projects/tasks/$id';
    case 'project_expense':
      return '/projects/approvals';
    case 'project_suggestion':
      return '/projects/suggestions/$id';

    // Library & Borrowing
    case 'borrowing':
    case 'borrowing_due':
    case 'borrowing_overdue':
      return '/settings/borrowings/$id';
    case 'library_request':
      return '/library-request/$id';

    // Education
    case 'edu_class':
    case 'edu_promotion':
      return '/edu/class/$id';
    case 'edu_lesson':
      return '/edu/learn/lesson/$id';
    case 'edu_quiz':
    case 'edu_submission':
      return '/edu/quiz/$id';
    case 'edu_assignment':
      return '/edu';
    case 'edu_course':
      return '/edu/course/$id?tab=assessments';
    case 'edu_assessment':
      return '/edu/review/assessment/$id';
    case 'edu_grading':
    case 'edu_score':
      return '/edu/progress';
    case 'edu_certificate':
      return '/edu/more';

    // Sinksar & Holy Days
    case 'sinksar':
    case 'holy_day':
      return extra != null && extra.isNotEmpty ? '/sinksar/$extra' : '/sinksar';

    // Account & Administration
    case 'user':
    case 'choir':
      return '/settings/me';
    case 'permission_request':
      return '/admin/permissions';
    case 'property_request':
      return '/admin/property-requests';
    case 'notification':
      return '/notifications';

    default:
      return '/notifications';
  }
}

/// Parse any notification payload (local, push, deep link, typed payload).
/// Supports:
/// - `route:<internalRoute>`
/// - `n:<notificationId>|route:<internalRoute>`
/// - `n:<notificationId>|<type>:<id>`
/// - `n:<notificationId>|sinksar:<date>`
/// - `alarm:<programId>`
/// - `sinksar:<date>` or `sinksar`
/// - `<type>:<id>`
({String route, int? notificationId}) parsePayload(String payload) {
  final trimmed = payload.trim();
  if (trimmed.isEmpty) return (route: '/notifications', notificationId: null);

  // Direct internal route: route:/alarm/12
  if (trimmed.startsWith('route:')) {
    final r = trimmed.substring(6).trim();
    return (route: r.startsWith('/') ? r : '/$r', notificationId: null);
  }

  // Push payload with prefix n:
  if (trimmed.startsWith('n:')) {
    final parts = trimmed.substring(2).split('|');
    final nid = int.tryParse(parts.first);
    if (parts.length <= 1 || parts[1].isEmpty) {
      return (route: '/notifications', notificationId: nid);
    }

    final entityPart = parts[1];
    if (entityPart.startsWith('route:')) {
      final r = entityPart.substring(6).trim();
      return (route: r.startsWith('/') ? r : '/$r', notificationId: nid);
    }

    final entity = entityPart.split(':');
    final type = entity.isNotEmpty ? entity.first : null;
    final id = entity.length > 1 ? int.tryParse(entity[1]) : null;
    final extra = entity.length > 1 && id == null ? entity[1] : (entity.length > 2 ? entity[2] : null);

    return (route: routeForEntity(type, id, extra: extra), notificationId: nid);
  }

  // Program or Reminder Alarm direct payload
  if (trimmed.startsWith('alarm:')) {
    final rest = trimmed.substring(6);
    if (rest.startsWith('reminder:')) {
      final rid = int.tryParse(rest.substring(9));
      return (route: rid != null ? '/alarm/$rid?type=reminder' : '/settings/reminders', notificationId: null);
    }
    final pid = int.tryParse(rest);
    return (route: pid != null ? '/alarm/$pid' : '/programs', notificationId: null);
  }

  // Sinksar direct payload
  if (trimmed.startsWith('sinksar:')) {
    final d = trimmed.substring(8).trim();
    return (route: d.isNotEmpty ? '/sinksar/$d' : '/sinksar', notificationId: null);
  }
  if (trimmed == 'sinksar' || trimmed == 'holy_day') {
    return (route: '/sinksar', notificationId: null);
  }

  // Standard <type>:<id>
  final p = trimmed.split(':');
  final type = p.first;
  final id = p.length > 1 ? int.tryParse(p[1]) : null;
  final extra = p.length > 1 && id == null ? p[1] : (p.length > 2 ? p[2] : null);

  return (route: routeForEntity(type, id, extra: extra), notificationId: null);
}
