import 'json.dart';

/// A person as Project Management shows them (assignees, team, leader…).
class PmUser {
  const PmUser({required this.id, required this.fullName, this.memberId, this.avatarUrl, this.role});
  final int id;
  final String fullName;
  final String? memberId;
  final String? avatarUrl;

  /// leader | admin | member (department people) or leader | member (project team).
  final String? role;

  factory PmUser.fromJson(Json j) => PmUser(
        id: asIntOr(j['id']),
        fullName: asStr(j['full_name']) ?? '',
        memberId: asStr(j['member_id']),
        avatarUrl: asStr(j['avatar_url']),
        role: asStr(j['role']),
      );

  static PmUser? maybe(Object? j) => j is Map ? PmUser.fromJson(asJson(j)) : null;
}

class PmDepartment {
  const PmDepartment({required this.id, required this.name, this.nameEn});
  final int id;
  final String name;
  final String? nameEn;
  String label(String lang) => lang == 'en' && (nameEn?.isNotEmpty ?? false) ? nameEn! : name;
  factory PmDepartment.fromJson(Json j) => PmDepartment(id: asIntOr(j['id']), name: asStr(j['name']) ?? '', nameEn: asStr(j['name_en']));
}

/// One department on the Project Management home.
class PmDepartmentOverview {
  const PmDepartmentOverview({required this.department, this.total = 0, this.active = 0, this.completed = 0, this.overdue = 0, this.openIssues = 0, this.canManage = false, this.canReports = false, this.canApprove = false, this.canSuggest = false});
  final PmDepartment department;
  final int total, active, completed, overdue, openIssues;
  final bool canManage, canReports, canApprove, canSuggest;

  factory PmDepartmentOverview.fromJson(Json j) {
    final p = asJson(j['projects']);
    final c = asJson(j['can']);
    return PmDepartmentOverview(
      department: PmDepartment.fromJson(asJson(j['department'])),
      total: asIntOr(p['total']),
      active: asIntOr(p['active']),
      completed: asIntOr(p['completed']),
      overdue: asIntOr(p['overdue']),
      openIssues: asIntOr(j['open_issues']),
      canManage: asBool(c['manage']),
      canReports: asBool(c['reports']),
      canApprove: asBool(c['approve']),
      canSuggest: asBool(c['suggest']),
    );
  }
}

class PmOverview {
  const PmOverview({this.departments = const [], this.myOpen = 0, this.myOverdue = 0, this.pendingApprovals = 0});
  final List<PmDepartmentOverview> departments;
  final int myOpen, myOverdue, pendingApprovals;
  factory PmOverview.fromJson(Json j) => PmOverview(
        departments: asJsonList(j['departments']).map(PmDepartmentOverview.fromJson).toList(),
        myOpen: asIntOr(asJson(j['my_tasks'])['open']),
        myOverdue: asIntOr(asJson(j['my_tasks'])['overdue']),
        pendingApprovals: asIntOr(j['pending_approvals']),
      );
}

class PmBudgetSummary {
  const PmBudgetSummary({this.currency = 'ETB', this.proposed, this.approved, this.spent = 0, this.remaining, this.utilization});
  final String currency;
  final double? proposed, approved, remaining, utilization;
  final double spent;
  factory PmBudgetSummary.fromJson(Json j) => PmBudgetSummary(
        currency: asStr(j['currency']) ?? 'ETB',
        proposed: j['proposed'] == null ? null : asDouble(j['proposed']),
        approved: j['approved'] == null ? null : asDouble(j['approved']),
        spent: asDouble(j['spent']),
        remaining: j['remaining'] == null ? null : asDouble(j['remaining']),
        utilization: j['utilization'] == null ? null : asDouble(j['utilization']),
      );
}

class Project {
  const Project({
    required this.id,
    required this.department,
    required this.title,
    this.description,
    this.leader,
    this.startDate,
    this.deadline,
    this.overdue = false,
    this.secondsRemaining,
    this.status = 'planning',
    this.priority = 'medium',
    this.progress = 0,
    this.progressMode = 'tasks',
    this.notes,
    this.allowLateTasks = false,
    this.taskCounts = const {},
    this.openIssues = 0,
    this.budget = const PmBudgetSummary(),
    this.team = const [],
    this.createdBy,
    this.canManage = false,
    this.canManageDepartment = false,
    this.canReportIssue = false,
    this.canBudget = false,
    this.canApprove = false,
    this.canReports = false,
  });

  final int id;
  final PmDepartment department;
  final String title;
  final String? description;
  final PmUser? leader;
  final DateTime? startDate;
  final DateTime? deadline;
  final bool overdue;
  final int? secondsRemaining;
  final String status;
  final String priority;
  final int progress;
  final String progressMode;
  final String? notes;
  final bool allowLateTasks;
  final Map<String, int> taskCounts;
  final int openIssues;
  final PmBudgetSummary budget;
  final List<PmUser> team;
  final PmUser? createdBy;
  final bool canManage, canManageDepartment, canReportIssue, canBudget, canApprove, canReports;

  bool get isOpen => const {'planning', 'not_started', 'in_progress', 'on_hold'}.contains(status);

  factory Project.fromJson(Json j) {
    final c = asJson(j['can']);
    return Project(
      id: asIntOr(j['id']),
      department: PmDepartment.fromJson(asJson(j['department'])),
      title: asStr(j['title']) ?? '',
      description: asStr(j['description']),
      leader: PmUser.maybe(j['leader']),
      startDate: asDate(j['start_date']),
      deadline: asDate(j['deadline']),
      overdue: asBool(j['overdue']),
      secondsRemaining: asInt(j['seconds_remaining']),
      status: asStr(j['status']) ?? 'planning',
      priority: asStr(j['priority']) ?? 'medium',
      progress: asIntOr(j['progress']),
      progressMode: asStr(j['progress_mode']) ?? 'tasks',
      notes: asStr(j['notes']),
      allowLateTasks: asBool(j['allow_late_tasks']),
      taskCounts: asJson(j['tasks']).map((k, v) => MapEntry(k, asIntOr(v))),
      openIssues: asIntOr(j['open_issues']),
      budget: PmBudgetSummary.fromJson(asJson(j['budget'])),
      team: asJsonList(j['team']).map(PmUser.fromJson).toList(),
      createdBy: PmUser.maybe(j['created_by']),
      canManage: asBool(c['manage']),
      canManageDepartment: asBool(c['manage_department']),
      canReportIssue: asBool(c['report_issue']),
      canBudget: asBool(c['budget']),
      canApprove: asBool(c['approve']),
      canReports: asBool(c['reports']),
    );
  }
}

class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    this.projectDeadline,
    required this.departmentId,
    required this.title,
    this.description,
    this.assignees = const [],
    this.startDate,
    this.deadline,
    this.overdue = false,
    this.secondsRemaining,
    this.priority = 'medium',
    this.status = 'not_started',
    this.statusReason,
    this.pendingReason,
    this.progress = 0,
    this.weight = 1,
    this.notes,
    this.programId,
    this.programTitle,
    this.issueId,
    this.issueTitle,
    this.completedAt,
    this.completedBy,
    this.completionNote,
    this.version = 1,
    this.createdBy,
    this.files = 0,
    this.canUpdateStatus = false,
    this.canEdit = false,
  });

  final int id;
  final int projectId;
  final String projectTitle;
  final DateTime? projectDeadline;
  final int departmentId;
  final String title;
  final String? description;
  final List<PmUser> assignees;
  final DateTime? startDate;
  final DateTime? deadline;
  final bool overdue;
  final int? secondsRemaining;
  final String priority;
  final String status;
  final String? statusReason;
  final String? pendingReason;
  final int progress;
  final int weight;
  final String? notes;
  final int? programId;
  final String? programTitle;
  final int? issueId;
  final String? issueTitle;
  final DateTime? completedAt;
  final PmUser? completedBy;
  final String? completionNote;

  /// Server version, sent back with offline changes (conflict detection).
  final int version;
  final PmUser? createdBy;
  final int files;
  final bool canUpdateStatus;
  final bool canEdit;

  static const statuses = ['not_started', 'pending', 'in_progress', 'blocked', 'completed', 'cancelled'];
  static const pendingReasons = ['approval', 'materials', 'finance', 'another_task', 'another_department', 'paused', 'other'];

  bool get isOpen => const {'not_started', 'pending', 'in_progress', 'blocked'}.contains(status);

  ProjectTask copyWith({String? status, String? statusReason, String? pendingReason, int? progress}) => ProjectTask(
        id: id,
        projectId: projectId,
        projectTitle: projectTitle,
        projectDeadline: projectDeadline,
        departmentId: departmentId,
        title: title,
        description: description,
        assignees: assignees,
        startDate: startDate,
        deadline: deadline,
        overdue: overdue,
        secondsRemaining: secondsRemaining,
        priority: priority,
        status: status ?? this.status,
        statusReason: statusReason ?? this.statusReason,
        pendingReason: pendingReason ?? this.pendingReason,
        progress: progress ?? this.progress,
        weight: weight,
        notes: notes,
        programId: programId,
        programTitle: programTitle,
        issueId: issueId,
        issueTitle: issueTitle,
        completedAt: completedAt,
        completedBy: completedBy,
        completionNote: completionNote,
        version: version,
        createdBy: createdBy,
        files: files,
        canUpdateStatus: canUpdateStatus,
        canEdit: canEdit,
      );

  factory ProjectTask.fromJson(Json j) {
    final p = asJson(j['project']);
    final c = asJson(j['can']);
    final prog = asJson(j['program']);
    final issue = asJson(j['issue']);
    return ProjectTask(
      id: asIntOr(j['id']),
      projectId: asIntOr(p['id']),
      projectTitle: asStr(p['title']) ?? '',
      projectDeadline: asDate(p['deadline']),
      departmentId: asIntOr(j['department_id']),
      title: asStr(j['title']) ?? '',
      description: asStr(j['description']),
      assignees: asJsonList(j['assignees']).map(PmUser.fromJson).toList(),
      startDate: asDate(j['start_date']),
      deadline: asDate(j['deadline']),
      overdue: asBool(j['overdue']),
      secondsRemaining: asInt(j['seconds_remaining']),
      priority: asStr(j['priority']) ?? 'medium',
      status: asStr(j['status']) ?? 'not_started',
      statusReason: asStr(j['status_reason']),
      pendingReason: asStr(j['pending_reason']),
      progress: asIntOr(j['progress']),
      weight: asIntOr(j['weight'], 1),
      notes: asStr(j['notes']),
      programId: asInt(prog['id']),
      programTitle: asStr(prog['title']),
      issueId: asInt(issue['id']),
      issueTitle: asStr(issue['title']),
      completedAt: asDate(j['completed_at']),
      completedBy: PmUser.maybe(j['completed_by']),
      completionNote: asStr(j['completion_note']),
      version: asIntOr(j['version'], 1),
      createdBy: PmUser.maybe(j['created_by']),
      files: asIntOr(j['files']),
      canUpdateStatus: asBool(c['update_status']),
      canEdit: asBool(c['edit']),
    );
  }
}

class PmComment {
  const PmComment({required this.id, required this.body, this.user, this.createdAt, this.mine = false});
  final int id;
  final String body;
  final PmUser? user;
  final DateTime? createdAt;
  final bool mine;
  factory PmComment.fromJson(Json j) => PmComment(id: asIntOr(j['id']), body: asStr(j['body']) ?? '', user: PmUser.maybe(j['user']), createdAt: asDate(j['created_at']), mine: asBool(j['mine']));
}

class PmIssue {
  const PmIssue({required this.id, required this.projectId, required this.projectTitle, required this.title, this.description, this.taskId, this.taskTitle, this.priority = 'medium', this.status = 'open', this.reporter, this.assignee, this.dueDate, this.resolution, this.createdAt, this.comments = const []});
  final int id;
  final int projectId;
  final String projectTitle;
  final String title;
  final String? description;
  final int? taskId;
  final String? taskTitle;
  final String priority;
  final String status;
  final PmUser? reporter;
  final PmUser? assignee;
  final DateTime? dueDate;
  final String? resolution;
  final DateTime? createdAt;
  final List<PmComment> comments;

  static const statuses = ['open', 'under_review', 'assigned', 'in_progress', 'resolved', 'closed'];

  factory PmIssue.fromJson(Json j) => PmIssue(
        id: asIntOr(j['id']),
        projectId: asIntOr(asJson(j['project'])['id']),
        projectTitle: asStr(asJson(j['project'])['title']) ?? '',
        title: asStr(j['title']) ?? '',
        description: asStr(j['description']),
        taskId: asInt(j['task_id']),
        taskTitle: asStr(j['task_title']),
        priority: asStr(j['priority']) ?? 'medium',
        status: asStr(j['status']) ?? 'open',
        reporter: PmUser.maybe(j['reporter']),
        assignee: PmUser.maybe(j['assignee']),
        dueDate: asDate(j['due_date']),
        resolution: asStr(j['resolution']),
        createdAt: asDate(j['created_at']),
        comments: asJsonList(j['comment_list']).map(PmComment.fromJson).toList(),
      );
}

class PmSuggestion {
  const PmSuggestion({required this.id, required this.departmentId, this.projectId, this.projectTitle, required this.title, this.body, this.status = 'submitted', this.author, this.reviewNote, this.convertedTaskId, this.createdAt, this.canReview = false, this.comments = const []});
  final int id;
  final int departmentId;
  final int? projectId;
  final String? projectTitle;
  final String title;
  final String? body;
  final String status;
  final PmUser? author;
  final String? reviewNote;
  final int? convertedTaskId;
  final DateTime? createdAt;
  final bool canReview;
  final List<PmComment> comments;
  factory PmSuggestion.fromJson(Json j) => PmSuggestion(
        id: asIntOr(j['id']),
        departmentId: asIntOr(j['department_id']),
        projectId: asInt(asJson(j['project'])['id']),
        projectTitle: asStr(asJson(j['project'])['title']),
        title: asStr(j['title']) ?? '',
        body: asStr(j['body']),
        status: asStr(j['status']) ?? 'submitted',
        author: PmUser.maybe(j['author']),
        reviewNote: asStr(j['review_note']),
        convertedTaskId: asInt(j['converted_task_id']),
        createdAt: asDate(j['created_at']),
        canReview: asBool(j['can_review']),
        comments: asJsonList(j['comment_list']).map(PmComment.fromJson).toList(),
      );
}

class PmExpense {
  const PmExpense({required this.id, required this.projectId, this.projectTitle, this.categoryName, required this.amount, this.currency = 'ETB', required this.description, this.expenseDate, this.requestedBy, this.paidBy, this.receiptUrl, this.status = 'pending', this.overBudget = false, this.reviewNote});
  final int id;
  final int projectId;
  final String? projectTitle;
  final String? categoryName;
  final double amount;
  final String currency;
  final String description;
  final DateTime? expenseDate;
  final PmUser? requestedBy;
  final String? paidBy;
  final String? receiptUrl;
  final String status;
  final bool overBudget;
  final String? reviewNote;
  factory PmExpense.fromJson(Json j) => PmExpense(
        id: asIntOr(j['id']),
        projectId: asIntOr(j['project_id']),
        projectTitle: asStr(j['project_title']),
        categoryName: asStr(asJson(j['category'])['name']),
        amount: asDouble(j['amount']),
        currency: asStr(j['currency']) ?? 'ETB',
        description: asStr(j['description']) ?? '',
        expenseDate: asDate(j['expense_date']),
        requestedBy: PmUser.maybe(j['requested_by']),
        paidBy: asStr(j['paid_by']),
        receiptUrl: asStr(asJson(j['receipt'])['url']),
        status: asStr(j['status']) ?? 'pending',
        overBudget: asBool(j['over_budget']),
        reviewNote: asStr(j['review_note']),
      );
}

class PmBudgetLine {
  const PmBudgetLine({required this.categoryId, required this.categoryName, this.planned, this.spent = 0});
  final int categoryId;
  final String categoryName;
  final double? planned;
  final double spent;
}

class PmAdjustment {
  const PmAdjustment({required this.id, required this.amount, required this.reason, this.status = 'pending', this.requestedBy, this.reviewNote, this.projectId, this.projectTitle, this.currency});
  final int id;
  final double amount;
  final String reason;
  final String status;
  final PmUser? requestedBy;
  final String? reviewNote;
  final int? projectId;
  final String? projectTitle;
  final String? currency;
  factory PmAdjustment.fromJson(Json j) => PmAdjustment(
        id: asIntOr(j['id']),
        amount: asDouble(j['amount']),
        reason: asStr(j['reason']) ?? '',
        status: asStr(j['status']) ?? 'pending',
        requestedBy: PmUser.maybe(j['requested_by']),
        reviewNote: asStr(j['review_note']),
        projectId: asInt(j['project_id']),
        projectTitle: asStr(j['project_title']),
        currency: asStr(j['currency']),
      );
}

class PmBudget {
  const PmBudget({this.currency = 'ETB', this.proposed, this.approved, this.spent = 0, this.pending = 0, this.remaining, this.utilization, this.overBudget = false, this.lines = const [], this.adjustments = const [], this.canEdit = false, this.canApprove = false, this.canSpend = false});
  final String currency;
  final double? proposed, approved, remaining, utilization;
  final double spent, pending;
  final bool overBudget;
  final List<PmBudgetLine> lines;
  final List<PmAdjustment> adjustments;
  final bool canEdit, canApprove, canSpend;
  factory PmBudget.fromJson(Json j) {
    final c = asJson(j['can']);
    return PmBudget(
      currency: asStr(j['currency']) ?? 'ETB',
      proposed: j['proposed'] == null ? null : asDouble(j['proposed']),
      approved: j['approved'] == null ? null : asDouble(j['approved']),
      spent: asDouble(j['spent']),
      pending: asDouble(j['pending']),
      remaining: j['remaining'] == null ? null : asDouble(j['remaining']),
      utilization: j['utilization'] == null ? null : asDouble(j['utilization']),
      overBudget: asBool(j['over_budget']),
      lines: asJsonList(j['lines'])
          .map((l) => PmBudgetLine(
                categoryId: asIntOr(asJson(l['category'])['id']),
                categoryName: asStr(asJson(l['category'])['name']) ?? '',
                planned: l['planned'] == null ? null : asDouble(l['planned']),
                spent: asDouble(l['spent']),
              ))
          .toList(),
      adjustments: asJsonList(j['adjustments']).map(PmAdjustment.fromJson).toList(),
      canEdit: asBool(c['edit']),
      canApprove: asBool(c['approve']),
      canSpend: asBool(c['spend']),
    );
  }
}

class PmFile {
  const PmFile({required this.id, this.name, required this.mime, required this.size, required this.url, this.uploadedBy, this.createdAt, this.taskId});
  final int id;
  final String? name;
  final String mime;
  final int size;
  final String url;
  final PmUser? uploadedBy;
  final DateTime? createdAt;
  final int? taskId;
  factory PmFile.fromJson(Json j) => PmFile(
        id: asIntOr(j['id']),
        name: asStr(j['name']),
        mime: asStr(j['mime']) ?? '',
        size: asIntOr(j['size']),
        url: asStr(j['url']) ?? '',
        uploadedBy: PmUser.maybe(j['uploaded_by']),
        createdAt: asDate(j['created_at']),
        taskId: asInt(j['task_id']),
      );
}

class PmActivity {
  const PmActivity({required this.id, required this.action, this.details = const {}, this.actorName, this.createdAt});
  final int id;
  final String action;
  final Json details;
  final String? actorName;
  final DateTime? createdAt;
  factory PmActivity.fromJson(Json j) => PmActivity(
        id: asIntOr(j['id']),
        action: asStr(j['action']) ?? '',
        details: asJson(j['details']),
        actorName: asStr(asJson(j['actor'])['full_name']),
        createdAt: asDate(j['created_at']),
      );
}

/// Report filters, grouped the way the filter sheet shows them.
class PmReportFilters {
  PmReportFilters({
    this.userIds = const {},
    this.projectStatus = const {},
    this.projectOverdue = false,
    this.taskStatus = const {},
    this.taskPriority = const {},
    this.overdue = false,
    this.period,
    this.from,
    this.to,
    this.dateField = 'deadline',
    this.budgetStatus,
    this.minProgress,
  });
  Set<int> userIds;
  Set<String> projectStatus;
  bool projectOverdue;
  Set<String> taskStatus;
  Set<String> taskPriority;
  bool overdue;
  String? period; // today | week | month | custom
  DateTime? from, to;
  String dateField;
  String? budgetStatus; // within | over | none
  int? minProgress;

  int get count => [
        userIds.isNotEmpty,
        projectStatus.isNotEmpty,
        projectOverdue,
        taskStatus.isNotEmpty,
        taskPriority.isNotEmpty,
        overdue,
        period != null,
        budgetStatus != null,
        minProgress != null,
      ].where((x) => x).length;

  String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQuery() => {
        if (userIds.isNotEmpty) 'user_ids': userIds.join(','),
        if (projectStatus.isNotEmpty) 'project_status': projectStatus.join(','),
        if (projectOverdue) 'project_overdue': 'true',
        if (taskStatus.isNotEmpty) 'task_status': taskStatus.join(','),
        if (taskPriority.isNotEmpty) 'task_priority': taskPriority.join(','),
        if (overdue) 'overdue': 'true',
        'period': ?period,
        if (period == 'custom' && from != null) 'from': _d(from!),
        if (period == 'custom' && to != null) 'to': _d(to!),
        if (period != null) 'date_field': dateField,
        'budget_status': ?budgetStatus,
        if (minProgress != null) 'min_progress': '$minProgress',
      };

  PmReportFilters copy() => PmReportFilters(
        userIds: {...userIds},
        projectStatus: {...projectStatus},
        projectOverdue: projectOverdue,
        taskStatus: {...taskStatus},
        taskPriority: {...taskPriority},
        overdue: overdue,
        period: period,
        from: from,
        to: to,
        dateField: dateField,
        budgetStatus: budgetStatus,
        minProgress: minProgress,
      );
}
