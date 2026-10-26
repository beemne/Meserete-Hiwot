import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/json.dart';
import 'sync_service.dart';

class SyncQueueItem {
  const SyncQueueItem({
    required this.opId,
    required this.type,
    required this.clientTs,
    required this.payload,
  });

  final String opId;
  final String type;
  final DateTime clientTs;
  final Json payload;
}

class SyncStatus {
  const SyncStatus({
    this.lastSuccessfulSync,
    this.pendingCount = 0,
    this.isFlushing = false,
    this.lastError,
    this.pendingOps = const [],
  });

  final DateTime? lastSuccessfulSync;
  final int pendingCount;
  final bool isFlushing;
  final String? lastError;
  final List<SyncQueueItem> pendingOps;

  SyncStatus copyWith({
    DateTime? lastSuccessfulSync,
    int? pendingCount,
    bool? isFlushing,
    String? lastError,
    bool clearLastError = false,
    List<SyncQueueItem>? pendingOps,
  }) =>
      SyncStatus(
        lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
        pendingCount: pendingCount ?? this.pendingCount,
        isFlushing: isFlushing ?? this.isFlushing,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        pendingOps: pendingOps ?? this.pendingOps,
      );
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final prefs = ref.watch(localPrefsProvider);
    final initialSync = prefs.lastSuccessfulSync;

    // Listen to sync service events
    final sync = ref.watch(syncServiceProvider);
    final subFlushed = sync.onFlushed.listen((_) => refresh());
    final subRejected = sync.onRejected.listen((rej) {
      state = state.copyWith(lastError: rej.code ?? 'SYNC_REJECTED');
      refresh();
    });
    ref.onDispose(() {
      subFlushed.cancel();
      subRejected.cancel();
    });

    Future.microtask(refresh);
    return SyncStatus(lastSuccessfulSync: initialSync);
  }

  Future<void> refresh() async {
    final sync = ref.read(syncServiceProvider);
    final prefs = ref.read(localPrefsProvider);
    final count = await sync.pendingCount();
    final items = await sync.getPendingQueueItems();
    state = state.copyWith(
      lastSuccessfulSync: prefs.lastSuccessfulSync,
      pendingCount: count,
      pendingOps: items,
      isFlushing: sync.isFlushing,
    );
  }

  void setFlushing(bool flushing) {
    state = state.copyWith(isFlushing: flushing);
  }

  void setLastError(String? err) {
    state = state.copyWith(lastError: err, clearLastError: err == null);
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);
