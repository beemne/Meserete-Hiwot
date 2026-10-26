import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../core/member_groups.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../features/player/mini_player.dart';
import '../widgets/brand.dart';
import '../widgets/states.dart';
import 'chrome.dart';

/// The app frame used everywhere after sign-in: the shared top bar (logo, search, notifications,
/// theme) and module-specific bottom navigation bars for Education and Mezmur.
/// The global Hub has no persistent bottom navigation bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell, required this.location});

  final StatefulNavigationShell shell;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Last place visited in the Home tab (kept while another tab is open).
  String _homeLocation = '/hub';

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    if (shell.currentIndex == 0) _homeLocation = widget.location;
    final section = homeSectionOf(_homeLocation);
    final online = ref.watch(isOnlineProvider);

    // Member types (with administrator-created ones) for labels and pickers across the app.
    ref.watch(memberGroupsProvider);

    final p = context.palette;
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // While typing, the bottom bar and mini player would sit on top of the keyboard — hide both.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    // The Mezmur section has its own 5 tabs; ትምህርት has its own 5 tabs; the hub has no bottom bar.
    final nav = NavLayout(
      section: section,
      branch: shell.currentIndex,
      location: widget.location,
    );
    final onHomePage = !nav.showsBottomBar;
    final mezmur = nav.hasCategories;
    final homeLabel = switch (section) {
      HomeSection.education => l.hubEducation,
      HomeSection.mezmur => l.hubMezmur,
      HomeSection.hub => l.navHome,
    };

    final currentPath = GoRouterState.of(context).uri.path;
    final atHubRoot = shell.currentIndex == 0 && currentPath == '/hub';
    return PopScope(
      canPop: atHubRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final loc = GoRouterState.of(context).uri.path;

        // If the user is on another shell branch, return to Home branch.
        if (shell.currentIndex != 0) {
          shell.goBranch(0);
        } else if (NavLayout.eduTabs.skip(1).contains(loc) ||
            (loc.startsWith('/edu') && loc != '/edu')) {
          // A subpage of Education goes back to Education home first.
          context.go('/edu');
        } else if (loc.startsWith('/home') &&
            loc != '/home') {
          // A subpage of Mezmur goes back to Mezmur home first.
          context.go('/home');
        } else if (loc != '/hub') {
          // If inside a module home, return to the module selector hub.
          context.go('/hub');
        }
      },
      child: Scaffold(
        // Pages inside the shell have their own Scaffold and
        // handle keyboard insets themselves.
        resizeToAvoidBottomInset: false,

        body: Column(
          children: [
            // Shared application top bar.
            SafeArea(bottom: false, child: AppTopBar(section: section)),

            // Offline status banner.
            if (!online) const OfflineBanner(),

            // Current shell page with inherited module background styling.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ModuleBackgroundWrapper(
                  kind: moduleKindFor(widget.location, section),
                  child: shell,
                ),
              ),
            ),

            // Mini player, hidden while the keyboard is open.
            if (!typing) const MiniPlayer(),
          ],
        ),

        // Module-specific bottom navigation bar:
        // Rendered for Education and Mezmur, but strictly hidden on the global Hub.
        bottomNavigationBar: typing || onHomePage
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: nav.isEducation
                          ? (isDark
                                ? AppColors.eduGold.withValues(alpha: 0.25)
                                : AppColors.eduGold.withValues(alpha: 0.35))
                          : p.border,
                    ),
                  ),
                ),
                child: NavigationBarTheme(
                  data: nav.isEducation
                      ? NavigationBarThemeData(
                          backgroundColor: isDark
                              ? const Color(0xFF241A1C)
                              : AppColors.eduCream,
                          indicatorColor: AppColors.eduGold.withValues(
                            alpha: 0.24,
                          ),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return IconThemeData(
                                color: isDark
                                    ? AppColors.eduGoldLight
                                    : AppColors.eduBurgundy,
                              );
                            }
                            return IconThemeData(
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.eduBurgundy.withValues(
                                      alpha: 0.55,
                                    ),
                            );
                          }),
                          labelTextStyle: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.eduGoldLight
                                    : AppColors.eduBurgundy,
                              );
                            }
                            return TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.eduBurgundy.withValues(
                                      alpha: 0.55,
                                    ),
                            );
                          }),
                        )
                      : Theme.of(context).navigationBarTheme,
                  child: NavigationBar(
                    selectedIndex: nav.selectedIndex,
                    onDestinationSelected: (i) {
                      final b = nav.branchFor(i);
                      if (b == null) {
                        context.go(nav.routeFor(i)!);
                        return;
                      }
                      shell.goBranch(
                        b,
                        initialLocation: b == shell.currentIndex,
                      );
                    },
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    indicatorColor: nav.isEducation
                        ? AppColors.eduGold.withValues(alpha: 0.24)
                        : AppColors.gold.withValues(alpha: 0.22),
                    destinations: nav.isEducation
                        // ትምህርት: Learn · Books · Progress · Settings.
                        ? [
                            NavigationDestination(
                              key: const ValueKey('edu-tab-learn'),
                              icon: const Icon(Icons.auto_stories_outlined),
                              selectedIcon: const Icon(
                                Icons.auto_stories_rounded,
                              ),
                              label: l.elTabLearn,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-books'),
                              icon: const Icon(Icons.menu_book_outlined),
                              selectedIcon: const Icon(Icons.menu_book_rounded),
                              label: l.libBooks,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-progress'),
                              icon: const Icon(Icons.insights_outlined),
                              selectedIcon: const Icon(Icons.insights_rounded),
                              label: l.elTabProgress,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-settings'),
                              icon: const Icon(Icons.settings_outlined),
                              selectedIcon: const Icon(Icons.settings_rounded),
                              label: l.navSettings,
                            ),
                          ]
                        : [
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-home'),
                              icon: HomeTabIcon(section: section),
                              selectedIcon: HomeTabIcon(
                                section: section,
                                selected: true,
                              ),
                              label: homeLabel,
                            ),
                            if (mezmur)
                              NavigationDestination(
                                key: const ValueKey('mezmur-tab-categories'),
                                icon: const Icon(Icons.grid_view_outlined),
                                selectedIcon: const Icon(
                                  Icons.grid_view_rounded,
                                ),
                                label: l.categories,
                              ),
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-library'),
                              icon: const Icon(Icons.local_library_outlined),
                              selectedIcon: const Icon(
                                Icons.local_library_rounded,
                              ),
                              label: l.navLibrary,
                            ),
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-programs'),
                              icon: const Icon(Icons.event_note_outlined),
                              selectedIcon: const Icon(
                                Icons.event_note_rounded,
                              ),
                              label: l.navPrograms,
                            ),
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-settings'),
                              icon: const Icon(Icons.settings_outlined),
                              selectedIcon: const Icon(Icons.settings_rounded),
                              label: l.navSettings,
                            ),
                          ],
                  ),
                ),
              ),
      ),
    );
  }
}
