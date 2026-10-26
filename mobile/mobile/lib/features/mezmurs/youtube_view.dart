import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/l10n/l10n.dart';
import '../../services/audio_player_service.dart';

/// The video id of a youtube.com / youtu.be link (null when it is not one).
String? youtubeIdOf(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  return YoutubePlayerController.convertUrlToId(url.trim());
}

/// A Mezmur's YouTube video played inside the app (YouTube's own embedded player), so the member
/// never leaves the app. The app's audio pauses while the video plays.
class InAppYoutube extends ConsumerStatefulWidget {
  const InAppYoutube({super.key, required this.videoId, this.autoPlay = false});
  final String videoId;
  final bool autoPlay;

  @override
  ConsumerState<InAppYoutube> createState() => _InAppYoutubeState();
}

class _InAppYoutubeState extends ConsumerState<InAppYoutube> {
  late final YoutubePlayerController _c = YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: widget.autoPlay,
    params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, showVideoAnnotations: false),
  );

  @override
  void initState() {
    super.initState();
    _c.listen((v) {
      if (v.playerState == PlayerState.playing && ref.read(audioProvider).playing) {
        ref.read(audioProvider.notifier).toggle();
      }
    });
  }

  @override
  void dispose() {
    _c.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: YoutubePlayer(controller: _c, aspectRatio: 16 / 9),
      );
}

/// Full-screen page with the video (from the Mezmur menu).
Future<void> openYoutubeInApp(BuildContext context, String url, {String? title}) async {
  final id = youtubeIdOf(url);
  if (id == null) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    builder: (ctx) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title ?? ctx.l10n.watchOnYoutube)),
      body: Center(child: InAppYoutube(videoId: id, autoPlay: true)),
    ),
  ));
}
