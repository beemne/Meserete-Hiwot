import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/audio_player_service.dart';
import '../mezmurs/mezmur_screen.dart';

/// "/player" (notification tap, mini player): the same player page as opening a Mezmur,
/// following the queue as it moves on.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.read(audioProvider).current?.id;
    if (id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const SizedBox.shrink();
    }
    return MezmurScreen(mezmurId: id, followPlayer: true);
  }
}
