import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session.dart';
import 'tour_engine.dart';

/// Centralized guide-to-destination navigation engine.
/// Handles role/permission validation, multi-step navigation, context passing,
/// informative feedback for restricted/unavailable routes, and safe back navigation.
class GuidanceNavigator {
  GuidanceNavigator._();

  /// Map of known guide targets with human-friendly title and permitted fallback.
  static const Map<String, ({String title, String? requiredPermission, String fallbackRoute, String fallbackTitle})>
      destinationRegistry = {
    // Member / Public destinations
    '/hub': (
      title: 'የመተግበሪያው ማዕከል (Hub)',
      requiredPermission: null,
      fallbackRoute: '/login',
      fallbackTitle: 'መግቢያ ገጽ (Sign In)',
    ),
    '/home': (
      title: 'መዝሙራት እና ድምጽ (Mezmurs)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/home/categories': (
      title: 'የመዝሙር ምድቦች (Categories)',
      requiredPermission: null,
      fallbackRoute: '/home',
      fallbackTitle: 'መዝሙራት (Mezmurs)',
    ),
    '/home/search': (
      title: 'መዝሙር መፈለጊያ (Search Mezmurs)',
      requiredPermission: null,
      fallbackRoute: '/home',
      fallbackTitle: 'መዝሙራት (Mezmurs)',
    ),
    '/edu': (
      title: 'ትምህርት (Education Home)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/edu/services': (
      title: 'ጥያቄዎች፣ ቅሬታዎች እና የትምህርት ጉዞ (Requests & Complaints)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ማዕከል (Education)',
    ),
    '/edu/review': (
      title: 'የትምህርት ግምገማ ማዕከል (Education Review Center)',
      requiredPermission: 'education.manage',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ማዕከል (Education)',
    ),
    '/edu/courses': (
      title: 'የትምህርት ኮርሶች (Courses)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ማዕከል (Education)',
    ),
    '/edu/library': (
      title: 'የትምህርት መጻሕፍት (Edu Library)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ማዕከል (Education)',
    ),
    '/edu/registrations': (
      title: 'የተማሪዎች ምዝገባ (Registrations)',
      requiredPermission: 'education.register',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/manage': (
      title: 'የትምህርት አስተዳደር (Manage Classes)',
      requiredPermission: 'education.manage',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/programs': (
      title: 'መርሐ ግብሮች እና ማንቂያ (Programs & Alarms)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/attendance': (
      title: 'የክትትል የቀን መቁጠሪያ (Attendance Calendar)',
      requiredPermission: null,
      fallbackRoute: '/settings/me',
      fallbackTitle: 'የአባልነት መረጃ (My Data)',
    ),
    '/library': (
      title: 'የእኔ መዝሙራት (የተወደዱ እና የወረዱ) (My Mezmurs: Favorites & Downloads)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/projects': (
      title: 'የመምሪያ ፕሮጀክቶች (Projects & Tasks)',
      requiredPermission: 'projects.view',
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/choir': (
      title: 'የመዘምራን መረጣ (Choir Selection)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/notifications': (
      title: 'ማሳወቂያዎች (Notifications)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/settings': (
      title: 'ቅንብሮች (Settings)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/settings/me': (
      title: 'የአባልነት ካርድ እና QR (Member ID Card)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/settings/profile': (
      title: 'መገለጫ እና ሙያ (Profile & Profession)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/settings/payments': (
      title: 'ክፍያዎች እና መዋጮዎች (Payments)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/settings/notifications': (
      title: 'የማሳወቂያ ቅንብሮች (Notification Settings)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/settings/sessions': (
      title: 'የገቡባቸው ስልኮች (Active Sessions)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/settings/guidance': (
      title: 'የመመሪያ ማዕከል (Guidance Center)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/guidance': (
      title: 'የመመሪያ ማዕከል (Guidance Center)',
      requiredPermission: null,
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/chat': (
      title: 'መልዕክቶች እና ውይይት (Chat)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),

    // Administrative destinations
    '/admin': (
      title: 'የአስተዳዳሪ ዳሽቦርድ (Admin Dashboard)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/admin/users': (
      title: 'የአባላት አስተዳደር (Manage Users)',
      requiredPermission: 'users.view',
      fallbackRoute: '/settings/me',
      fallbackTitle: 'የግል መረጃ (My Data)',
    ),
    '/admin/member-ids': (
      title: 'የመታወቂያ ቅርጸት (Member ID Format)',
      requiredPermission: 'member_id.configure',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/member-groups': (
      title: 'የአባላት ቡድኖች (Member Groups)',
      requiredPermission: 'member_groups.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/change-requests': (
      title: 'የመረጃ ለውጥ ጥያቄዎች (Change Requests)',
      requiredPermission: 'users.update',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/payments': (
      title: 'የክፍያዎች አስተዳደር (Payments Admin)',
      requiredPermission: 'payments.view',
      fallbackRoute: '/settings/payments',
      fallbackTitle: 'የእኔ ክፍያዎች (Payments)',
    ),
    '/admin/programs': (
      title: 'መርሐ ግብር እና አቴንዳንስ መዝጋት (Programs Admin)',
      requiredPermission: 'programs.manage',
      fallbackRoute: '/programs',
      fallbackTitle: 'የመርሐ ግብር ዝርዝር (Programs)',
    ),
    '/admin/attendance': (
      title: 'አቴንዳንስ መቆጣጠሪያ (Attendance Admin)',
      requiredPermission: 'attendance.view',
      fallbackRoute: '/attendance',
      fallbackTitle: 'የግል አቴንዳንስ (My Attendance)',
    ),
    '/admin/attendance/rules': (
      title: 'የአቴንዳንስ ደንቦች እና ነጥብ (Attendance Rules & Scoring)',
      requiredPermission: 'attendance.configure',
      fallbackRoute: '/admin/attendance',
      fallbackTitle: 'አቴንዳንስ መቆጣጠሪያ (Attendance)',
    ),
    '/admin/attendance/corrections': (
      title: 'የአቴንዳንስ ማስተካከያ ጥያቄዎች (Attendance Corrections)',
      requiredPermission: 'attendance.correction.approve',
      fallbackRoute: '/admin/attendance',
      fallbackTitle: 'አቴንዳንስ መቆጣጠሪያ (Attendance)',
    ),
    '/admin/permissions': (
      title: 'የፈቃድ ጥያቄዎች (Absence Requests)',
      requiredPermission: 'attendance.view',
      fallbackRoute: '/admin/attendance',
      fallbackTitle: 'አቴንዳንስ መቆጣጠሪያ (Attendance)',
    ),
    '/admin/fines': (
      title: 'የቅጣቶች አስተዳደር (Fines & Penalties)',
      requiredPermission: 'fines.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/notify': (
      title: 'ማሳወቂያ መላኪያ (Broadcast Notifications)',
      requiredPermission: 'notifications.send',
      fallbackRoute: '/notifications',
      fallbackTitle: 'ማሳወቂያዎች (Notifications)',
    ),
    '/admin/notification-health': (
      title: 'የማሳወቂያ ጤና (Notification Health)',
      requiredPermission: 'notifications.send',
      fallbackRoute: '/admin/notify',
      fallbackTitle: 'ማሳወቂያ መላኪያ (Notify)',
    ),
    '/admin/departments': (
      title: 'የክፍላት አስተዳደር (Departments Admin)',
      requiredPermission: 'departments.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/chat': (
      title: 'የክፍላት ውይይት (Department Chat)',
      requiredPermission: 'chat.supervise',
      fallbackRoute: '/settings/chat',
      fallbackTitle: 'ውይይት (Chat)',
    ),
    '/admin/items': (
      title: 'የንብረት እና መጻሕፍት አስተዳደር (Items & Inventory)',
      requiredPermission: 'items.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/borrowings': (
      title: 'የውሰት አስተዳደር (Borrowings Admin)',
      requiredPermission: 'borrowing.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/property-requests': (
      title: 'የንብረት ጥያቄዎች (Property Requests)',
      requiredPermission: 'property.review',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/library-requests': (
      title: 'የመጻሕፍት መጠየቂያዎች (Library Requests)',
      requiredPermission: 'borrowing.manage',
      fallbackRoute: '/edu/library',
      fallbackTitle: 'ቤተ-መጽሐፍት (Library)',
    ),
    '/admin/selections': (
      title: 'የበዓላት መዘምራን መረጣ አስተዳደር (Choir Selections Admin)',
      requiredPermission: 'selection.view',
      fallbackRoute: '/choir',
      fallbackTitle: 'የመዘምራን መረጣ (Choir Selection)',
    ),
    '/admin/weddings': (
      title: 'የሰርግ መዘምራን አገልግሎት (Wedding Choir)',
      requiredPermission: 'choir.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/categories': (
      title: 'የመዝሙር ምድቦች አስተዳደር (Mezmur Categories Admin)',
      requiredPermission: 'categories.manage',
      fallbackRoute: '/home/categories',
      fallbackTitle: 'ምድቦች (Categories)',
    ),
    '/admin/mezmurs': (
      title: 'የመዝሙር ይዘት አስተዳደር (Mezmur Content Admin)',
      requiredPermission: 'mezmurs.view',
      fallbackRoute: '/home',
      fallbackTitle: 'መዝሙራት (Mezmurs)',
    ),
    '/admin/import': (
      title: 'የጅምላ ማስገቢያ (Bulk Import)',
      requiredPermission: 'mezmurs.create',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/program-categories': (
      title: 'የመርሐ ግብር ምድቦች (Program Categories)',
      requiredPermission: 'program_categories.manage',
      fallbackRoute: '/admin/programs',
      fallbackTitle: 'መርሐ ግብራት (Programs)',
    ),
    '/admin/ads': (
      title: 'ማስታወቂያዎች አስተዳደር (Ads Admin)',
      requiredPermission: 'ads.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/pages': (
      title: 'የገጾች አስተዳደር (Pages Admin)',
      requiredPermission: 'pages.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/projects/my-tasks': (
      title: 'የእኔ ተግባራት (My Tasks)',
      requiredPermission: 'projects.view',
      fallbackRoute: '/projects',
      fallbackTitle: 'ፕሮጀክቶች (Projects)',
    ),
    '/projects/approvals': (
      title: 'የወጪ ማጽደቂያዎች (Project Approvals)',
      requiredPermission: 'projects.expenses.approve',
      fallbackRoute: '/projects',
      fallbackTitle: 'ፕሮጀክቶች (Projects)',
    ),
    '/admin/admins': (
      title: 'አስተዳዳሪዎች (Admins Management)',
      requiredPermission: 'admins.view',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/roles': (
      title: 'ሚናዎች እና ፈቃዶች (Roles & Permissions)',
      requiredPermission: 'admins.view',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/settings': (
      title: 'የስርዓት ቅንብሮች (System Settings)',
      requiredPermission: 'settings.manage',
      fallbackRoute: '/settings',
      fallbackTitle: 'ቅንብሮች (Settings)',
    ),
    '/admin/releases': (
      title: 'የመተግበሪያ እትሞች (App Releases)',
      requiredPermission: 'releases.manage',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/guidance': (
      title: 'የመመሪያዎች አስተዳደር (Manage Guidance)',
      requiredPermission: 'guidance.manage',
      fallbackRoute: '/settings/guidance',
      fallbackTitle: 'የመመሪያ ማዕከል (Guidance Center)',
    ),
    '/admin/reports': (
      title: 'ሪፖርቶች እና ዳሽቦርድ (Reports & Analytics)',
      requiredPermission: 'reports.view',
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/admin/audit': (
      title: 'የስርዓት ኦዲት ሎግ (System Audit Trail)',
      requiredPermission: 'audit_logs.view',
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/admin/activity': (
      title: 'የተጠቃሚዎች እንቅስቃሴ (Activity Log)',
      requiredPermission: 'activity_logs.view',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/edu/assignments': (
      title: 'የተማሪዎች ክፍል ምደባ (Class Assignment & Rosters)',
      requiredPermission: 'education.manage',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/admin/edu/classes': (
      title: 'የሰንበት ት/ቤት ክፍሎች (Sunday School Classes)',
      requiredPermission: 'education.manage',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/admin/edu/academic-years': (
      title: 'የትምህርት ዘመን እና ወሰነ-ትምህርት (Academic Calendar Admin)',
      requiredPermission: 'education.manage',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/calendar': (
      title: 'የትምህርት ቀን መቁጠሪያ (Academic Calendar)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/admin/edu/programs': (
      title: 'ከክፍል ጋር የተሳሰሩ መርሐ ግብሮች (Class-Linked Programs)',
      requiredPermission: 'education.manage',
      fallbackRoute: '/admin/programs',
      fallbackTitle: 'መርሐ ግብር (Programs)',
    ),
    '/admin/selections/intervals': (
      title: 'የመረጣ ጊዜያት እና የአቴንዳንስ ነጥቦች (Selection Intervals & Attendance Rules)',
      requiredPermission: 'selection.configure',
      fallbackRoute: '/admin/selections',
      fallbackTitle: 'የመረጣ አስተዳደር (Selections)',
    ),
    '/offline-status': (
      title: 'ከመስመር ውጭ አሠራር እና ማመሳሰል (Offline Sync Status)',
      requiredPermission: null,
      fallbackRoute: '/hub',
      fallbackTitle: 'የመተግበሪያው ማዕከል (Hub)',
    ),
    '/edu/assignments': (
      title: 'የቤት ሥራዎች እና ምደባዎች (Assignments)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/results': (
      title: 'የትምህርት ውጤቶች እና ግምገማ (Academic Results)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/retakes': (
      title: 'የድጋሚ ፈተና ጥያቄዎች (Exam Retake Requests)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/exams': (
      title: 'የፈተና ጥያቄዎች እና ምዘና (Exams & Assessments)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/certificates': (
      title: 'የትምህርት ማስረጃዎች (My Certificates)',
      requiredPermission: null,
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/admin/edu/certificates': (
      title: 'የሰርተፊኬት አሰጣጥ እና ቁጥጥር (Certificate Issuance & Management)',
      requiredPermission: 'education.certify',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/library/books': (
      title: 'ዲጂታል ቤተ-መጽሐፍት እና ትረካ (Digital Library & Narration)',
      requiredPermission: null,
      fallbackRoute: '/edu/library',
      fallbackTitle: 'ቤተ-መጽሐፍት (Library)',
    ),
    '/admin/library/circulation': (
      title: 'የሰንበት ት/ቤት ቤተ-መጽሐፍት ውሰት (Library Circulation & Loans)',
      requiredPermission: 'library.circulate',
      fallbackRoute: '/admin',
      fallbackTitle: 'የአስተዳዳሪ ዳሽቦርድ (Admin)',
    ),
    '/admin/edu/scores': (
      title: 'የትምህርት ውጤት እና የተሳትፎ ነጥቦች (Education Academic & Engagement Scores)',
      requiredPermission: 'education.reports',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
    '/edu/admin/scores': (
      title: 'የትምህርት ውጤት እና የተሳትፎ ነጥቦች (Education Academic & Engagement Scores)',
      requiredPermission: 'education.reports',
      fallbackRoute: '/edu',
      fallbackTitle: 'የትምህርት ክፍል (Education)',
    ),
  };

  /// Safely navigates from a guide or help sheet to a target screen.
  /// Validates permissions, shows clear reason if denied with a permitted alternative,
  /// initiates smooth auto-scroll to the relevant section or card, and launches tour if requested.
  static Future<void> navigateTo(
    BuildContext context,
    WidgetRef ref,
    String targetScreen, {
    String? requiredPermission,
    String? tourId,
    bool closeCurrentModal = true,
  }) async {
    final user = ref.read(currentUserProvider);

    // Parse route path and optional section anchor (e.g. /admin#users -> route: /admin, anchor: users)
    String routePath = targetScreen;
    String? sectionAnchor;
    if (routePath.contains('#')) {
      final parts = routePath.split('#');
      routePath = parts[0];
      sectionAnchor = parts.length > 1 ? parts[1] : null;
    }
    final normalized = routePath.split('?').first;

    // 1. Check if user is signed in
    if (user == null) {
      final proceed = await _showLoginPrompt(context, routePath);
      if (proceed && context.mounted) {
        if (closeCurrentModal && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        context.push('/login');
      }
      return;
    }

    // 2. Strict Permission and Admin checks (no blind bypass for staff admins)
    final destinationMeta = destinationRegistry[normalized];
    final effectivePerm = requiredPermission ?? destinationMeta?.requiredPermission;
    final isAdminRoute = normalized.startsWith('/admin') || normalized.startsWith('/system');
    final isSuperAdmin = (user.roleLevel ?? 0) >= 100 || (user.isAccountAdmin && user.roleName == 'superadmin');

    final lacksAdminAccess = isAdminRoute && !user.isAdmin && !isSuperAdmin;
    final lacksPermission = effectivePerm != null && !user.can(effectivePerm) && !isSuperAdmin;

    if (lacksAdminAccess || lacksPermission) {
      await _showPermissionDeniedDialog(
        context,
        destinationTitle: destinationMeta?.title ?? targetScreen,
        requiredPermission: effectivePerm ?? 'Admin Authority',
        fallbackRoute: destinationMeta?.fallbackRoute ?? '/hub',
        fallbackTitle: destinationMeta?.fallbackTitle ?? 'መነሻ ገጽ (Home)',
        onNavigateFallback: (route) {
          final nav = rootNavigatorKey.currentContext ?? context;
          if (closeCurrentModal && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          nav.push(route);
        },
      );
      return;
    }

    // 3. Capture active navigation context before closing modal
    final navContext = rootNavigatorKey.currentContext ?? context;
    if (closeCurrentModal && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // 4. Push destination to navigation stack so users can press Back to return
    try {
      navContext.push(routePath);

      // 5. Auto-scroll to specific section or module card if anchor or key is available
      final targetKey = TourKeys.moduleKeys[normalized];
      if (targetKey != null || sectionAnchor != null) {
        _scheduleScrollToSection(targetKey);
      }

      // 6. If an interactive tour is attached, auto-start it once destination is mounted
      if (tourId != null && TourCatalog.tours.containsKey(tourId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navContext = rootNavigatorKey.currentContext ?? context;
          TourController.instance.startTour(navContext, tourId, ref: ref, force: true);
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('የተጠየቀው አገልግሎት ለጊዜው አልተገኘም: $routePath'),
          backgroundColor: AppColors.maroon,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static void _scheduleScrollToSection(GlobalKey? key) {
    if (key == null) return;
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      attempts++;
      final ctx = key.currentContext;
      if (ctx != null) {
        timer.cancel();
        try {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        } catch (_) {}
      } else if (attempts >= 15) {
        timer.cancel();
      }
    });
  }

  static Future<bool> _showLoginPrompt(BuildContext context, String targetScreen) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppColors.maroon),
                const SizedBox(width: 8),
                Text('መግባት ያስፈልጋል', style: ctx.serif(18, weight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'ይህንን አገልግሎት ለመጠቀም በመጀመሪያ ወደ መለያዎ መግባት አለብዎት። አሁን መግባት ይፈልጋሉ?',
              style: ctx.sans(14),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ይቅር')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('ግባ (Sign In)'),
              ),
            ],
          ),
        )) ??
        false;
  }

  static Future<void> _showPermissionDeniedDialog(
    BuildContext context, {
    required String destinationTitle,
    required String requiredPermission,
    required String fallbackRoute,
    required String fallbackTitle,
    required void Function(String route) onNavigateFallback,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text('ፈቃድ አልተሰጠም', style: ctx.serif(18, weight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '«$destinationTitle» ገጽን ለመክፈት አስፈላጊው ፈቃድ የለዎትም።',
              style: ctx.sans(14, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'የሚያስፈልግ ፈቃድ: $requiredPermission',
                      style: ctx.sans(12, color: AppColors.danger, weight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'በምትኩ ወደ ተፈቀደው $fallbackTitle መሄድ ይችላሉ።',
              style: ctx.sans(13, color: ctx.palette.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('እሺ (Close)'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text('ወደ $fallbackTitle'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
            onPressed: () {
              Navigator.of(ctx).pop();
              onNavigateFallback(fallbackRoute);
            },
          ),
        ],
      ),
    );
  }
}
