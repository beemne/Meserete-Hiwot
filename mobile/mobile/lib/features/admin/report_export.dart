import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';

/// "Export" menu of a report: PDF (print-ready, branded, Ethiopian dates), Excel (summary + detail
/// sheets) or CSV (plain data). The server builds the file from one shared template and audits the
/// export; the phone saves it and opens the share sheet (save to files, send, print…).
/// Another report offered in the same export menu (one download button per page).
class ExtraReport {
  const ExtraReport({required this.kind, required this.label, this.filters, this.formats = const ['pdf', 'xlsx', 'csv']});
  final String kind;
  final String label;
  final Json Function()? filters;
  final List<String> formats;
}

class ReportExportButton extends ConsumerWidget {
  const ReportExportButton({super.key, required this.kind, this.filters, this.formats = const ['pdf', 'xlsx', 'csv'], this.label, this.extra = const []});

  /// Heading of this report in the menu (shown only when [extra] reports share the menu).
  final String? label;

  /// More reports in the same menu, each under its own heading.
  final List<ExtraReport> extra;

  /// users | mezmurs | attendance | borrowings | notifications | admin-activity | audit-logs |
  /// activity-logs | contributions | selection | projects
  final String kind;

  /// The filters on screen when the menu is used (read at that moment).
  final Json Function()? filters;
  final List<String> formats;

  Future<void> _export(BuildContext context, WidgetRef ref, String format, {String? kind, Json Function()? filters}) async {
    final l = context.l10n;
    final query = <String, String>{'format': format};
    kind ??= this.kind;
    filters ??= this.filters;
    for (final e in (filters?.call() ?? const <String, dynamic>{}).entries) {
      if (e.value != null && '${e.value}'.isNotEmpty) query[e.key] = '${e.value}';
    }
    final path = Uri(path: '/reports/export/$kind', queryParameters: query).toString();
    final bytes = await runWithProgress(context, () => ref.read(adminRepositoryProvider).exportReport(path));
    if (bytes == null) return;
    final ext = format == 'xlsx' ? 'xlsx' : format;
    final name = '$kind-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = switch (format) {
      'pdf' => 'application/pdf',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'text/csv',
    };
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(ShareParams(files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mime, name: name)], subject: name));
      } else {
        final f = File(p.join((await getTemporaryDirectory()).path, name));
        await f.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime)], subject: name));
      }
      if (context.mounted) showSnack(context, l.exportReady);
    } catch (e) {
      if (context.mounted) showSnack(context, '${l.export}: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Menu values are "index|format": 0 = this report, 1.. = the extra ones.
    List<PopupMenuEntry<String>> group(int i, String? heading, List<String> fmts) => [
          if (heading != null)
            PopupMenuItem<String>(enabled: false, height: 32, child: Text(heading, style: context.sans(12, weight: FontWeight.w700, color: context.palette.muted))),
          if (fmts.contains('pdf')) PopupMenuItem(value: '$i|pdf', child: ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(l.exportPdf))),
          if (fmts.contains('xlsx')) PopupMenuItem(value: '$i|xlsx', child: ListTile(leading: const Icon(Icons.grid_on_rounded), title: Text(l.exportExcel))),
          if (fmts.contains('csv')) PopupMenuItem(value: '$i|csv', child: ListTile(leading: const Icon(Icons.table_rows_outlined), title: Text(l.exportCsv))),
        ];
    return PopupMenuButton<String>(
      key: ValueKey('export-$kind'),
      tooltip: l.export,
      icon: const Icon(Icons.file_download_outlined),
      onSelected: (v) {
        final [i, f] = v.split('|');
        final n = int.parse(i);
        if (n == 0) {
          _export(context, ref, f);
        } else {
          _export(context, ref, f, kind: extra[n - 1].kind, filters: extra[n - 1].filters);
        }
      },
      itemBuilder: (_) => [
        ...group(0, extra.isEmpty ? null : (label ?? l.export), formats),
        for (var i = 0; i < extra.length; i++) ...[const PopupMenuDivider(), ...group(i + 1, extra[i].label, extra[i].formats)],
      ],
    );
  }
}
