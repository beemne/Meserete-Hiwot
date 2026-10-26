# Holiday Service Selection: How It Works

This guide explains how members are selected for a holiday service, who does what at each step, and how the score is calculated. It describes the system as deployed on 14 October 2026 (app 1.5.3, build 13).

## Who does what

| Role | Responsibilities |
|---|---|
| **High admin** (holds *Finalize selection*) | Creates the selection, sets the passing rules and the monthly range, approves or rejects the criteria, finalizes and publishes. |
| **Education admins** | Divide the **50 Education points** into categories, assign evaluators, approve Education scores. |
| **Mezmur admins** | Divide the **30 Mezmur points** into categories, assign evaluators, approve Mezmur scores, download the Mezmur report. |
| **Due-collection approvers** | Set up the **10 monthly-dues points** and approve its scores. |
| **Each department's administrators** | Record their members' participation score every month (the **10 participation points**). |
| **Evaluators** | Enter scores for the manual categories they are assigned to (interview, practical test, …). |
| **Review departments** | Hymns & Arts, Education & Training and Human Resources each approve the results before finalization. |

### Who counts as a part's administrator

Each part is prepared by people who hold its permission through a **specific role** (for example an Education department role), by a **direct grant**, or by **being an administrator of that part's own department**:

| Part | Permission | Own department |
|---|---|---|
| Education (50) | Manage education | Education and Training (EDU) |
| Mezmur (30) | Manage choir / Mezmur | Hymns and Arts (HYM) |
| Monthly dues (10) | Record monthly payments | Finance and Property (FIN) |

General admin roles (Admin, High admin, System) do **not** make someone a part's administrator on their own, even though they hold almost every permission. This keeps each department in charge of its own share. If a permission is revoked for one person, that person loses the part even if their role or department would grant it.

The criteria page shows **"Prepared by: …"** under each part. If it shows **"Nobody can prepare this part yet"** in red, assign an administrator to that department before continuing. Otherwise the criteria can never be completed.

## The 100 points

The split is fixed by policy and nobody can change it:

| Part | Points | What it measures |
|---|---|---|
| Education | 50 | Class attendance, exams, and any Education categories (interview, …) |
| Mezmur | 30 | Mezmur attendance and any Mezmur categories (knowledge, practical test, …) |
| Monthly dues | 10 | Months paid within the monthly range |
| Department participation | 10 | Average of the monthly participation scores within the monthly range |

The selection's own settings also refuse weights that break the 50 / 30 / 10 / 10 split.

## Step by step

### 1. Create the selection (high admin)

Set the name, the date range and the member groups that can apply. A selection that never starts department criteria uses the older fixed scoring (class attendance 25, exams 25, Mezmur attendance 30, dues 10, participation 10, passing score 43).

### 2. Prepare the criteria (each department)

Open **Admin panel → Selection criteria** and pick the selection. The first draft starts from the selection's own settings: its passing score, its minimums, and its weights fitted to the split.

Each part's administrators edit only their own part. They divide their share into **categories**:

- **Automatic categories** reuse the data the system already has: class attendance, exams, Mezmur attendance, dues paid, department participation. Each automatic source can be used only once in the whole configuration.
- **Manual categories** (interview, practical test, knowledge assessment, …) are scored by evaluators out of any maximum you choose.
- A category may have a **minimum**. A member below it is not eligible, whatever their total.
- A category can be switched off; it is kept but not counted.

A part can be **submitted** only when its categories add up exactly to its share (for example 20 + 30 = 50 for Education). The department participation part needs no setup and is always complete.

### 3. Rules, monthly range and approval (high admin)

Under **Passing rules & monthly range** the high admin sets:

- the **passing score** (out of 100);
- **seats** (optional; empty means everyone who passes is selected);
- an optional **minimum per part**;
- the **monthly range**: the months counted for monthly dues and department participation, at most 24 Ethiopian months. Empty means the selection's own dates.

When all three configurable parts are submitted, the version goes to the high admins. **Approve** puts it in force. **Reject** needs a comment and sends every part back to draft.

**Nobody approves their own work:** someone who submitted a part cannot approve the version.

**The selection cannot open until its criteria are approved.**

To change approved criteria, choose **Revise**. That creates a new version; the approved one stays in force until the revision is approved. Every result records the version it was calculated with.

### 4. Manual scores

1. The part's administrators **assign evaluators** to each manual category.
2. Evaluators open the score sheet and enter each applicant's score, or tick **Did not take part** (counted as 0). Scores above the category maximum are refused.
3. Evaluators **submit** the scores.
4. The part's administrators **approve** or **reject** them. Rejecting needs a reason and lets the evaluator correct the scores. Nobody can review scores they entered themselves.

Only approved scores count.

### 5. How results are calculated

While the selection is open, results are recalculated automatically as data arrives:

```
category points = score ÷ category maximum × category weight
                  (automatic categories: percent ÷ 100 × weight)
part score      = sum of its category points
total           = sum of the four parts            (out of 100)
```

- Nothing is rounded before the final comparison and ranking.
- **A missing value is "pending", never 0.** A member with a pending category gets the outcome *pending*, not *failed*.
- A member is **eligible** when the total reaches the passing score and every category and part minimum is met.
- Eligible members are **ranked** by exact score. Equal scores share a rank.
- With seats set, members within the seats are **selected** and those beyond are **eligible but not selected**. Everyone tied at the last seat is selected.

### 6. Review

Moving the selection to **Review** closes the results for checking:

- Each review department (Hymns & Arts, Education & Training, Human Resources) records its approval.
- Admins can **override** a member's result (qualified or not qualified) with a written reason. The override is kept beside the calculated result and recorded in the audit log.

### 7. Finalize and publish

**Finalize** is blocked until:

- every review department has approved, and
- **no member is still pending**: each pending member needs their missing scores or an explicit override.

Finalizing locks the results and the criteria. After that, admins can assign service categories (for example ለወረብ አገልግሎት / ለመዝሙር አገልግሎት) and view category rankings.

**Publish** notifies every member with the message for their group:

- **selected**;
- **eligible, but beyond the number of seats**;
- **not eligible**.

## Reports

From the selection page, the single **download** button offers:

- **Selection report**: every applicant with scores and outcome (PDF, Excel, CSV).
- **Mezmur report**: for Mezmur administrators only. It lists member ID, participation in each Mezmur category, and pass / fail. Pending values are written as *Pending*, never as 0.

## Common questions

**The criteria page says "Nobody can prepare this part yet".**
No one is an administrator of that part. Make someone administrator of the part's department (EDU, HYM or FIN), or give a specific role the part's permission.

**Why can't I submit my part?**
Its enabled categories must add up exactly to the part's share (50, 30 or 10). The total is shown in green when it matches.

**Why can't the selection open?**
Its criteria have not been approved yet.

**Why can't I approve the criteria?**
You submitted one of its parts. Another high admin must approve.

**A member shows "pending".**
A category has no approved value yet: a manual score not entered or not approved, or a month without a participation score. Fill it in, or decide the member's result with an override during review.

**Can I change the criteria after approval?**
Yes. Choose **Revise**, change it, and have it approved again. Results switch to the new version only once it is approved. Criteria of a finalized or cancelled selection never change.

## For developers

| Area | Location |
|---|---|
| Criteria, scoring, ranking | `laravel/app/Mz/Services/SelectionCriteria.php` |
| Selections, evaluation, status flow, publish | `laravel/app/Mz/Services/Selections.php` |
| Mezmur report | `laravel/app/Mz/Services/SelectionReports.php` |
| Criteria API | `laravel/routes/api/selection_criteria.php` (`/selections/{id}/criteria/...`, `/selection-criteria/mine`) |
| Selection API | `laravel/routes/api/selections.php` |
| App screens | `mobile/mobile/lib/features/admin/selection_criteria_admin.dart`, `selections_admin.dart` |
| Tests | `laravel/tests/Integration/SelectionCriteriaTest.php` |

Criteria versions are stored in `selection_config_versions`: `draft → submitted → approved` (or `rejected`), and a previously approved version becomes `superseded` when a revision is approved. The monthly range is `passing.months = {from, to}` (Ethiopian `YYYY-MM`). Manual scores live in `selection_scores`, evaluators in `selection_evaluators`, and results in `selection_results` (`outcome`, `score_exact`, `rank`, `config_version_id`).
