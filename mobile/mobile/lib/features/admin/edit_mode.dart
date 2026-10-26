import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart';
import '../auth/session.dart';

/// Admin "Edit mode": while on, the regular screens (home, categories, programs) show ✎ on each
/// item and + buttons, so content can be fixed where it is seen. Off by default; per session.
class EditModeController extends Notifier<bool> {
  @override
  bool build() {
    // Leaving the admin account (sign-out) always turns it off.
    ref.watch(currentUserProvider.select((u) => u?.id));
    return false;
  }

  void toggle() => state = !state;
}

final editModeProvider = NotifierProvider<EditModeController, bool>(EditModeController.new);

/// Admins who can change front-end content for the given [module].
/// For 'mezmur': categoriesManage, mezmursUpdate, mezmursCreate, programsManage.
/// For 'edu': educationContent, educationManage, or teacher role.
bool canEditFront(WidgetRef ref, {String module = 'mezmur'}) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return false;
  if (module == 'edu') {
    return u.canAny([Perm.educationContent, Perm.educationManage]) || u.roles.contains('teacher');
  }
  return u.isAdmin && u.canAny([Perm.categoriesManage, Perm.mezmursUpdate, Perm.mezmursCreate, Perm.programsManage]);
}

/// Edit mode is on and the user can edit this item (checking permission and optional teacher ownership).
bool editingWith(WidgetRef ref, String permission, {bool isTeacherOwner = false}) {
  if (!ref.watch(editModeProvider)) return false;
  final u = ref.watch(currentUserProvider);
  if (u == null) return false;
  if (u.can(permission)) return true;
  if (isTeacherOwner && (u.can(Perm.educationContent) || u.roles.contains('teacher'))) return true;
  return false;
}

/// Toggle button for the screen header (for admins or teachers who can edit content).
class EditModeToggle extends ConsumerWidget {
  const EditModeToggle({super.key, this.module = 'mezmur'});
  final String module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canEditFront(ref, module: module)) return const SizedBox.shrink();
    final on = ref.watch(editModeProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? AppColors.gold : context.palette.pill,
        shape: const CircleBorder(),
        child: IconButton(
          key: ValueKey('edit-mode-toggle-$module'),
          tooltip: context.l10n.editMode,
          icon: Icon(on ? Icons.edit_off_rounded : Icons.edit_rounded, color: on ? Colors.white : AppColors.goldDark, size: 20),
          onPressed: () => ref.read(editModeProvider.notifier).toggle(),
        ),
      ),
    );
  }
}

/// Small strip reminding the admin that edit mode is on.
class EditModeBanner extends ConsumerWidget {
  const EditModeBanner({super.key, this.module = 'mezmur'});
  final String module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(editModeProvider) || !canEditFront(ref, module: module)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.edit_note_rounded, color: AppColors.goldDark),
        const SizedBox(width: 8),
        Expanded(child: Text(context.l10n.editModeOn, style: context.sans(12, weight: FontWeight.w600, color: AppColors.goldDark))),
      ]),
    );
  }
}

/// Puts a ✎ button on [child] while edit mode is on (and the admin holds [permission] or is teacher owner).
class EditOverlay extends ConsumerWidget {
  const EditOverlay({
    super.key,
    required this.child,
    required this.permission,
    this.isTeacherOwner = false,
    required this.onEdit,
    this.top = 6,
    this.right,
    this.left,
    this.bottom,
  });
  final Widget child;
  final String permission;
  final bool isTeacherOwner;
  final Future<void> Function() onEdit;
  final double? top;
  final double? right;
  final double? left;
  final double? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!editingWith(ref, permission, isTeacherOwner: isTeacherOwner)) return child;
    return Stack(children: [
      child,
      Positioned(
        top: top,
        right: right ?? (left == null ? 6 : null),
        left: left,
        bottom: bottom,
        child: Material(
          color: AppColors.gold,
          shape: const CircleBorder(),
          elevation: 3,
          child: IconButton(
            key: const ValueKey('edit-pen-btn'),
            tooltip: context.l10n.edit,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            onPressed: onEdit,
          ),
        ),
      ),
    ]);
  }
}

/// A "+" button (FAB) for edit mode offering the given actions.
class EditModeAddButton extends ConsumerWidget {
  const EditModeAddButton({super.key, required this.actions});
  final List<({String label, IconData icon, String permission, Future<void> Function() run})> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(editModeProvider)) return const SizedBox.shrink();
    final user = ref.watch(currentUserProvider);
    final allowed = actions.where((a) => user?.can(a.permission) ?? false).toList();
    if (allowed.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      heroTag: 'edit-mode-add',
      icon: const Icon(Icons.add_rounded),
      label: Text(context.l10n.addNew),
      onPressed: () async {
        if (allowed.length == 1) return allowed.first.run();
        final pick = await showModalBottomSheet<int>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < allowed.length; i++)
                ListTile(leading: Icon(allowed[i].icon, color: AppColors.gold), title: Text(allowed[i].label), onTap: () => Navigator.pop(ctx, i)),
            ]),
          ),
        );
        if (pick != null) await allowed[pick].run();
      },
    );
  }
}

/// Bumped after every edit made from the front; content screens watch it and reload.
class ContentRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final contentRevisionProvider = NotifierProvider<ContentRevision, int>(ContentRevision.new);

/// Open an admin editor from the front, then refresh the content screens.
Future<void> openAdminEditor(BuildContext context, WidgetRef ref, String location) async {
  await context.push(location);
  ref.read(contentRevisionProvider.notifier).bump();
}
