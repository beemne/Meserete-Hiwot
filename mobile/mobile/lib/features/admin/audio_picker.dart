import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/states.dart';

/// Pick any audio on the phone — music, voice recordings, WhatsApp/Telegram audio — after asking
/// for the audio permission. "Browse files" falls back to the system file picker.
/// Returns the local file path, or null when cancelled.
Future<String?> pickAudioPath(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.85, child: const _AudioPicker()),
      ),
    );

class _AudioPicker extends StatefulWidget {
  const _AudioPicker();
  @override
  State<_AudioPicker> createState() => _AudioPickerState();
}

class _Audio {
  const _Audio(this.entity, this.title);
  final AssetEntity entity;
  final String title;
}

class _AudioPickerState extends State<_AudioPicker> {
  static const _option = PermissionRequestOption(androidPermission: AndroidPermission(type: RequestType.audio, mediaLocation: false));

  PermissionState? _permission;
  List<_Audio>? _items;
  String _q = '';
  bool _opening = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await PhotoManager.requestPermissionExtend(requestOption: _option);
      if (!mounted) return;
      setState(() => _permission = state);
      if (!state.hasAccess) return;
      final total = await PhotoManager.getAssetCount(type: RequestType.audio);
      final items = <_Audio>[];
      for (var page = 0; page * 200 < total; page++) {
        final batch = await PhotoManager.getAssetListPaged(page: page, pageCount: 200, type: RequestType.audio);
        for (final e in batch) {
          final title = (e.title?.isNotEmpty ?? false) ? e.title! : await e.titleAsync;
          items.add(_Audio(e, title));
        }
      }
      items.sort((a, b) => b.entity.createDateTime.compareTo(a.entity.createDateTime)); // newest recordings first
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _choose(_Audio a) async {
    setState(() => _opening = true);
    final file = await a.entity.originFile ?? await a.entity.file;
    if (!mounted) return;
    setState(() => _opening = false);
    if (file != null) Navigator.pop(context, file.path);
  }

  Future<void> _browse() async {
    // FileType.any: some phones hide voice recordings (.amr, .opus, .m4a) from the audio filter.
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (!mounted || res.isEmpty) return;
    final path = res.first.path;
    if (path != null) Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final visible = _items?.where((a) => _q.isEmpty || a.title.toLowerCase().contains(_q.toLowerCase())).toList();

    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: () {
        setState(() => _error = null);
        _load();
      });
    } else if (_permission == null || (_permission!.hasAccess && _items == null)) {
      body = const LoadingView();
    } else if (!_permission!.hasAccess) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.library_music_outlined, size: 48, color: AppColors.gold),
            const SizedBox(height: 12),
            Text(l.audioPermissionNeeded, textAlign: TextAlign.center, style: context.sans(14, color: p.muted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: Text(l.allowAccess)),
            TextButton(onPressed: PhotoManager.openSetting, child: Text(l.openSettings)),
          ]),
        ),
      );
    } else if (visible!.isEmpty) {
      body = EmptyView(message: l.noAudioFiles, icon: Icons.music_off_outlined);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        itemCount: visible.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: p.border),
        itemBuilder: (context, i) {
          final a = visible[i];
          return ListTile(
            leading: const Icon(Icons.audiotrack_rounded, color: AppColors.gold),
            title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text([Formatters.durationSec(a.entity.duration), f.date(a.entity.createDateTime)].join(' · ')),
            onTap: _opening ? null : () => _choose(a),
          );
        },
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
        child: Row(children: [
          Expanded(child: Text(l.audioOnPhone, style: context.serif(19))),
          IconButton(tooltip: l.close, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        ]),
      ),
      if (_items != null && _items!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.searchAudio, isDense: true),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
        ),
      if (_opening) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: body),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: OutlinedButton.icon(onPressed: _browse, icon: const Icon(Icons.folder_open_rounded), label: Text(l.browseFiles)),
        ),
      ),
    ]);
  }
}
