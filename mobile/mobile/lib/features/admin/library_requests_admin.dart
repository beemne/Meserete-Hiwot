import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/library.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../library/books_screen.dart' show bookRequestStatusColor, bookRequestStatusLabel;
import 'admin_widgets.dart';

/// Librarian (borrowing.manage): members' requests for printed books. Approve or reject, then hand
/// the book over — the member signs on the phone and the normal borrowing record is created.
class LibraryRequestsAdminScreen extends ConsumerStatefulWidget {
  const LibraryRequestsAdminScreen({super.key});
  @override
  ConsumerState<LibraryRequestsAdminScreen> createState() => _LibraryRequestsAdminScreenState();
}

class _LibraryRequestsAdminScreenState extends ConsumerState<LibraryRequestsAdminScreen> {
  final _ctrl = PagedListController<BookRequest>();
  String _status = 'requested,approved';
  String _q = '';

  Future<void> _approve(BookRequest r) async {
    final l = context.l10n;
    final note = await promptText(context, title: l.libApprove, label: l.libRequestNote);
    if (note == null || !mounted) return;
    final x = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).approve(r.id, note: note.trim().isEmpty ? null : note.trim()));
    if (x != null) await _ctrl.refresh();
  }

  Future<void> _reject(BookRequest r) async {
    final l = context.l10n;
    final reason = await promptText(context, title: l.libReject, label: l.reason, required: true);
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final x = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).reject(r.id, reason.trim()));
    if (x != null) await _ctrl.refresh();
  }

  Future<void> _handOver(BookRequest r) async {
    final l = context.l10n;
    final days = await promptText(context, title: l.libHandOver, label: l.libLoanDays, initial: '14');
    if (days == null || !mounted) return;
    final signature = await captureSignature(context, name: r.userName ?? '');
    if (signature == null || !mounted) return;
    final x = await runWithProgress(
      context,
      () => ref.read(libraryRepositoryProvider).handOver(r.id, signature: signature, loanDays: int.tryParse(days.trim())),
      success: l.libReqIssued,
    );
    if (x != null) await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final filters = [
      ('requested,approved', l.open),
      ('requested', l.libRequested),
      ('approved', l.libReqApproved),
      ('issued', l.libReqIssued),
      ('rejected', l.libReqRejected),
      ('cancelled', l.libReqCancelled),
    ];
    return AdminScaffold(
      title: l.libRequests,
      actions: [IconButton(tooltip: l.libBooks, icon: const Icon(Icons.menu_book_outlined), onPressed: () => context.push('/admin/items'))],
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final (k, label) in filters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(key: ValueKey('libreq-filter-$k'), label: Text(label), selected: _status == k, onSelected: (_) => setState(() => _status = k)),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<BookRequest>(
            key: ValueKey('$_status-$_q'),
            controller: _ctrl,
            emptyMessage: l.libNoRequests,
            emptyIcon: Icons.outbox_outlined,
            fetch: (page) => ref.read(libraryRepositoryProvider).requests(status: _status, q: _q.isEmpty ? null : _q, page: page),
            itemBuilder: (context, r, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    ListThumb(icon: Icons.menu_book_outlined, imageUrl: r.bookCoverUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.bookTitle, style: context.sans(14, weight: FontWeight.w700)),
                        Text([?r.bookCode, l.libAvailable('${r.bookAvailable}')].join(' · '), style: context.sans(11, color: context.palette.subtle)),
                        Text([?r.userName, ?r.userMemberId, ?r.userPhone].join(' · '), style: context.sans(12, color: context.palette.muted)),
                      ]),
                    ),
                    Pill(bookRequestStatusLabel(l, r.status), color: bookRequestStatusColor(r.status)),
                  ]),
                  if (r.note != null || r.neededOn != null || r.reviewNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        [?r.note, if (r.neededOn != null) '${l.libNeededOn}: ${f.date(r.neededOn)}', ?r.reviewNote, if (r.createdAt != null) f.relative(r.createdAt)].join(' · '),
                        style: context.sans(12, color: context.palette.muted),
                      ),
                    ),
                  if (r.isOpen)
                    Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                      TextButton(key: ValueKey('libreq-reject-${r.id}'), onPressed: () => _reject(r), child: Text(l.libReject)),
                      if (r.status == 'requested') OutlinedButton(key: ValueKey('libreq-approve-${r.id}'), onPressed: () => _approve(r), child: Text(l.libApprove)),
                      FilledButton.icon(
                        key: ValueKey('libreq-issue-${r.id}'),
                        onPressed: r.bookAvailable > 0 ? () => _handOver(r) : null,
                        icon: const Icon(Icons.draw_rounded, size: 18),
                        label: Text(l.libHandOver),
                      ),
                    ])
                  else if (r.borrowingId != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () => context.push('/admin/borrowings/${r.borrowingId}'), child: Text(l.borrowing)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
