import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/lrc.dart';
import '../services/audio_player_service.dart';
import '../services/narration_player_service.dart';

/// What a file is, from its MIME type or name (the server already checked the real content type).
String fileKindOf(String name, String? mime) {
  final m = (mime ?? '').toLowerCase();
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (ext == 'lrc') return 'lrc';
  if (m.startsWith('image/') || ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) return 'image';
  if (m == 'application/pdf' || ext == 'pdf') return 'pdf';
  if (m.startsWith('audio/') || ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'flac', 'amr'].contains(ext)) return 'audio';
  if (m.startsWith('video/') || ['mp4', 'mov', 'webm', '3gp', 'mkv'].contains(ext)) return 'video';
  if (m.startsWith('text/') || ['txt', 'csv', 'json', 'md', 'log', 'xml'].contains(ext)) return 'text';
  return 'other';
}

/// One reusable preview for every module's files (chat, projects, tasks, education, property…):
/// images (zoom), PDF, audio, video, text / CSV / JSON and .lrc (as timed lines). Anything else
/// shows its name, type and size with "Open with / Share". The file was already downloaded with
/// the user's own permission (private files are never public URLs).
Future<void> openFilePreview(BuildContext context, String path, {String? name, String? mime}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => FilePreviewScreen(path: path, name: name ?? path.split(Platform.pathSeparator).last, mime: mime)));

class FilePreviewScreen extends StatelessWidget {
  const FilePreviewScreen({super.key, required this.path, required this.name, this.mime});
  final String path;
  final String name;
  final String? mime;

  Future<void> _share() => SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: mime)], subject: name));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kind = fileKindOf(name, mime);
    final file = File(path);
    final body = switch (kind) {
      'image' => InteractiveViewer(maxScale: 6, child: Center(child: Image.file(file))),
      'pdf' => PdfViewer.file(path, params: const PdfViewerParams()),
      'audio' => _AudioPreview(path: path),
      'video' => _VideoPreview(path: path),
      'text' || 'lrc' => _TextPreview(path: path, lrc: kind == 'lrc'),
      _ => _FileInfo(name: name, mime: mime, size: file.existsSync() ? file.lengthSync() : 0, onOpen: _share),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [IconButton(key: const ValueKey('preview-share'), tooltip: l.openWith, icon: const Icon(Icons.ios_share_rounded), onPressed: _share)],
      ),
      body: body,
    );
  }
}

class _FileInfo extends StatelessWidget {
  const _FileInfo({required this.name, required this.mime, required this.size, required this.onOpen});
  final String name;
  final String? mime;
  final int size;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 72, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(name, textAlign: TextAlign.center, style: context.serif(17)),
          const SizedBox(height: 6),
          Text('${mime ?? l.fileTypeUnknown} · ${Formatters.fileSize(size)}', style: context.sans(12, color: context.palette.muted)),
          const SizedBox(height: 4),
          Text(l.previewUnavailable, textAlign: TextAlign.center, style: context.sans(12, color: context.palette.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onOpen, icon: const Icon(Icons.open_in_new_rounded), label: Text(l.openWith)),
        ]),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.path, required this.lrc});
  final String path;
  final bool lrc;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: File(path).readAsBytes().then((b) => utf8.decode(b, allowMalformed: true)),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final text = snap.data!.replaceFirst('﻿', '');
        if (lrc) {
          // A synchronized-lyrics file: its timed lines (repeats shown with every time).
          final sheet = parseLrcSheet(text);
          if (!sheet.isEmpty) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (var i = 0; i < sheet.lines.length; i++)
                ListTile(
                  dense: true,
                  leading: Text(sheet.times[i].map(formatLrcTime).join('\n'), style: context.sans(12, color: AppColors.goldDark)),
                  title: Text(sheet.lines[i].isEmpty ? '♪' : sheet.lines[i], style: context.serif(15)),
                ),
            ]);
          }
        }
        return SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)));
      },
    );
  }
}

class _AudioPreview extends ConsumerStatefulWidget {
  const _AudioPreview({required this.path});
  final String path;
  @override
  ConsumerState<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends ConsumerState<_AudioPreview> {
  final _p = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _p.setFilePath(widget.path).catchError((_) => null);
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  void _togglePlay(bool isPlaying) {
    if (isPlaying) {
      _p.pause();
    } else {
      try {
        ref.read(audioProvider.notifier).player.pause();
      } catch (_) {}
      try {
        ref.read(narrationControllerProvider.notifier).pause();
      } catch (_) {}
      _p.play();
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: StreamBuilder<Duration>(
          stream: _p.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final total = _p.duration ?? Duration.zero;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.audiotrack_rounded, size: 72, color: AppColors.gold),
                Slider(value: pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(), max: total.inMilliseconds.toDouble().clamp(1, double.infinity), onChanged: (v) => _p.seek(Duration(milliseconds: v.round()))),
                Text('${Formatters.duration(pos)} / ${Formatters.duration(total)}'),
                StreamBuilder<bool>(
                  stream: _p.playingStream,
                  builder: (context, s) => IconButton(
                    iconSize: 56,
                    icon: Icon(s.data == true ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: AppColors.maroon),
                    onPressed: () => _togglePlay(s.data == true),
                  ),
                ),
              ]),
            );
          },
        ),
      );
}

class _VideoPreview extends ConsumerStatefulWidget {
  const _VideoPreview({required this.path});
  final String path;
  @override
  ConsumerState<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<_VideoPreview> {
  late final VideoPlayerController _c = VideoPlayerController.file(File(widget.path));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_c.value.isPlaying) {
      _c.pause();
    } else {
      try {
        ref.read(audioProvider.notifier).player.pause();
      } catch (_) {}
      try {
        ref.read(narrationControllerProvider.notifier).pause();
      } catch (_) {}
      _c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AspectRatio(
          aspectRatio: _c.value.aspectRatio,
          child: Stack(alignment: Alignment.center, children: [
            VideoPlayer(_c),
            if (!_c.value.isPlaying) const Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white70),
            Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(_c, allowScrubbing: true)),
          ]),
        ),
      ),
    );
  }
}
