import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'budget_screens.dart';
import 'feedback_screens.dart';
import 'project_detail.dart';
import 'projects_home.dart';
import 'reports_screen.dart';
import 'task_detail.dart';

int _id(GoRouterState s, [String name = 'id']) => int.parse(s.pathParameters[name]!);

/// Department Project Management screens (full-screen, above the tab bar).
List<RouteBase> projectRoutes(GlobalKey<NavigatorState> root) => [
      GoRoute(
        path: '/projects',
        parentNavigatorKey: root,
        builder: (_, _) => const ProjectsHomeScreen(),
        routes: [
          GoRoute(path: 'my-tasks', builder: (_, _) => const MyTasksScreen()),
          GoRoute(path: 'approvals', builder: (_, _) => const ProjectApprovalsScreen()),
          GoRoute(path: 'department/:id', builder: (_, s) => DepartmentProjectsScreen(departmentId: _id(s))),
          GoRoute(path: 'department/:id/reports', builder: (_, s) => ProjectReportsScreen(departmentId: _id(s))),
          GoRoute(path: 'tasks/:id', builder: (_, s) => TaskDetailScreen(taskId: _id(s))),
          GoRoute(path: 'issues/:id', builder: (_, s) => IssueDetailScreen(issueId: _id(s))),
          GoRoute(path: 'suggestions/:id', builder: (_, s) => SuggestionDetailScreen(suggestionId: _id(s))),
          GoRoute(path: ':id', builder: (_, s) => ProjectDetailScreen(projectId: _id(s))),
        ],
      ),
    ];
