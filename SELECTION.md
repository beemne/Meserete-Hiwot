# Holiday Service Selection: How It Works

This guide explains how members are selected for a holiday service, who does what, and how the score is calculated.

> **Change on 15 October 2026:** the department-based criteria have been withdrawn at the church's request. Under that scheme, Education 50, Mezmur 30, monthly dues 10 and department participation 10 were each prepared and approved by that department's administrators. A selection is again configured in one place, on the selection itself, as described below. The former files are kept in `backups/department-criteria-2026-10-15/`.

## Who does what

| Role (permission) | Responsibilities |
|---|---|
| **Selection configurers** (*Configure selection*) | Create the selection, set its weights, minimums and options, open it, cancel it, choose the review departments. |
| **Exam administrators** (*Selection exams*) | Adjust the exam settings of a selection. |
| **Reviewers** (*Review selection*) | Move the selection to review, record their department's review, and decide exceptions (overrides). |
| **Final approvers** (*Finalize selection*) | Finalize the selection, decide exceptions, publish the results. |
| **Mezmur administrators** (*Manage choir*) | Assign service categories after finalization, download the Mezmur report. |
| **Department leaders** | Record their members' monthly participation score. |
| **Members** | See their own result once published, and send feedback. |

## The score

A selection scores five components. Each has a **weight** and an optional **minimum** (in points). The defaults are:

| Component | Default weight | Default minimum | Measured from |
|---|---|---|---|
| Class attendance | 25 | 10 | Attendance in the member's education classes |
| Exams | 25 | 10 | Approved / published exam marks of the subjects the member takes |
| Mezmur attendance | 30 | 15 | Attendance at Mezmur programs (chosen categories / programs) |
| Monthly contribution | 10 | 3 | Months paid ÷ months due in the period |
| Department participation | 10 | 5 | Average monthly participation score from the member's departments |

The weights must add up to **100**. The default passing score is **43**.

### How it is calculated

```
attendance %   = Σ (program weight × points for the status) ÷ Σ program weights
                 (status points: present 100, late 100, excused not counted, absent 0 — configurable)
component pts  = component % × weight ÷ 100
total          = Σ component points ÷ Σ weights of the counted components × 100
```

- A component with **no data** (for example no exams yet, or exams not required) is **not counted**. The total is scaled over the components that are counted, so a missing component neither helps nor counts as 0.
- **Mezmur service bonus:** up to 30 points from attendance at the chosen service programs. It is given only to members at 100 % Mezmur attendance, and the Mezmur component can never exceed its weight.
- **Monthly contribution:** paid and late payments count as paid. Members exempt from payments get 100 %. The months are the selection's dates unless a specific start / end month is set.
- **Qualified** means the total reaches the passing score and every counted component reaches its minimum.

The calculation is shown on each member's result page, with the shortfall for any failed minimum.

## Step by step

### 1. Create and configure (Configure selection)

Set the name, the date range and the member groups. Under **Configure**, adjust if needed:

- the weights (total 100) and minimums of the five components, and the passing score;
- whether exams are required;
- which classes / subjects count for Education;
- which Mezmur categories and programs count for Mezmur attendance;
- the monthly contribution period and the credit for late payments;
- the service bonus (percentage or fixed points, at most 30);
- the points per attendance status and per-program weights.

### 2. Open

While the selection is **open**, results are calculated for every applicant and recalculated as attendance, marks and payments come in. Admins can recalculate at any time.

### 3. Review

Moving to **Review** starts the checks before finalization:

- Each required review department records **approved** or **rejected**. The defaults are Hymns & Arts, Education & Training, and Human Resources Management; configurers can change the list.
- Reviewers and final approvers can **override** a member's result (qualified / not qualified) with a written reason. The calculated result is kept beside the override, and the change is recorded in the audit log.

### 4. Finalize

A final approver **finalizes** once every required department has approved. Results are then locked. The Mezmur administrators are notified.

After finalization, admins can:

- assign **service categories** (ለወረብ አገልግሎት የተመረጡ / ለመዝሙር አገልግሎት የተመረጡ) and view the **category rankings**;
- **publish**: every applicant is notified that they met, or did not meet, the requirements;
- read **feedback** that members send about the result.

A selection can be **cancelled** while it is draft, open or in review.

## Reports

From the selection page, the **download** button offers:

- **Selection report**: every applicant with component scores and result (PDF, Excel, CSV).
- **Mezmur report** (Mezmur administrators): applicant ID, Mezmur attendance participation, final score and pass / fail. The report is marked provisional until the selection is finalized.

## Common questions

**A component shows "missing" for a member.**
There is no data for it in the period: no classes or marks, no Mezmur programs, nothing due, or no participation score. It is left out of the total rather than counted as 0.

**Why can't I finalize?**
A required review department has not approved yet.

**Can results change after finalization?**
No. Finalized results are locked; use an override during review instead.

## For developers

| Area | Location |
|---|---|
| Selections, scoring, status flow, publish | `laravel/app/Mz/Services/Selections.php` |
| Mezmur report | `laravel/app/Mz/Services/SelectionReports.php` |
| API | `laravel/routes/api/selections.php`, export: `GET /reports/export/{selection,mezmur-selection}` |
| App screens | `mobile/mobile/lib/features/admin/selections_admin.dart` |

The tables of the withdrawn department criteria (`selection_config_versions`, `selection_scores`, `selection_evaluators`) and the extra columns on `selection_results` (`outcome`, `score_exact`, `rank`, `config_version_id`) are still in the database, unused, so no data was deleted.
