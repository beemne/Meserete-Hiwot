# Education & Attendance Implementation Plan

Meserete Hiwot super-app · Laravel 11 backend (`laravel/`) · Flutter app (`mobile/mobile/`) · reviewed 2026-10-16 against release 1.5.3+16

Source: https://claude.ai/artifact/QTP3bKdVjRKYRQeTQex4yy

This plan covers every feature from the two requirement documents ("Complete Education Platform Transformation" and "Attendance, Service Selection, Offline Mode"). For each one it gives the code's current state, how the feature must work, how to build it here, the expected output, and the acceptance criteria. Statuses come from reading the code and the test database schema. Nothing was changed during this review.

---

## Contents

- Start here: [Status summary](#status-summary) · [Decisions needed](#decisions-needed-before-building) · [How to build in this codebase](#how-to-build-in-this-codebase)
- Shipped + follow-ups: [F0 Attendance sessions](#f0--attendance-sessions-signatures-and-offline-attendance--done) · [F0a Offline queue lost on sign-out](#f0a--offline-queue-lost-on-sign-out--defect)
- Academic core: [F1](#f1--academic-years-terms-and-grade-levels--missing) · [F2](#f2--class-assignment-and-exclusive-enrollment--partial) · [F3](#f3--courses-teachers-eligibility-and-physical-programs--partial) · [F4](#f4--class-attendance-through-programs--missing)
- Service selection: [F5](#f5--selection-monthly-contribution-range--defect) · [F6](#f6--selection-attendance-categories-and-elapsed-time-intervals--partial)
- Offline: [F7](#f7--platform-wide-offline-including-administrators--partial)
- Learning & results: [F8](#f8--online-learning-remaining-gaps--done--gaps) · [F9](#f9--assignments--partial) · [F10](#f10--course-outcomes-and-pass-marks--missing) · [F11](#f11--failed-courses-and-online-retakes--missing) · [F12](#f12--online-exams-and-question-banks--partial) · [F13](#f13--certificates-and-verification--missing) · [F14](#f14--student-dashboard--partial) · [F15](#f15--admin-activity-and-academicengagement-scores--missing)
- Libraries: [F16](#f16--digital-library--partial) · [F17](#f17--physical-sunday-school-library--partial)
- Experience: [F18](#f18--shared-settings-filtered-by-module--partial) · [F19](#f19--education-editing-pen--missing) · [F20](#f20--role-specific-guidance--partial) · [F21](#f21--responsive-design-and-accessibility--partial)
- [Build order and releases](#build-order-and-releases)

---

## Status summary

Evidence key: **Done** is implemented, tested and live. **Partial** means some of the feature exists. **Missing** means there is no implementation. **Defect** means it exists but is wrong.

| # | Feature | Status | What exists today |
|---|---|---|---|
| F0 | Attendance sessions, signatures, HR control, offline attendance | Done | Live in 1.5.3+16. Backend has 98 tests and the app 168. |
| F0a | Offline queue survives sign-out | **Defect** | Signing out offline deletes queued attendance and signatures. |
| F1 | Academic years, terms, Grades 1–12 | Missing | Only free-text `edu_classes.academic_year` / `semester` / `term` columns. |
| F2 | Exclusive class assignment | Partial | Registration and class-change requests exist. Nothing stops two active classes in the same year. |
| F3 | Courses across classes and periods, eligibility | Partial | Each course belongs to one class. Teachers and course enrollments exist. There are no eligible groups and no program link. |
| F4 | Class attendance through programs | Missing | A separate `edu_attendance` tool with 5 app entry points still exists. |
| F5 | Contribution month range | **Defect** | The server calculation reads the start and end months. The API schema rejects them, so they can never be saved. |
| F6 | Category and elapsed-time attendance scoring | Partial | Mezmur categories exist. There are no interval percentages and no config versions in use. |
| F7 | Offline for all pages and admins | Partial | GET responses are cached in plain SQLite. The banner is Mezmur-only and shows no last-sync time. |
| F8 | Online learning | Done + gaps | Shipped in 1.5.3+15. Enrollment-based access and prerequisites are thin. |
| F9 | Assignments | Partial | Create, submit, grade and groups work. There is no publish time, deadline enforcement or late rule. |
| F10 | Course outcomes and pass marks | Missing | The marks review and publish workflow exists. There is no pass mark or outcome. |
| F11 | Retakes | Missing | — |
| F12 | Exams and question banks | Partial | Quizzes support 4 question types, attempts, timers and manual grading. There are no banks or random draws. |
| F13 | Certificates and verification | Missing | — |
| F14 | Student dashboard | Partial | `EduDashboard::forUser` exists. It lacks the academic period, outcomes, certificates and retakes. |
| F15 | Admin activity and academic/engagement scores | Missing | Journey events and activity logs exist. There are no scores. |
| F16 | Digital library | Partial | An encrypted PDF download and a basic reader exist. There are no subcategories, favorites, progress or narration. |
| F17 | Physical library with per-copy IDs | Partial | Books are quantity-based `items`. Loans are ordinary `borrowings`. |
| F18 | Shared Settings, filtered by module | Partial | There is one Settings screen. It shows the same content from either module. |
| F19 | Education editing pen | Missing | The pen exists only on the Mezmur home and Programs. |
| F20 | Role-specific guidance | Partial | The guidance system and attendance articles exist. Education student, teacher and librarian articles are missing. |
| F21 | Responsive and accessibility verification | Partial | Overflow tests exist for Learn screens and the roster. Admin tables are not covered. |

---

## Decisions needed before building

Each question blocks part of the work. A recommendation follows each one. Everything else in this plan follows decisions you have already made.

### D1 · Signing out with unsynced offline work (F0a)
Today the queue is deleted at sign-out. Should sign-out be blocked until it syncs, or allowed with an explicit "discard N unsynced records" confirmation?

**Recommended:** block sign-out while offline work is pending, and offer "Sign out and discard" only behind a second confirmation. When the server revokes the session, keep the queue tagged with the user's id and send it after that same user signs in again.

### D2 · Attendance after the last time interval (F6)
A member is recorded after the final configured interval. Does that record earn 0%, or the last interval's percentage?

**Recommended:** an explicit "after the last interval" value per category, defaulting to 0%, so nothing is assumed.

### D3 · Excused records in interval scoring (F6)
**Recommended:** keep today's rule. Excused uses the existing permission-policy weight and ignores intervals, because it has no capture time.

### D4 · Contributions: partial payments and missing months (F5)
The payment model has no "partial" status. A month is paid, paid after due month, exempt or unpaid.

**Recommended:** count only paid and paid-after-due-month as paid. A missing record is unpaid. A partial amount stays unpaid until the month is fully covered. No new financial rule is invented.

### D5 · Class attendance history in selection (F4/F6)
When class attendance moves to programs, the old `edu_attendance` rows (6 live) still exist.

**Recommended:** freeze `edu_attendance` as read-only. Selection uses it for dates before the switch-over day and program attendance from that day on. Both are shown separately in the explanation.

### D6 · Existing Education books (F17)
**Recommended:** move physical `timhirt` books into the new library tables, one copy record per unit with IDs generated as `LIB-{code}-{number}-{copy}`. Keep open borrowings in `borrowings` until they are returned, and record new loans only in the library tables.

### D7 · Certificate wording and signatory (F13)
I need the issuing organisation's name as it should print, the signatory title(s) and whether the certificate carries a church seal image. Online and physical courses use the same template unless you say otherwise.

### D8 · Score formulas (F15)
**Recommended:** Academic score = average percentage of the published course outcomes in the period. Engagement score = (completed accessible mandatory lessons ÷ accessible mandatory lessons) × 50% + (submitted assignments ÷ assignments due) × 30% + (quiz and exam attempts ÷ open quizzes and exams) × 20%. Both appear only to `education.reports` holders, and each shows its counts.

### D9 · Offline writes for administrators (F7)
**Recommended:** admin pages are readable offline from the last sync. Only these writes are queued: attendance (done), borrowing and returns (done), task updates (done), library checkout and return (new), and marking lessons complete (new). Everything else shows "Needs a connection".

---

## How to build in this codebase

Every feature below follows these conventions. They are what the existing, tested code already does.

### Backend
- Services live in `app/Mz/Services/*.php` as static classes. Routes are closures in `routes/api/*.php`, with input parsed through `Ctx::body(Z::object([...]))`.
- Permission checks use the `mz`, `mz:any,…` or `mz:all,…` middleware, and the service checks again. Education routes also use `mz.module:education`.
- Errors go through `ApiError::field/conflict/forbidden/notFound`, using UPPER_SNAKE codes that the app maps in `core/l10n/error_text.dart`.
- Audit every sensitive change with `Audit::log($actx, action, entity, id, meta, inTrx:)`.
- Migrations are additive, raw SQL, idempotent (`hasTable`/`hasColumn`) and reversible. They never delete live rows.
- Tests are written in `tests/Integration/*Test.php` on `IntegrationTestCase` (`member()`, `as()`, `program()`) against MariaDB `mh_app_test`.

### App
- The app uses Riverpod and GoRouter with one shell. Repositories live in `lib/repositories/`, and screens under `lib/features/<module>/`.
- Offline-capable writes go through `SyncService.submit`/`enqueue`, with a matching op in `app/Mz/Services/Sync.php`.
- Text is localized: `lib/l10n/app_am.arb` is the template and `app_en.arb` the English file, followed by `flutter gen-l10n`.
- Widget tests use `test/fakes.dart` (`FakeAdapter`) and an in-memory SQLite (sqflite_common_ffi), and they check overflow at 360 dp and 130% text size.
- Each release follows the same steps: a DB backup, then `deploy.py`, then `optimize:clear`, a live check and `Releases::publish`. `deploy.py` never deletes server files that were removed locally.

---

## F0 · Attendance sessions, signatures and offline attendance — Done

**Purpose:** Each program date has one HR-assigned taker. Attendance opens 15 minutes before the start and counts from Start. Every Attended mark is signed and timed. HR controls attendance, and offline capture keeps a conflict queue.

### Current status: verified
- Migration `2026_10_19_000001_attendance_sessions` ran on production on 2026-10-16. The backup is `~/backups/appdb-before-attendance-16-20261016-0105.sql.gz`.
- The work is in `AttendanceSessions.php`, plus the rewrite of `Attendance.php` and the `Sync.php` ops `attendance.session.start/end` and `attendance.record`.
- On the app side it is the roster session card, signature capture, `QueueSeal` (AES-GCM for queued signatures), the HR review screen `/admin/attendance/conflicts` and the signature policy screen.
- Tests: `AttendanceSessionTest` (12) and `AttendanceRegressionTest` (4) on the backend; `attendance_session_test.dart` and `offline_resilience_test.dart` in the app.
- Release 1.5.3+16 is published as mandatory (`min_supported_code` 16).

### Remaining items, delivered by other features
- The report columns "Associated classes" and "interval percentage" come with F4 and F6.
- The offline indicator with last-sync time comes with F7.
- The sign-out data loss is F0a, and should be fixed first.

---

## F0a · Offline queue lost on sign-out — Defect

**Purpose:** Offline attendance, signatures, borrowings and task changes must never be lost. They are lost today if the user signs out, or the server revokes the session, before the phone syncs.

### Current status: evidence
- `features/auth/session.dart` `logout()` runs the sign-out hooks, including `SyncService.flush()`, with a 10-second timeout. `_clear()` then calls `LocalDb.clearUserData()`.
- `core/storage/local_db.dart` `clearUserData()` runs `db.delete('sync_queue')`. When the phone is offline, the flush sends nothing and every queued op is deleted.
- `expire()` (server revoked the session) does the same with no flush attempt at all.
- No screen warns the user. `SyncService.pendingCount()` exists but nothing calls it.

### Implementation steps
1. Add a `user_id` column to `sync_queue` with a local DB version bump in `local_db.dart`. Fill it in `SyncService._insert` from `currentUserProvider`.
2. Make `_flush` send only the current user's rows.
3. In `logout()`, before the hooks run, get `pendingCount()`. If it is above 0, try a flush (online) and recount. If rows are still pending, show a dialog: "N changes recorded offline are not synced yet" with **Stay signed in** as the default and **Sign out and discard**. The discard option sits behind a second confirmation that names the count.
4. In `_clear()`, stop deleting `sync_queue` by default. Delete only on an explicit discard, and only the leaving user's rows. On `expire()`, keep the rows. They sync after the same user signs in again, and stay invisible to anyone else. Purge another user's rows after 30 days.
5. Keep wiping the plain-text response cache at sign-out, as today. Sealed queue payloads stay encrypted.

### Expected behavior and output
- A taker offline with 12 queued records presses Sign out. The dialog shows 12 and the default keeps them signed in. The queue is untouched.
- The session is revoked while offline. After the same taker signs in again, the 12 records sync with their original capture times, and the server applies them or sends them to HR review.
- A different person signs in on that phone. They never see or send the first user's rows.

### Errors and edge cases
- A flush fails halfway: the rows the server already acknowledged are deleted, and the rest stay.
- Duplicate resend after sign-in again: the server receipts (`sync_receipts`) return `duplicate`, so nothing is doubled.
- The keystore key is lost: the op is reported as `LOCAL_DATA_UNREADABLE` (already handled).

### Files
`lib/core/storage/local_db.dart`, `lib/features/auth/session.dart`, `lib/services/sync_service.dart`, the settings sign-out tile in `settings_screen.dart`, the ARB files, and `test/offline_resilience_test.dart`.

### Acceptance criteria
- [ ] Offline with pending ops, Sign out → dialog shows the count; choosing Stay keeps every row.
- [ ] Discarding requires two confirmations, and only the leaving user's rows are deleted.
- [ ] `expire()` keeps the rows, and the same user's next sign-in syncs them exactly once.
- [ ] Another user's sign-in never sends or shows the earlier user's rows.

---

## F1 · Academic years, terms and grade levels — Missing

**Purpose:** One academic calendar drives classes, assignments, outcomes, reports and selection filters. Years follow the Ethiopian calendar. Terms are configurable. The levels are Grades 1–12 plus admin-defined levels.

### Current status
- `edu_classes` stores `academic_year varchar(20)`, `semester varchar(40)` and `term varchar(80)` as free text. Nothing validates them and there are no year, term or level tables.
- `member_groups` already models eligible groups and stays as it is.
- Live data: 1 class.

### Implementation steps
1. **Migration** `2026_10_20_000001_academic_structure`:
   - `edu_academic_years`: id, `eth_year` int unique, name, starts_on, ends_on, status enum(planned, active, closed), is_current tinyint, created_by, timestamps. Only one row may be current, enforced in the service inside a transaction.
   - `edu_terms`: id, academic_year_id FK, name, sort_order, starts_on, ends_on, status. UNIQUE(academic_year_id, name).
   - `edu_levels`: id, code unique, name, name_en, kind enum(grade, extra), sort_order, is_active, built_in. Seed G1 to G12 as built-in grades.
   - `edu_classes` gains `academic_year_id` and `term_id` (both nullable FKs), `level_id` nullable, and `allow_multiple` tinyint default 0.
   - Backfill: create years from the distinct `academic_year` text values (parsing a 4-digit Ethiopian year where present) and link the classes. Keep the text columns for history and stop writing them.
2. **Service** `EduAcademicYears`: list, create, update, setCurrent, close. Closing requires no open (unpublished) assessments, otherwise `YEAR_HAS_OPEN_MARKS`. The same service handles terms and levels.
3. **Routes** in `routes/api/edu.php` under `admin/`: `GET/POST/PATCH academic-years`, `…/{id}/terms` and `levels`, all behind `mz:all,education.manage`. Audit every change.
4. **Class editor** (`features/edu/edu_manage.dart`): replace the free-text year and semester fields with Year, Term and Level pickers. The class list gets a Year filter that defaults to the current year.
5. **Admin screen** "Academic calendar" under Course management, which lists years, their terms and the levels.

### Expected behavior and output
- An admin creates "2019 ዓ.ም" with Term I and Term II and marks it current. New classes default to it.
- The class list, rosters and reports filter by year and term. The API returns `academic_year: {id, eth_year, name}`, `term` and `level` objects on every class.
- Database: one `is_current=1` year. The text columns are unchanged on old rows.

### Errors and edge cases
- A duplicate `eth_year` gives `YEAR_EXISTS`. A term outside its year's dates gives `TERM_OUTSIDE_YEAR`.
- Deleting a year, term or level that classes use gives `HAS_RECORDS` (archive instead), matching the existing rule.
- A backfill value that can't be parsed leaves the class with `academic_year_id` null. It is listed under "Needs a year" for the admin to fix, never guessed.

### Files
New: the migration, `app/Mz/Services/EduAcademicYears.php` and its tests. Changed: `Edu.php` (createClass, updateClass, adminClasses, serialize), `routes/api/edu.php`, `EduSchemas.php`, `edu_manage.dart`, `edu_repository`, the ARB files.

### Acceptance criteria
- [ ] Grades 1–12 exist after the migration, and admins can add a level such as "Adult catechism".
- [ ] Only one current year can exist, even with two concurrent requests.
- [ ] Every existing class keeps its data. Classes with a parseable year are linked to it, and the rest are flagged.
- [ ] Rollback removes the new tables and columns without touching existing rows.

---

## F2 · Class assignment and exclusive enrollment — Partial

**Purpose:** Admins assign students to a class for an academic year. A student assigned to an exclusive class disappears from other exclusive lists for that year. Transfers and promotions keep their history.

### Current status
- `EduRegistration::register()` enrolls existing or new members into one class, inside a transaction with a class lock. `edu_enrollments` has UNIQUE(class_id, user_id) only, so a student can be active in two classes of the same year.
- `EduRequests` handles class-change requests with `target_class_id` and writes `edu_journey` events (`class_changed`). This is the existing history to reuse.
- The app registration screen (`features/edu/edu_registration.dart`) does not filter by year.

### Implementation steps
1. **Migration:** add `edu_enrollments.academic_year_id`, filled from the class. Add a generated column `exclusive_key = IF(status='active' AND allow_multiple=0, CONCAT(user_id,':',academic_year_id), NULL)` with a UNIQUE index. MariaDB allows multiple NULLs, so exclusivity is enforced by the database itself. Since `allow_multiple` lives on the class, copy it onto the enrollment row (`exclusive` tinyint) when the student is enrolled.
2. **Check existing data first:** list students with two active exclusive enrollments in one year, and stop the migration if any exist, printing them. Never auto-withdraw anyone.
3. **Assignment list:** `GET edu/admin/classes/{id}/assignable?q=&group=&page=` returns active members of the class's eligible groups (F3). It excludes anyone already active in this class and, for exclusive classes, anyone active in another exclusive class of the same year.
4. **Assign:** `POST edu/admin/classes/{id}/assign {user_ids[], program}` runs in a transaction and locks the class row and the users' enrollment rows. It inserts, catches the unique violation, and returns a per-user result: `assigned`, `already_in_class`, `in_other_class` (with that class's name) or `not_eligible`. It writes a journey event `assigned` and an audit entry.
5. **Transfer and promote:** `POST edu/admin/enrollments/{id}/transfer {target_class_id, reason}` marks the old row `withdrawn` (status with a reason) and creates the new row in one transaction. Promotion assigns into a class of the next year with the same rule. Permission: `education.register` to assign, and `education.manage` to transfer or promote.
6. **App:** an "Assign students" screen opened from the class. It has a search box and group filter, a multi-select list, an Assign button and per-user results. Assigned students drop out of the list immediately and stay out after a refresh, since the server is the source. Class roster and history tabs reuse the journey endpoint.

### Expected behavior and output
- An admin picks 5 students for Grade 5 (2019) and presses Assign. The response is `{assigned:[…5]}`, the list shrinks by 5, and the roster shows them.
- The same students no longer appear on the Grade 6 (2019) list but do appear on the Grade 6 (2020) list.
- Database: active rows carry `exclusive_key`. A second insert fails at the unique index even if the app is bypassed.

### Errors and edge cases
- Two admins assign the same student at once: one wins, and the other gets `in_other_class`.
- A class with `allow_multiple=1` (an authorised exception): its enrollments carry `exclusive=0` and don't block.
- A withdrawn student is available again. A class that is not active gives `CLASS_NOT_ACTIVE`.

### Files
`EduRegistration.php` (reuse `register` internals), `EduRequests.php` (the transfer path must respect the key), `EduJourney.php`, a migration, `routes/api/edu.php`, `edu_registration.dart` or a new `edu_assign.dart`, the repository and the ARB files.

### Acceptance criteria
- [ ] A direct SQL insert of a second active exclusive enrollment for the same user and year fails.
- [ ] The assignable list never contains someone the assign call would reject as `in_other_class`.
- [ ] A transfer leaves the old row withdrawn with its reason, a new active row, a journey entry and an audit entry.
- [ ] Existing enrollments (2 live) are unchanged.

---

## F3 · Courses, teachers, eligibility and physical programs — Partial

**Purpose:** The same catalogue subject can be taught to several classes and periods, each with its own teachers and eligible groups. A physical course is linked to the scheduled Sunday-school programs where it meets.

### Current status
- `edu_courses` belongs to one class (`class_id`) and links to a catalogue subject (`subject_id`, never set automatically). `edu_course_teachers` (many teachers, with status) and `edu_course_enrollments` (UNIQUE user, course) exist.
- `edu_schedule` holds weekly class meeting rules separately from `programs`.
- There are no eligible groups per course and no link between a course and a program.

### Implementation steps
1. Keep "class course" = `edu_courses` row (the class + subject offering), which already lets the same subject be reused in many classes. Add `term_id` (nullable), `member_groups` (CSV of `member_groups.key`, empty meaning everyone in the class), `mode` enum(physical, online, hybrid) default physical, and `pass_mark` decimal(5,2) default 50 (used by F10).
2. New table `program_edu_courses`(program_id, course_id) with a UNIQUE pair. It is set from the program editor when "Education program" is ticked (shared with F4).
3. Course roster = active class enrollments whose member group matches `member_groups`, plus explicit `edu_course_enrollments` (for online or distance learners). This is computed in `Edu::rosterQuery`, which already exists, so it is extended rather than duplicated.
4. App course editor: add the Mode, Term, Eligible groups (multi-select from `MemberGroups.keys()`) and Pass mark fields. The course page shows linked programs.

### Expected behavior and output
- "Liturgy" can be offered to Grade 5 and Grade 6. Each has its own teachers, roster and marks. The catalogue subject and lessons are shared.
- The course detail API adds `mode`, `term`, `member_groups`, `pass_mark` and `programs:[{id,title}]`.

### Errors and edge cases
- Unknown group key: `INVALID_MEMBER_GROUP`.
- A pass mark outside 0–100: validation error.
- Linking a program to a course of an archived class: `CLASS_NOT_ACTIVE`.

### Files
`Edu.php` (createCourse, updateCourse, rosterQuery, courseDetail), a migration, `EduSchemas.php`, `edu_manage.dart`, `programs_admin.dart` (program editor).

### Acceptance criteria
- [ ] The same subject is offered to two classes with independent rosters and marks.
- [ ] A youth-only course roster excludes child members of the class.
- [ ] Existing courses keep working with mode physical, all groups and pass mark 50.

---

## F4 · Class attendance through programs — Missing

**Purpose:** Education attendance uses the HR session system: the same taker, Start, signatures and offline sync. One program date can serve several classes. Only enrolled students of those classes can be recorded.

### Current status
- A separate tool, `Edu::mark` / `markByQr`, writes to `edu_attendance` (class_id, session_date, status, via), with its own sync ops `edu_attendance.set`/`scan`.
- App entry points to `/edu/attendance/:classId`: `edu_home.dart:104`, `edu_manage.dart:572`, and `edu_screens.dart:182`, `:334` and `:875`.
- Selection reads `edu_attendance` (`Selections.php:341`). Dashboards read `Edu::attendanceSummary`, and `Choir.php` reads it too.
- Programs have no class link.

### Implementation steps
1. **Migration:**
   - `program_edu_classes`(program_id, class_id) with a UNIQUE pair.
   - `attendance_edu_classes`(attendance_id, class_id) with a UNIQUE pair.
   - A setting `edu.attendance_cutover` (date). It defaults to the release date and decision D5 confirms it.
2. **Program editor:** when the category is an Education one, or a new "Education program" switch is on, show a multi-select of active classes for the current year. Save through `Programs::update`. This needs `programs.manage` plus `education.manage` to pick classes. Audit the change.
3. **Expected members:** in `Attendance::expectedMembers()`, if the program has linked classes, the expected set is the union of active enrollments of those classes in the occurrence's academic year, filtered by course eligible groups where a course is linked. A student in two linked classes appears once.
4. **Recording:** in `Attendance::set()`, after the existing checks, insert one `attendance_edu_classes` row per linked class the student is enrolled in, all in the same transaction. A student not enrolled gets `MEMBER_NOT_EXPECTED`, which is the existing code. There is still exactly one attendance row per member and date, so nothing is duplicated.
5. **Offline pack** (`OfflinePack::programs`): `participant_ids` for class-linked programs come from those enrollments, so the phone's check matches the server.
6. **Freeze the old tool:**
   - Remove the 5 app entry points. Keep the class attendance summary as a read-only history view.
   - The server's `Edu::mark` / `markByQr` return `EDU_ATTENDANCE_MOVED` (410) for dates on or after the cutover.
   - The `edu_attendance.*` sync ops coming from old app queues go to the HR conflict queue as kind `legacy_class`, never dropped.
7. **Read paths:** `Edu::attendanceSummary`, the dashboard and selection combine `edu_attendance` (before the cutover) with session attendance joined through `attendance_edu_classes` (from the cutover). Absent means an occurrence of a linked program where the member was expected and no record exists after the session ended.
8. **Reports:** the per-date export gains a "Classes" column. The aggregate attendance report gains a class filter.

### Expected behavior and output
- The Sunday 09:00 program is linked to Grade 5 and Grade 6. The roster lists only their enrolled students, and the taker records with signatures exactly as for Mezmur.
- A Grade 7 student scanned gets "Not expected at this program".
- The class page shows the attendance rate from both sources. The report row for a member shows "Grade 5".

### Errors and edge cases
- Two programs at the same time for different classes: they are separate occurrences and sessions with no conflict.
- A student transferred mid-term: expected only in occurrences while their enrollment is active on that date.
- A class archived after the attendance: its history is kept, and it can't be picked for new programs.

### Files
`Attendance.php`, `Programs.php`, `OfflinePack.php`, `Sync.php`, `Edu.php`, `EduDashboard.php`, `Selections.php`, `Choir.php`, `ReportExport.php`, a migration, `programs_admin.dart`, `edu_home.dart`, `edu_manage.dart`, `edu_screens.dart`.

### Acceptance criteria
- [ ] Only enrolled students of the linked classes can be recorded, online and offline.
- [ ] A student in two linked classes produces one attendance row and two class links.
- [ ] No Education screen offers the old attendance tool. The 6 live `edu_attendance` rows still count in summaries.
- [ ] An old-app `edu_attendance.set` after the cutover lands in HR review.

---

## F5 · Selection: monthly contribution range — Defect

**Purpose:** Each selection cycle sets a start month, an end month and an Ethiopian year for contribution scoring. The admin sees the percentage and the month-by-month counts.

### Current status: evidence
- `Selections.php` (around lines 574–635) already computes paid months ÷ months in range from `contribution.start_month`, `end_month` and `year`, with a per-month detail. Exempt members score 100.
- `routes/api/selections.php` validates `'contribution' => Z::object(['late_credit' => …])->strict()`, which rejects `start_month`, `end_month` and `year`. They can never be saved, and the app editor has no fields for them.

### Implementation steps
1. Route schema: allow `start_month` and `end_month` (int 1–13, nullable) and `year` (int, nullable). Add a refine: both months set or both null, and start ≤ end, otherwise `MONTH_RANGE_INVALID`.
2. `Selections::mergeConfig` already keeps the keys. Add a test that saving and reloading round-trips them.
3. App (`selections_admin.dart`): add Year, From month and To month pickers using Ethiopian month names (the existing period labels), plus a live sentence such as "Counts Meskerem–Tir 2019 (5 months)".
4. The result detail screen shows paid, unpaid and total months, the list of months, and "paid after due month" counted as paid (decision D4).

### Expected behavior and output
- Meskerem–Tir 2019 saved. A member with 4 of 5 months paid gets `contribution.percent = 80` and `detail.total_months = 5`. The result screen and the export show the same figures.

### Errors and edge cases
- No range set: the selection's own from–to dates are used, as today.
- A missing payment record counts as unpaid and is never assumed paid.
- Editing the range after finalization is refused. Finalized results keep the config they were computed with (F6).

### Acceptance criteria
- [ ] PATCH with `start_month` and `end_month` is accepted, stored and returned.
- [ ] The percentage equals paid ÷ months in range on a fixture with 5 months and 4 paid.
- [ ] Selections without a range compute exactly as before (regression test).

---

## F6 · Selection: attendance categories and elapsed-time intervals — Partial

**Purpose:** Mezmur attendance and Education attendance are each scored from chosen categories or classes. Each record earns a percentage according to the minutes between Start and the member's capture time. The two scores stay separate, and finalized results record the config version they used.

### Current status
- `Selections::attendancePart()` averages per-occurrence points for `mezmur.category_ids`, plus included and excluded programs. The points per status come from `config.attendance` (present, excused, absent).
- Education attendance comes from `edu_attendance` through `education.class_ids` and `course_ids`.
- Since 1.5.3+16 every new record stores `elapsed_seconds`, but nothing reads it for scoring.
- The `selection_config_versions` table and `selection_results.config_version_id` exist but are unused, left over from the withdrawn department criteria.

### Implementation steps
1. **Config shape** (stored in `holiday_selections.config`), as JSON:
   ```
   attendance_rules: {
     mezmur:    { category_ids:[…], intervals:[{from:0,to:15,percent:100},{from:15,to:30,percent:70}], after_last_percent:0 },
     education: { class_ids:[…], course_ids:[…], intervals:[…], after_last_percent:0,
                  overrides:[{class_id:3, intervals:[…], after_last_percent:0}] }
   }
   ```
   Intervals are in minutes and half-open [from, to). The first must start at 0, each next `from` must equal the previous `to`, and percentages are 0–100. Validation errors are `INTERVAL_GAP`, `INTERVAL_OVERLAP` and `INTERVAL_START_NOT_ZERO`.
2. **Per-record percentage:** elapsed = `attendance.elapsed_seconds` ÷ 60, and the matching interval's percent applies. Beyond the last interval, `after_last_percent` applies (D2). Excused uses the existing excused weight (D3). Absent is 0. A legacy record with no session counts as present at 100%, as today.
3. **Component score:** keep the existing average (sum of per-occurrence percentages ÷ number of counted occurrences), computed separately for Mezmur and for Education. There is no combined formula, and the weights, minimums and bonus logic are untouched.
4. **Versions:** every save of the attendance rules while the selection is open writes a `selection_config_versions` row (version + 1, a sha256 of the canonical JSON). Compute uses the latest one. On `finalized`, each `selection_results.config_version_id` is set, and recomputation after finalization is refused.
5. **Explanation:** the result detail lists each occurrence with its date, capture time, minutes after Start, interval and percent, for Mezmur and Education separately.
6. **App:** in `selections_admin.dart`, add two cards, "Mezmur attendance" and "Education attendance". Each has a category or class picker, reusing the Mezmur category picker pattern, plus an interval table editor (add row, from, to, percent) with inline gap and overlap errors and an "After the last interval" field.
7. **Attendance report:** the per-date export's "Minutes after start" column gains an "Interval %" column, shown only to `attendance.reports` holders, when a selection config applies.

### Expected behavior and output
- With intervals 0–15 = 100% and 15–30 = 70% (after the last = 0%), records at 3, 20 and 40 minutes score 100, 70 and 0, so Mezmur attendance is 56.7%. Education is computed the same way from its own classes and intervals.
- The finalized result shows "Config v3". The export reproduces the same numbers.

### Errors and edge cases
- No intervals configured for a category: that component reports `not_configured` and is not scored as zero.
- An offline record with a device time: its `elapsed_seconds` already uses the clock-corrected time.
- HR accepts a conflict later: a recompute picks it up if the selection is still open.

### Files
`Selections.php`, `routes/api/selections.php`, `SelectionReports.php`, `ReportExport.php`, `selections_admin.dart`, `eligibility_screen.dart`, the ARB files.

### Acceptance criteria
- [ ] Gapped or overlapping intervals are refused with field errors, and valid ones save as a new version.
- [ ] The score uses the official Start, not the scheduled start, on the 11:00 / 11:15 example from the requirements.
- [ ] Mezmur and Education scores differ when their intervals differ.
- [ ] The finalized results' `config_version_id` points to the version used, and recompute is refused after finalization.
- [ ] Existing selections without attendance rules compute exactly as before.

---

## F7 · Platform-wide offline, including administrators — Partial

**Purpose:** Every page a user has opened before works offline from the last sync, with a clear offline state, the last-sync time and the pending changes. Cached admin data is protected and role-checked.

### Current status
- `ApiClient._resilientGet` answers GETs from `_DbResponseCache` (`core/providers.dart`) when offline. The cache table is plain JSON in SQLite, kept 45 days and wiped at sign-out.
- The `OfflineBanner` (`widgets/states.dart`, shown from `app/shell.dart:97`) reads "offline — downloaded mezmurs are available" and shows no time or pending count.
- Queued writes cover attendance, borrowing, tasks, reminders, favorites, preferences and activity.
- Cached admin responses are not encrypted. Role checks happen only on the server, so a demoted admin could still read the old cache offline until sign-out.

### Implementation steps
1. **Sync status provider:** tracks `lastSuccessfulSync` (the time of the last successful flush plus pack refresh, stored in prefs), `pendingCount`, the flush-in-progress state and the last error.
2. **Banner:** replace the text with "Offline · last synced 14:05 · 3 changes waiting". Tapping it opens a "Sync status" sheet listing pending ops by type with their capture times, a Retry button and the last error.
3. **Protected cache:** responses from `/admin`, `/edu/admin`, `/reports`, `/attendance/`, `/payments`, `/selections` and `/users` paths are stored sealed with the same AES-GCM keystore key as `QueueSeal`. Each cache row stores the permission set hash of the user when it was saved, and a read is refused if the current user's permissions no longer include the route's permission. Permissions are refreshed at each online start.
4. **Offline-capable actions:** each screen marks its write buttons. Supported writes queue (D9). Unsupported ones show "Needs a connection" disabled, never a working-looking button.
5. **Ordering:** the queue already flushes in rowid order. Keep it, and add a dependency rule so a session End is never sent before its queued records (already true by order). Document it in tests.
6. **Never claim server confirmation early:** rows stay marked "waiting" until the server answers `applied` or `duplicate`.

### Expected behavior and output
- An admin opens Members, Reports and Selections online, then goes offline. All three open from the cache with the banner showing the last sync time. Edit buttons show "Needs a connection".
- After their admin role is removed and they open the app online once, offline admin pages show "Not available for your account".

### Errors and edge cases
- A page never opened online shows "Not saved for offline use yet" plus a Retry button, not a spinner.
- The keystore key is lost: sealed cache rows are dropped and refetched next time online.
- A deleted record is answered from the cache while offline, and the next online fetch returns 404, which removes it.

### Files
`core/network/api_client.dart`, `core/providers.dart`, `core/storage/local_db.dart`, `services/sync_service.dart`, `widgets/states.dart`, `app/shell.dart`, admin screens (button states), the ARB files, tests.

### Acceptance criteria
- [ ] Offline, the banner shows the correct last-sync time and pending count on every page.
- [ ] Admin cache rows contain no readable personal data in the SQLite file (test reads the raw row).
- [ ] A permission removal blocks cached admin pages offline.
- [ ] No write button that cannot work offline is enabled offline.

---

## F8 · Online learning: remaining gaps — Done + gaps

**Purpose:** The structured lessons released in 1.5.3+15 need access by enrollment, optional prerequisites and per-course completion rules for certificates.

### Current status
- These exist: `edu_categories`, `edu_subjects` (with `visibility` and `sequential`), `edu_units`, `edu_lessons`, `edu_lesson_materials`, `edu_lesson_progress` and quizzes. `EduLearning.php`, the Learn screens, resume and bookmarks are in place.
- Missing: a "mandatory lesson" flag (needed by F13), online or distance enrollment as the access rule for online courses, and completion percentage per course offering.

### Implementation steps
1. Add `edu_lessons.is_mandatory` tinyint default 1.
2. For `mode` online or hybrid courses (F3), lesson access requires an active class enrollment for the course or an `edu_course_enrollments` row (distance or retake). `visibility = all` subjects stay open to every member as today.
3. Add `EduLearning::courseCompletion(userId, courseId)`, returning mandatory completed ÷ mandatory published.
4. Keep `sequential` as the prerequisite rule: a lesson unlocks when the previous mandatory lesson is completed. The existing `LESSON_LOCKED` code applies.

### Acceptance criteria
- [ ] A non-enrolled member gets 403 `NOT_ENROLLED` on an online course's lesson. The app shows the course as "Not enrolled" rather than an error.
- [ ] Completion counts only mandatory published lessons.

---

## F9 · Assignments — Partial

**Purpose:** Teachers publish assignments for their own courses with a publish time, due date and late rules. Students submit text or files, see their history and resubmit when allowed.

### Current status: evidence
- `Edu::createAssignment` stores the title, instructions, `due_at`, `max_score`, `is_group` and one attachment. It notifies the class at once.
- `Edu::submit` checks the roster and the group. It allows overwriting until graded (`ALREADY_GRADED`) and **never checks `due_at`**.
- Teacher ownership is checked by `assertTeaches`.
- There is no publish time, no late rule, no per-student target and no submission history (an overwrite replaces the file).

### Implementation steps
1. Add to `edu_assignments`: `publish_at` (null = now), `late_policy` enum(refuse, accept_marked) default refuse, `late_until`, `allow_resubmit` tinyint default 1, `target_user_ids` JSON (null = whole roster) and `status` enum(draft, published, archived).
2. New table `edu_submission_versions`(id, submission_id, text, file, file_name, submitted_at, is_late), written on every submit. The current row keeps pointing to the latest version.
3. Submit checks the following in order:
   - The assignment is published and `publish_at` has passed (`ASSIGNMENT_NOT_OPEN`).
   - The student is a target.
   - Before `due_at`: the submission is accepted.
   - After `due_at`: refused with `DEADLINE_PASSED`, or accepted with `is_late=1` until `late_until`, according to `late_policy`.
   - A resubmission when `allow_resubmit` is 0 gives `RESUBMIT_NOT_ALLOWED`.
4. Notifications go out when the assignment is published (a queued job or the existing reminder runner, `runClassReminders`, when `publish_at` passes), 24 hours before the due date to non-submitters, and when grading is done.
5. App: the editor gains publish time, late policy, resubmission and target students. The student view shows a status chip (Not submitted, Submitted, Late, Graded) and a version history.

### Acceptance criteria
- [ ] A submission after the due date is refused (refuse policy) or flagged late (accept policy), checked on the server.
- [ ] A teacher of another course gets 403 on create and update.
- [ ] Every resubmission keeps the earlier version. Existing assignments migrate as published with refuse policy and the same behavior.

---

## F10 · Course outcomes and pass marks — Missing

**Purpose:** Turn published marks into a finalized course outcome (passed or failed, with a percentage) using the class course's pass mark. The default is 50% of the published weighted total.

### Current status
- `edu_assessments` (weight, max_score), `edu_scores` (status draft → submitted → approved → published) and `EduMarks` (submit, review, publish, amend, history) exist with `edu_score_history`.
- There is no pass mark and no outcome table.

### Implementation steps
1. New table `edu_course_outcomes`: id, course_id, user_id, attempt_type enum(original, retake), retake_id nullable, percent, pass_mark, result enum(passed, failed, incomplete), status enum(provisional, finalized, superseded), counts_for_progression tinyint, finalized_by, finalized_at, note, timestamps. UNIQUE(course_id, user_id, attempt_type, retake_id).
2. `EduOutcomes::compute(courseId)` computes weighted percent = Σ(score ÷ max × weight) ÷ Σ weight over **published** scores only. It is `incomplete` if any assessment lacks a published score. It writes or updates `provisional` rows.
3. `finalize(courseId, userIds)` (permission `education.manage`) freezes the rows. A failed or incomplete outcome can never be finalized as passed. Changing a finalized outcome requires amending marks through `EduMarks::amend`, then a recompute that creates a new row and marks the old one `superseded`, with the reason kept.
4. App: a course "Results" tab for admins (compute, review, finalize). Students see the finalized outcome only.

### Acceptance criteria
- [ ] Unpublished marks never affect an outcome.
- [ ] Weighted totals on a 3-assessment fixture equal hand-calculated values.
- [ ] A finalized outcome cannot be edited directly. An amendment keeps the old row as superseded.

---

## F11 · Failed courses and online retakes — Missing

**Purpose:** Admins can approve an online retake for a failed student. The retake is tracked separately, and the admin decides which result counts.

### Implementation steps
1. New table `edu_retakes`: id, original_outcome_id, user_id, course_id, status enum(requested, approved, rejected, active, completed, cancelled), requested_by, decided_by, decided_at, decision_note, timestamps.
2. The student sees "Request an online retake" on a finalized failed outcome. An admin can also create one directly. Approving creates an `edu_course_enrollments` row (status `retake`) that gives online access (F8). Nothing is automatic.
3. Retake marks use the same assessments and add `edu_scores.attempt` (default 1). Outcomes are computed with `attempt_type=retake`.
4. `setCounting(outcomeId)` sets `counts_for_progression` on exactly one of the original or the retake, with a reason, and writes an audit entry and a journey event.

### Acceptance criteria
- [ ] Only finalized failed outcomes can have a retake. A duplicate active retake gives `RETAKE_EXISTS`.
- [ ] The original marks and outcome are never changed by a retake.
- [ ] Exactly one outcome per course and student counts for progression.

---

## F12 · Online exams and question banks — Partial

**Purpose:** Build on quizzes to add question banks, random draws, result release times and exam reports.

### Current status: evidence
- `edu_quizzes` has opens_at, closes_at, time limit, max_attempts, scoring, shuffle, review_policy and status. `edu_quiz_questions` has types single, multiple, true_false and short_text. Attempts carry `expires_at`, auto and manual scores and `needs_grading`.
- `EduQuizzes::transfer` sends scores to the score sheet as drafts. Unique (quiz, user, attempt_no) prevents duplicate attempts.

### Implementation steps
1. New table `edu_question_banks`(id, subject_id, title, created_by). `edu_quiz_questions` gains `bank_id` (nullable, with `quiz_id` becoming nullable) so a question lives in a bank or in a quiz.
2. New table `edu_quiz_draws`(quiz_id, bank_id, count, points_each). On attempt start, select N random question ids per draw and store them on `edu_quiz_attempts.question_ids` JSON, so a resumed attempt shows the same questions.
3. Add `results_release_at` to quizzes. Correct answers and explanations are hidden until then, extending the `review_policy` check in `EduQuizzes`.
4. Add `kind` enum(quiz, exam) to quizzes. An exam requires `assessment_id` and allows one attempt by default.
5. Exam report: participants, attempts, scores and grading changes, through `ReportExport` (PDF, Excel and CSV, each verified).

### Acceptance criteria
- [ ] Two students drawing from a bank of 30 get the configured count. Resuming shows the same set.
- [ ] Answers are not in any API response before `results_release_at` (test the JSON).
- [ ] A submit after expiry is refused. A double submit returns the first result.

---

## F13 · Certificates and verification — Missing

**Purpose:** Issue a certificate only for a finalized passing outcome, plus all mandatory lessons for online courses. Each has a unique number and can be verified, and revocations keep their history.

### Implementation steps
1. New table `edu_certificates`: id, number (unique, `MH-{eth_year}-{000123}`), verify_code (random 10 characters, unique), user_id, course_id, outcome_id, issued_at, issued_by, status enum(valid, revoked, replaced), replaced_by, revoked_reason, pdf_path, snapshot JSON (name, member ID, course, date, signatory as printed).
2. `EduCertificates::eligible(courseId)` requires a finalized passed outcome with `counts_for_progression`, plus `courseCompletion = 100%` for online and hybrid courses. `issue(userIds)` refuses anyone ineligible (`NOT_ELIGIBLE`) and never issues automatically.
3. The PDF uses the existing branded PDF renderer in `ReportExport` (the same library) with a certificate layout. It is stored privately.
4. Public verification: `GET /verify/{code}` (web page) and `GET api/v1/certificates/verify/{code}` return valid or revoked, the name, course and date, and nothing else.
5. Revoke and correct (permission `education.manage`, new key `education.certify`): revoke with a reason, or reissue as a new number with the old one marked `replaced`. Both are audited.

### Acceptance criteria
- [ ] An ineligible issue is refused on the server even if the app is bypassed.
- [ ] Verification shows "Revoked" after revocation, and the old number links to the replacement.
- [ ] The PDF opens in a viewer and its number and code match the database.

Blocked by decision D7 (wording and signatory).

---

## F14 · Student dashboard — Partial

**Purpose:** One screen with the student's real Education status.

### Current status
`EduDashboard::forUser` already returns classes, continue-learning, subjects, assignments due, quizzes, results, attendance summaries, next sessions and role blocks (teacher, admin, registrar, content editor).

### Implementation steps
1. Add these blocks: academic year, term and level (F1); outcomes, both original and retake (F10, F11); certificates (F13); approved retakes; and attendance from both sources (F4).
2. Each block has its own loading, empty and error state in the app, reusing the existing widgets in `edu_widgets.dart`.

### Acceptance criteria
- [ ] Every number on the dashboard equals the corresponding detail screen's number for the same fixture.
- [ ] A student with nothing gets empty states with guidance, not zeros pretending to be data.

---

## F15 · Admin activity and academic/engagement scores — Missing

**Purpose:** Two separate, auditable scores that only authorised administrators can see.

### Current status
`edu_journey` (enrollment and mark events), `activity_logs` (app events) and `edu_lesson_progress` exist. There are no scores and no Education activity report.

### Implementation steps
1. New permission `education.reports` (granted to the roles holding `education.manage`).
2. `EduScores::forPeriod(yearId, termId, classId, courseId, group)` computes the two scores from database rows (D8). It counts only lessons, assignments and quizzes the student could access (enrolled, published, open during their enrollment) and excludes approved absences.
3. The admin screen is a sortable table with academic score, engagement score and the underlying counts. Each row opens an explanation. Export goes through `ReportExport`. There is no student-facing ranking.
4. An activity report shows lesson opens and completions, submissions, attempts and certificates by period and class, drawn from existing tables only. Security logs stay excluded.

### Acceptance criteria
- [ ] Recomputing a student's scores by hand from their rows gives the same figures (test).
- [ ] A member without `education.reports` gets 403.
- [ ] Inaccessible activities don't lower anyone's score.

Formula decision: D8.

---

## F16 · Digital library — Partial

**Purpose:** Education books get categories, favorites, reading progress, a better in-app reader, secure offline copies and optional narration (ትረካ).

### Current status: evidence
- Digital books are `items` rows with `kind=digital`, `domain=timhirt` and `file_path`. `Library::books()` lists them with one flat `category` string.
- `BookVault` keeps downloads AES-GCM encrypted and wipes them at sign-out. `BookReaderScreen` uses `pdfrx` `PdfViewer.data` with text selection disabled. It has no page memory, no search, no favorites and no narration.

### Implementation steps
1. New table `library_categories`(id, parent_id, domain, name, name_en, code, sort_order). `items` gains `library_category_id`. Existing `category` strings are migrated into categories, and the strings are kept.
2. New tables `library_favorites`(user_id, item_id) and `library_progress`(user_id, item_id, page, page_count, audio_position_ms, updated_at), plus a sync op `library.progress` so progress saves offline.
3. Narration: `items` gains `narration_path`, `narration_mime` and `narration_duration`, uploaded by admins. The player is the existing `just_audio` + `just_audio_background` setup through a library-specific audio source, without the Mezmur playlist.
4. Reader upgrade (keeping `pdfrx`): restore the last page, add search with `PdfTextSearcher` (text extraction stays in memory), a page-number jump and zoom (already built in), and landscape support. Show the download size and status on the book page. Offline availability = `BookVault.has` only, never favorites.

### Acceptance criteria
- [ ] Reopening a book lands on the saved page, offline too.
- [ ] A favorited but not downloaded book shows "Download to read offline".
- [ ] Narration plays in the background with lock-screen controls and resumes at the saved position.
- [ ] Mezmur playback is unaffected (regression test).

---

## F17 · Physical Sunday-school library — Partial

**Purpose:** Departmental books get stable per-copy IDs and a separate checkout and return workflow run by library staff with the borrower's signature. Loans are kept apart from property borrowing.

### Current status: evidence
- Physical books are `items` rows (`kind=physical`, quantity and available_quantity). `Library::issue` creates an ordinary `borrowings` row with a `borrowing_signatures` record, so library loans currently mix with property loans.
- `item_categories.code` exists. There are no copy records.
- The Education More screen links to the library (`progress_more.dart:182`). The Education home has no borrowing shortcut left to remove.

### Implementation steps
1. New table `library_copies`: id, item_id, copy_no, copy_code (unique, `LIB-{category code at creation}-{book number}-{copy}`, stored and never recalculated), condition, location, status enum(available, on_loan, lost, withdrawn), timestamps.
2. New table `library_loans`: id, copy_id, user_id, checked_out_at, due_on, returned_at, condition_out, condition_in, issued_by, received_by, signature_path, sha256, notes, status. A generated column plus a UNIQUE key on (copy_id while the loan is open) stops two loans of one copy.
3. `LibraryCirculation` service: checkout (scan or enter the copy code, verify the borrower by QR or search, capture the signature with the existing `captureSignature`), return, overdue list, history. New permission `library.circulate`, separate from `borrowing.manage`.
4. Move existing books (D6): create copies equal to `quantity`. Open `borrowings` stay in `borrowings` until returned and are shown in the copy history as "legacy loan".
5. Members see availability per book (copies available ÷ total) and can't mark anything borrowed. The existing request flow stays as an optional "hold" request.
6. Offline: the checkout and return sync ops are added to the queue (D9). The server refuses a copy already on loan and sends the conflict to the library review list.

### Acceptance criteria
- [ ] Renaming or moving a category never changes an existing `copy_code`.
- [ ] Two simultaneous checkouts of one copy: one succeeds and the other gets `COPY_ON_LOAN`.
- [ ] New library loans never appear in property borrowing reports, and property reports are unchanged.
- [ ] Overdue and inventory reports export in PDF, Excel and CSV, each verified.

---

## F18 · Shared Settings, filtered by module — Partial

**Purpose:** There is one Settings destination. Shared settings always show, and module tools show only for the module the user came from.

### Current status
`features/settings/settings_screen.dart` is shared. The Education group (lines 113–121: course management, registrations, content) appears from Mezmur too, and Mezmur-specific tools appear from Education.

### Implementation steps
1. Open Settings with `?from=mezmur|edu|hub` (existing go_router routes). Mezmur's More passes `mezmur` and Education passes `edu`.
2. Group tiles as shared (account, theme, language, notifications, sessions), Mezmur tools and Education tools. Show module groups only for the matching `from`. From the hub, show both with headers. Admin tiles keep their permission checks.
3. Back returns to the module the user came from.

### Acceptance criteria
- [ ] Settings opened from Education shows no Mezmur-only tools, and the reverse.
- [ ] Theme and language changes made from either entry apply everywhere (same prefs).

---

## F19 · Education editing pen — Missing

**Purpose:** The Mezmur edit mode is reused in Education. Pen and + controls appear in place only for users who hold the matching content permission.

### Current status
`features/admin/edit_mode.dart` provides `editModeProvider`, `EditModeToggle` and `editingWith(ref, perm)`. They are used only in `home_screen.dart` and `programs_screen.dart`. Education editing happens in separate screens (`/edu/content`).

### Implementation steps
1. Generalise `canEditFront` to take a module. For Education it checks `education.content`, `education.manage`, or the teacher-of-subject rule already enforced in `EduLearning`.
2. Put the `EditModeToggle` in the Education top bar. Pens on category, subject, unit and lesson cards open the existing editors. A + on lists creates items.
3. Delete stays in the editors, behind confirmation and the existing `HAS_RECORDS` archive rule.

### Acceptance criteria
- [ ] A user without edit permission sees no toggle and no pens.
- [ ] A teacher sees pens only on subjects they teach. A pen action refused by the server shows the error and changes nothing.

---

## F20 · Role-specific guidance — Partial

**Purpose:** Short in-context help for students, teachers, admins, HR and librarians that describes only what that user can actually do.

### Current status
The guidance system (`GuidanceSeeder.php`, `guidance_catalog.dart`, the contextual help sheet and the tour engine) works, and it already has permission-filtered articles. The attendance articles were updated in 1.5.3+16.

### Implementation steps
1. For each feature shipped, add articles for its screens to both `GuidanceSeeder.php` and `guidance_catalog.dart`, with `required_permission` set. Coverage: class assignment, academic calendar, class-linked programs, selection intervals, the offline status sheet, assignments, results and retakes, exams, certificates, the digital library and narration, circulation, and scores.
2. Empty states on the new screens explain the first action, for example "No copies yet — add the first copy".
3. Add a test that every route listed in `guidance_navigator.dart` has an article, and that no article's permission is missing from `Catalog.php`.

### Acceptance criteria
- [ ] A student never sees admin guidance. Each new screen has a help button that opens its own article.

---

## F21 · Responsive design and accessibility — Partial

**Purpose:** No overflow and readable Amharic and English from 360 dp phones to tablets and web. Admin tables adapt instead of squeezing.

### Current status
Overflow tests at 360 dp and 130% text exist for the Learn screens (`edu_learning_test.dart`) and the roster (`attendance_session_test.dart`). That test found and fixed the shared signature pad overflow. Admin lists and reports are not covered.

### Implementation steps
1. A shared test helper pumps a screen at 360×740, 412×892 and 1024×768, at text scale 1.0 and 1.3, in Amharic and English, and fails on any RenderFlex overflow.
2. Apply it to every new screen in F1–F19 and to the existing admin lists. Wide layouts (≥ 900 dp) show tables, and phones show cards.
3. Every icon-only button has a tooltip or semantics label, and tap targets are at least 44 dp.

### Acceptance criteria
- [ ] Every new screen passes the overflow matrix in CI (`flutter test`).
- [ ] The web build shows admin tables at desktop width without horizontal page scroll.

---

## Build order and releases

Each release can be deployed on its own, gets a DB backup first, and is followed by a phase report.

| Release | Contents | Why this order | Needs |
|---|---|---|---|
| 1.5.3+17 | F0a, F5 | Stops data loss; fixes a one-line schema defect. | D1, D4 |
| +18 | F1, F2, F3 | Everything academic depends on years and enrollments. | — |
| +19 | F4, F6 | Class attendance needs F1–F3, and scoring needs both sources. | D2, D3, D5 |
| +20 | F7 | Offline for everything, built on the stable data shapes. | D9 |
| +21 | F8, F9, F10, F11, F12 | The results pipeline. | — |
| +22 | F13, F14, F15 | Need finalized outcomes. | D7, D8 |
| +23 | F16, F17 | Libraries are independent of the academic chain. | D6 |
| +24 | F18, F19, F20, F21 | Polish across all the screens added before. | — |

> The regression checks you required run on every release: Mezmur playback, borrowing signatures, contribution calculation, selection finalization, every report export (PDF, Excel and CSV opened individually), attendance sessions and offline sync.
