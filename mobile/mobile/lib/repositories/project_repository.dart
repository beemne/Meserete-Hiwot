import '../core/network/api_client.dart';
import '../models/json.dart';
import '../models/project.dart';

/// Department Project Management (/api/v1/projects). Every rule is enforced by the server; the
/// `can` flags in responses only decide which buttons to show.
class ProjectRepository {
  ProjectRepository(this._api);
  final ApiClient _api;

  Future<PmOverview> overview() => _api.get('/projects/overview', parse: (d) => PmOverview.fromJson(asJson(d)));

  Future<Paged<Project>> projects({int? departmentId, String? status, bool active = false, bool overdue = false, bool mine = false, String? q, int page = 1}) =>
      _api.getPage('/projects', Project.fromJson, page: page, query: {
        'department_id': departmentId,
        'status': status,
        'active': active ? 'true' : null,
        'overdue': overdue ? 'true' : null,
        'mine': mine ? 'true' : null,
        'q': q,
      });

  Future<Project> project(int id) => _api.get('/projects/$id', parse: (d) => Project.fromJson(asJson(d)));
  Future<Project> createProject(Json body) => _api.post('/projects', body: body, parse: (d) => Project.fromJson(asJson(d)));
  Future<Project> updateProject(int id, Json body) => _api.patch('/projects/$id', body: body, parse: (d) => Project.fromJson(asJson(d)));
  Future<void> deleteProject(int id) => _api.delete<void>('/projects/$id');
  Future<Project> setTeam(int id, List<int> userIds) => _api.put('/projects/$id/team', body: {'members': [for (final u in userIds) {'user_id': u}]}, parse: (d) => Project.fromJson(asJson(d)));
  Future<List<PmUser>> people(int departmentId) => _api.get('/projects/departments/$departmentId/people', parse: (d) => asJsonList(d).map(PmUser.fromJson).toList());
  Future<Paged<PmActivity>> activity(int id, {int page = 1}) => _api.getPage('/projects/$id/activity', PmActivity.fromJson, page: page);
  Future<Json> activityDetail(int projectId, int activityId) => _api.get('/projects/$projectId/activity/$activityId', parse: asJson);

  // ---- tasks ----
  Future<Paged<ProjectTask>> tasks(int projectId, {String? status, bool open = false, bool overdue = false, bool mine = false, int page = 1}) =>
      _api.getPage('/projects/$projectId/tasks', ProjectTask.fromJson, page: page, limit: 100, query: {'status': status, 'open': open ? 'true' : null, 'overdue': overdue ? 'true' : null, 'mine': mine ? 'true' : null});
  Future<Paged<ProjectTask>> myTasks({String? status, bool open = false, bool overdue = false, int page = 1}) =>
      _api.getPage('/projects/my-tasks', ProjectTask.fromJson, page: page, query: {'status': status, 'open': open ? 'true' : null, 'overdue': overdue ? 'true' : null});
  Future<ProjectTask> task(int id) => _api.get('/projects/tasks/$id', parse: (d) => ProjectTask.fromJson(asJson(d)));
  Future<ProjectTask> createTask(int projectId, Json body) => _api.post('/projects/$projectId/tasks', body: body, parse: (d) => ProjectTask.fromJson(asJson(d)));
  Future<ProjectTask> updateTask(int id, Json body) => _api.patch('/projects/tasks/$id', body: body, parse: (d) => ProjectTask.fromJson(asJson(d)));
  Future<void> deleteTask(int id) => _api.delete<void>('/projects/tasks/$id');
  Future<ProjectTask> setAssignees(int id, List<int> userIds, {String? reason}) =>
      _api.put('/projects/tasks/$id/assignees', body: {'user_ids': userIds, 'reason': ?reason}, parse: (d) => ProjectTask.fromJson(asJson(d)));
  Future<Json> askStatus(int id) => _api.post('/projects/tasks/$id/ask-status', parse: asJson);
  Future<List<PmComment>> taskComments(int id) => _api.get('/projects/tasks/$id/comments', parse: (d) => asJsonList(d).map(PmComment.fromJson).toList());
  Future<List<PmComment>> addTaskComment(int id, String body) => _api.post('/projects/tasks/$id/comments', body: {'body': body}, parse: (d) => asJsonList(d).map(PmComment.fromJson).toList());

  // ---- issues / suggestions ----
  Future<Paged<PmIssue>> issues({int? projectId, int? departmentId, bool open = false, bool mine = false, int page = 1}) =>
      _api.getPage('/projects/issues', PmIssue.fromJson, page: page, query: {'project_id': projectId, 'department_id': departmentId, 'open': open ? 'true' : null, 'mine': mine ? 'true' : null});
  Future<PmIssue> issue(int id) => _api.get('/projects/issues/$id', parse: (d) => PmIssue.fromJson(asJson(d)));
  Future<PmIssue> createIssue(int projectId, Json body) => _api.post('/projects/$projectId/issues', body: body, parse: (d) => PmIssue.fromJson(asJson(d)));
  Future<PmIssue> updateIssue(int id, Json body) => _api.patch('/projects/issues/$id', body: body, parse: (d) => PmIssue.fromJson(asJson(d)));
  Future<void> addIssueComment(int id, String body) => _api.post<void>('/projects/issues/$id/comments', body: {'body': body});
  Future<Paged<PmSuggestion>> suggestions({int? projectId, int? departmentId, int page = 1}) =>
      _api.getPage('/projects/suggestions', PmSuggestion.fromJson, page: page, query: {'project_id': projectId, 'department_id': departmentId});
  Future<PmSuggestion> suggestion(int id) => _api.get('/projects/suggestions/$id', parse: (d) => PmSuggestion.fromJson(asJson(d)));
  Future<PmSuggestion> createSuggestion(Json body) => _api.post('/projects/suggestions', body: body, parse: (d) => PmSuggestion.fromJson(asJson(d)));
  Future<PmSuggestion> reviewSuggestion(int id, String status, {String? note}) =>
      _api.patch('/projects/suggestions/$id', body: {'status': status, 'note': ?note}, parse: (d) => PmSuggestion.fromJson(asJson(d)));
  Future<Json> convertSuggestion(int id, int projectId, Json task) => _api.post('/projects/suggestions/$id/convert', body: {...task, 'project_id': projectId}, parse: asJson);
  Future<void> addSuggestionComment(int id, String body) => _api.post<void>('/projects/suggestions/$id/comments', body: {'body': body});

  // ---- budget ----
  Future<PmBudget> budget(int projectId) => _api.get('/projects/$projectId/budget', parse: (d) => PmBudget.fromJson(asJson(d)));
  Future<PmBudget> setBudget(int projectId, Json body) => _api.put('/projects/$projectId/budget', body: body, parse: (d) => PmBudget.fromJson(asJson(d)));
  Future<PmBudget> approveBudget(int projectId, double amount, {String? note}) =>
      _api.post('/projects/$projectId/budget/approve', body: {'amount': amount, 'note': ?note}, parse: (d) => PmBudget.fromJson(asJson(d)));
  Future<PmBudget> requestAdjustment(int projectId, double amount, String reason) =>
      _api.post('/projects/$projectId/budget/adjustments', body: {'amount': amount, 'reason': reason}, parse: (d) => PmBudget.fromJson(asJson(d)));
  Future<PmBudget> reviewAdjustment(int id, String status, {String? note}) =>
      _api.patch('/projects/budget/adjustments/$id', body: {'status': status, 'note': ?note}, parse: (d) => PmBudget.fromJson(asJson(d)));
  Future<List<Json>> budgetCategories() => _api.get('/projects/budget-categories', parse: (d) => asJsonList(d));
  Future<Paged<PmExpense>> expenses({int? projectId, String? status, int page = 1}) =>
      _api.getPage('/projects/expenses', PmExpense.fromJson, page: page, query: {'project_id': projectId, 'status': status});

  /// A new expense; [receiptPath] (optional) is uploaded with it.
  Future<PmExpense> createExpense(int projectId, Json fields, {String? receiptPath}) => receiptPath == null
      ? _api.post('/projects/$projectId/expenses', body: fields, parse: (d) => PmExpense.fromJson(asJson(d)))
      : _api.upload('/projects/$projectId/expenses', filePath: receiptPath, fields: fields.map((k, v) => MapEntry(k, '$v')), parse: (d) => PmExpense.fromJson(asJson(d)));
  Future<PmExpense> reviewExpense(int id, String status, {String? note, bool override = false}) =>
      _api.patch('/projects/expenses/$id', body: {'status': status, 'note': ?note, if (override) 'override': true}, parse: (d) => PmExpense.fromJson(asJson(d)));
  Future<Json> approvals() => _api.get('/projects/approvals', parse: asJson);

  // ---- files ----
  Future<List<PmFile>> files(int projectId, {int? taskId}) => _api.get('/projects/$projectId/files', query: {'task_id': taskId}, parse: (d) => asJsonList(d).map(PmFile.fromJson).toList());
  Future<PmFile> uploadFile(int projectId, String path, {int? taskId, int? issueId}) => _api.upload('/projects/$projectId/files', filePath: path, fields: {'task_id': ?taskId, 'issue_id': ?issueId}, parse: (d) => PmFile.fromJson(asJson(d)));
  Future<void> deleteFile(int id) => _api.delete<void>('/projects/files/$id');

  /// A private file (receipt / project file) as bytes (sent with the signed-in user's token).
  Future<List<int>> fileBytes(String url) => _api.bytes(url);

  // ---- reports ----
  Future<Json> report(int departmentId, PmReportFilters f) => _api.get('/projects/reports/summary', query: {'department_id': departmentId, ...f.toQuery()}, parse: asJson);

  // ---- live updates (the change feed) ----
  Future<Json> events({int? after, int? projectId, int? departmentId}) => _api.get('/projects/events', query: {'after': after, 'project_id': projectId, 'department_id': departmentId}, parse: asJson);

  // ---- chat Task Bot buttons ----
  Future<Json> botAction(int departmentId, int messageId, Json body) => _api.post('/chat/$departmentId/messages/$messageId/task-status', body: body, parse: asJson);
}
