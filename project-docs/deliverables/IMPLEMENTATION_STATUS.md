# Implementation Status — Meserete Hiwot Super-App

Reviewed 2026-10-16 against the source code (backend `laravel/`, app `mobile/mobile/`), the route table, the database schema and the project logs. Production release recorded in the project logs: **1.5.3+16** (published 2026-10-16, mandatory update). Source tree version: **1.5.3+19**.

## Summary

| Status | Meaning | Count |
|---|---|---|
| **LIVE** | Live (released 1.5.3+16) | 79 |
| **UNREL** | Implemented in source – not yet released | 6 |
| **PARTIAL** | Partially implemented | 7 |
| **MISSING** | Not implemented (planned) | 4 |
| **WITHDRAWN** | Withdrawn (removed by request) | 1 |
| **CONFIG** | Configured – not verified | 1 |
| | **Total** | **98** |

How each status was determined:

- **Verified / Live** — the code path exists in the source, its migration is part of the 1.5.3+16 schema (present in the test database), and the project logs record its deployment.
- **Implemented in source – not yet released** — code and migrations exist in the source tree (labelled for builds +17…+19 in code comments) but the migrations are not applied to the test database and no release is recorded. Treat as *in development*.
- **Partial** — part of the feature exists; the gap is named in the notes (cross-checked with the 2026-10-16 plan in `prompt.md`).
- **Missing / planned** — no implementation found by code search.
- **Withdrawn** — built and later removed at the church's request; data structures kept.
- **Configured – not verified** — project configuration exists but no build or operation could be verified.

## Verified — live in 1.5.3+16 (79)

### Accounts & security
- Registration with 4/6-digit PIN, member group, membership profile (`routes/api/auth.php · AuthService::register`)
- Sign-in by phone or e-mail + PIN; 5 failures → 15-minute lock (`AuthService::login (MAX_FAILED, LOCK_MINUTES)`)
- One trusted device per member; administrators on several devices (`AuthService::login · Middleware::resolve`)
- Access JWT + rotating refresh tokens; app sessions do not time out (`Tokens.php · config mz.jwt`) — *Decision 2026-10-13: automatic logout removed*
- Session list, end one / others / all sessions (`Sessions.php · /settings/sessions`)
- PIN reset by 6-digit code via Telegram or e-mail (`AuthService::forgotPassword/resetPassword`)
- Admin device reset, force logout, disable, soft delete (`UserAdmin.php`)
- Account approval states (pending / active / disabled), can_login flag (`AuthService::login`)
- Biometric lock and screenshot blocking on personal screens (`local_auth · widgets/secure_screen.dart`)
- Telegram account linking (`Notifications/Telegram.php · routes/api/telegram.php`)

### Members, HR & departments
- Membership form (profile) with encrypted personal fields (`MemberProfile.php · Crypto/EncryptedColumns.php`)
- Member ID numbers with group prefix; digital ID card with QR (`MemberIds.php · Members.php · /settings/me`)
- Member groups (types) management (`MemberGroups.php`)
- Profile change requests with approval and permanent history (`ProfileChanges.php`)
- 7 departments, membership, role labels, department admins (`Departments.php · DepartmentAdmins.php`)
- Monthly department participation score by the department leader (`Departments::saveParticipation`)
- Professions catalogue (`Professions.php`)
- Bulk import of users / Mezmurs / categories (xlsx, csv, paste; dry run) (`Import.php`)

### Mezmur
- Mezmur library: hierarchical categories, search, recent / popular, today's category (`Mezmurs.php · Categories.php`)
- Lyrics with adjustable font size; time-synced lyrics (LRC) and LRC maker for admins (`core/utils/lrc.dart · admin/lrc_maker.dart`)
- Audio player: background playback, lock-screen controls, queue, shuffle, repeat, speed, sleep timer (`services/audio_player_service.dart`)
- Favourites and offline downloads (lyrics always, audio optional) (`favorites_service.dart · download_service.dart`)
- YouTube link playback (`features/mezmurs/youtube_view.dart`)
- Admin: create / edit / publish Mezmurs, audio & cover upload, bulk category assignment, drafts (`content_admin.dart · Mezmurs.php`)
- Share links (/m/{id}) with preview page and app deep link (`routes/web/public.php`)

### Programs & attendance
- Programs: once / weekly / monthly / twice monthly / Ethiopian calendar days; occurrence overrides (`ProgramSchemas.php · Schedule.php`)
- Audience (all or participants), registration, capacity, member-group targeting (`Programs.php`)
- Program reminders (2 d / 1 d / 6 h / 1 h) and 15-day interval reminders; mandatory reminders (`ReminderJobs.php · program_alarms.dart`)
- Attendance sessions: one HR-assigned taker, opens 15 min before, Start / End, auto-end (`AttendanceSessions.php`)
- QR or manual marking; signature for every Present mark (group exemptions) (`Attendance::set · attendance.signature setting`)
- No 'late' status; capture time and elapsed seconds since Start recorded (`Attendance.php (LATE_REMOVED)`)
- Absence excuse requests with deadline and monthly / quarterly limits; admin cancel of approved excuse (`Permissions.php`)
- Corrections after closure with review (`Attendance::requestCorrection/reviewCorrection`)
- Offline attendance with encrypted queue and HR conflict review queue (`Sync.php · /admin/attendance/conflicts`)
- Member attendance calendar and statistics (`Attendance::calendar/stats · /settings/attendance`)

### Education
- Classes, courses (subjects), schedules, staff, registration windows, regular / distance streams (`Edu.php · EduRegistration.php`)
- Teacher assignments with history; only active teachers enter marks (`EduTeachers.php · edu_course_teachers`)
- Marks workflow draft → submitted → approved / rejected → published, amendments with reason (`EduMarks.php · edu_score_history`)
- Student requests (class / stream / mode change, add / drop) and complaints (EC-YYYY-NNNNNN) (`EduRequests.php · EduComplaints.php`)
- Learning platform: categories → subjects → units → lessons with materials and progress (`EduLearning.php · features/edu/learn`)
- Quizzes: 4 question types, timer, attempts, manual grading, send to score sheet (`EduQuizzes.php`)
- Module gate: Education can be switched off per member (403 MODULE_DISABLED) (`Http/ModuleGate.php`)

### Holiday selection & Mezmur services
- Holiday selection: 5 weighted components, minimums, pass mark, bonus, per-program weights (`Selections.php (DEFAULT_CONFIG)`)
- Lifecycle draft → open → review → finalized (+ cancel); required department reviews; overrides with reason (`Selections::setStatus/submitReview/override`)
- Service categories (ወረብ / መዝሙር), rankings, publication, member feedback (`Selections::assignCategories/publish/submitFeedback`)
- Selection and Mezmur-selection reports (PDF / XLSX / CSV) (`ReportExport.php · SelectionReports.php`)
- Wedding (other) Mezmur services with manual participant selection (`Weddings.php`)
- Daily choir eligibility computation (`Choir::refresh · job choir:eligibility 02:15`)

### Contributions, property & library
- Monthly contributions by Ethiopian month, rates per member type, receipts, verification (`Payments.php`)
- 'Paid after due month' label (grace days) — financial rule kept (`payments.policy grace_days`)
- Items / property inventory with categories, codes, departments, history (`Items.php`)
- Borrowing: direct, bulk, approval, renewal, return conditions, signatures (`Borrowings.php`)
- Fines: per day / week, grace, cap, override with reason, daily recalculation (`Fines.php · job fines:recalculate`)
- Department property requests with review, issue, partial issue, return (`PropertyRequests.php`)

### Projects & collaboration
- Department projects, teams, tasks with several assignees, statuses with reasons (`Projects/ProjectService.php · TaskService.php`)
- Budgets by category, expenses with receipts, over-budget control, adjustments (Finance approval) (`Projects/BudgetService.php`)
- Issues, suggestions (convert to task), comments, files, activity feed, reports (`Projects/FeedbackService.php · ReportService.php`)
- Department chat: group + private threads, media for leaders, meeting links, Task Bot (`Chat.php · Projects/Bot.php`)
- Task deadline reminders (`ProjectReminders.php · scheduled_notifications`)

### Communication
- In-app notification centre with topics and per-user preferences (`Notifications.php (8 topics)`)
- Push notifications (Firebase Cloud Messaging) (`Fcm.php · push_service.dart`) — *Requires Firebase credentials in the environment*
- E-mail delivery (SMTP) (`Mailer.php`) — *Requires SMTP settings*
- Admin broadcasts to one / selected / filtered / all, resend, delivery history (`Broadcasts.php · Targeting.php`)
- Banners (advertisements) and internal pages (`Promotions.php`)
- Notification delivery health screen (`Notifications::health · /admin/notification-health`)
- In-app guidance: 56 bilingual articles, tours, contextual help (`GuidanceService.php · guidance_catalog.dart`)

### Administration, reports & audit
- Role-based access: 63 permissions, roles, direct grants and revocations (`Auth/Catalog.php · Admins.php`)
- Admin panel with 10 permission-filtered groups (`features/admin/admin_home.dart`)
- Dashboard and reports (`Reports.php`)
- 15 export kinds in PDF / XLSX / CSV, each audited (`ReportExport.php`)
- Audit log and user activity log (`Auth/Audit.php · Activity.php`)
- System settings with validated schemas (`Settings.php`)
- App releases: APK hosting, download page, mandatory update / minimum build (`Releases.php · update_service.dart`)

### Platform
- Ethiopian calendar (Amete Mihret) for periods, dates, reports and program days (`Support/Ethiopian.php · ethiopian_date_picker.dart`)
- Amharic (template) and English localisation (2,754 keys) (`lib/l10n/app_am.arb · app_en.arb`)
- Light / dark theme, church branding and module watermarks (`core/theme · widgets/brand.dart`)
- Background jobs without cron (after-response tick) (`Jobs/Jobs.php`)
- At-rest encryption of sensitive columns (`Crypto/Seal.php · DataEncryptor.php`)
- Web app (PWA) build (`mobile/mobile/web · deployed per records`)

## Implemented in source — not yet released (6)

### Programs & attendance
- Class attendance through programs linked to classes (edu_attendance frozen) (`migration 2026_10_20_000002 · Settings::eduAttendanceCutover`) — *Release target +19 (F4)*
- Elapsed-time interval percentages per attendance category for selection (`Selections::validateIntervalRules/scoreOccurrenceInterval`) — *Release target +19 (F6)*

### Education
- Academic years, terms, Grades 1–12 levels, exclusive enrolment, course offerings (`EduAcademicYears.php · migration 2026_10_20_000001`) — *Release target +18 (F1–F3)*

### Holiday selection & Mezmur services
- Contribution month range for selection (`routes/api/selections.php start_month/end_month`) — *Was a defect (F5); fix in source*
- Selection configuration versions (`Selections::recordConfigVersion`) — *F6*

### Platform
- Offline queue preserved on sign-out (`features/auth/session.dart logout(discard)`) — *Was a defect (F0a)*

## Partially implemented (7)

### Education
- Assignments (individual / group), submissions and grading (`Edu.php`) — *No publish time, deadline enforcement or late rule (F9)*
- Question banks / random draws (`EduQuizzes.php`) — *Banks not implemented (F12)*
- Student dashboard (`EduDashboard::forUser`) — *F14*

### Contributions, property & library
- Library: digital PDF books (encrypted on device), physical book requests (`Library.php · book_vault.dart`) — *No sub-categories, favourites, reading progress (F16)*
- Physical library with per-copy IDs (`items quantity-based`) — *F17 – decision D6 needed*

### Platform
- Offline: cache of GET responses, offline pack, sync queue for listed operations (`local_db.dart · sync_service.dart`) — *Platform-wide offline incl. admins planned (F7)*
- Shared Settings filtered by module; Education edit pen; role guidance for students/teachers; responsive checks of admin tables (`prompt.md F18–F21`) — *Polish items*

## Not implemented — planned (4)

### Education
- Course outcomes and pass marks (`pass_mark column added in unreleased migration only`) — *F10*
- Failed courses and online retakes (`—`) — *F11*
- Certificates and verification (`—`) — *F13 – needs wording/signatory decision (D7)*
- Academic and engagement scores for admins (`—`) — *F15*

## Withdrawn (1)

### Holiday selection & Mezmur services
- Department-based criteria (50/30/10/10) (`backups/department-criteria-2026-10-15`) — *Removed 2026-10-15; tables kept unused*

## Configured — not verified (1)

### Platform
- iOS app (`ios/ project, Info.plist`) — *No build or store release verified*

## Proposed (not existing functionality)

These are recommendations only; none is implemented or approved:

- iOS build and store release.
- Automated off-server backups of database and private files with restore tests.
- Uptime and job-failure monitoring with alerts.
- A cron entry calling `php artisan mz:jobs` so reminders do not depend on traffic.
- Continuous integration running both test suites on every change against a freshly migrated database.
- Regenerate the OpenAPI specification from the current Laravel routes.
- Optional online payment of contributions (requires a leadership decision).

## Release roadmap (from the approved plan)

| Build | Contents | Status |
|---|---|---|
| +17 | F0a offline queue kept at sign-out; F5 contribution month range | In source, unreleased |
| +18 | F1–F3 academic years, terms, levels, exclusive enrolment, course offerings | In source, unreleased |
| +19 | F4 class attendance through programs; F6 interval scoring and config versions | In source, unreleased |
| +20 | F7 platform-wide offline incl. administrators | Planned |
| +21 | F8–F12 results pipeline (assignments, outcomes, retakes, exams/banks) | Planned |
| +22 | F13–F15 certificates, student dashboard, scores | Planned (needs decisions D7, D8) |
| +23 | F16–F17 digital and physical library | Planned (needs decision D6) |
| +24 | F18–F21 settings, edit pen, guidance, responsive checks | Planned |

## Verification performed for this report

- Route table exported with `php artisan route:list --json` (570 routes; 564 documented, 6 restricted).
- Schema read from `information_schema` of `mh_app_test` (128 tables).
- Flutter suite: `flutter test` → 176 passed, 12 skipped, 0 failed.
- Backend suite: `php vendor/bin/phpunit` → 119 tests, 82 passed, 34 failures, 3 errors. All failing tests are Integration tests touching Education/attendance; the recorded causes are a missing table (`edu_academic_years`) and a missing column (`config`) — both created by the two unreleased migrations, which are not applied to the test database. The test database was intentionally not migrated during this review.
- Not verified: the production server state (no connection was made), the iOS build, and whether builds +17…+19 were deployed after the last log entry.
