import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/error_text.dart';
import '../core/l10n/l10n.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../features/support/report_problem_screen.dart';
import '../services/sync_status.dart';
import 'sync_status_sheet.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = const EdgeInsets.all(40)});
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.message, this.action, this.actionLabel});
  final IconData icon;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: p.pill, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppColors.goldDark),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: context.sans(14, color: p.muted, height: 1.6)),
          if (action != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: action, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(actionLabel ?? context.l10n.retry)),
          ],
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.music_note_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => MessageView(icon: icon, message: message);
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.module,
    this.screen,
    this.reportId,
  });

  final Object error;
  final VoidCallback? onRetry;
  final String? module;
  final String? screen;
  final String? reportId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    String message = errorText(l, error);
    IconData icon = Icons.error_outline_rounded;

    if (error is ApiException) {
      final apiEx = error as ApiException;
      if (apiEx.code == 'NOT_AVAILABLE_FOR_ACCOUNT') {
        icon = Icons.lock_outline_rounded;
        message = l.notAvailableForAccount;
      } else if (apiEx.isNetwork) {
        icon = Icons.cloud_off_rounded;
        message = l.offlineNotCached;
      }
    }

    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: p.pill, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: AppColors.goldDark),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.sans(14, color: p.muted, height: 1.5),
            ),
            if (reportId != null) ...[
              const SizedBox(height: 8),
              Text(
                '${isEn ? "Diagnostic ID" : "የስህተት መለያ"}: $reportId',
                style: context.mono(11, color: p.muted),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.retry),
                  ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReportProblemScreen(
                          initialModule: module ?? 'general',
                          initialScreen: screen,
                          initialErrorMessage: error.toString(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: Text(isEn ? 'Report Problem' : 'ችግር ሪፖርት አድርግ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an AsyncValue with consistent loading / error (+retry) states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
    );
  }
}

/// Infinite-scroll list over a paginated endpoint, with pull-to-refresh and all states.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 24),
    this.header,
    this.separator,
    this.controller,
    this.onPageLoaded,
  });

  final Future<Paged<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final EdgeInsets padding;
  final Widget? header;
  final Widget? separator;
  final PagedListController<T>? controller;
  final void Function(Paged<T> page)? onPageLoaded;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class PagedListController<T> {
  _PagedListViewState<T>? _state;
  Future<void> refresh() async => _state?._refresh();
  List<T> get items => _state?._items ?? const [];
  int get total => _state?._total ?? 0;
  void updateWhere(bool Function(T) test, T Function(T) update) => _state?._update(test, update);
  void removeWhere(bool Function(T) test) => _state?._remove(test);
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _items = <T>[];
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;
  Object? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _pages) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _pages = res.pages;
        _total = res.total;
      });
      widget.onPageLoaded?.call(res);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _pages = 1;
      _error = null;
    });
    await _loadMore();
  }

  void _update(bool Function(T) test, T Function(T) update) {
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (test(_items[i])) _items[i] = update(_items[i]);
      }
    });
  }

  void _remove(bool Function(T) test) => setState(() => _items.removeWhere(test));

  @override
  Widget build(BuildContext context) {
    final showEmpty = !_loading && _error == null && _items.isEmpty;
    final showFullError = _error != null && _items.isEmpty;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.gold,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: (widget.header != null ? 1 : 0) + _items.length + 1,
        separatorBuilder: (_, i) {
          final dataIndex = i - (widget.header != null ? 1 : 0);
          if (dataIndex < 0 || dataIndex >= _items.length - 1) return const SizedBox.shrink();
          return widget.separator ?? const SizedBox(height: 2);
        },
        itemBuilder: (context, i) {
          if (widget.header != null && i == 0) return widget.header!;
          final idx = i - (widget.header != null ? 1 : 0);
          if (idx < _items.length) return widget.itemBuilder(context, _items[idx], idx);
          if (showFullError) return ErrorView(error: _error!, onRetry: _refresh);
          if (showEmpty) return EmptyView(message: widget.emptyMessage, icon: widget.emptyIcon);
          if (_error != null) return ErrorView(error: _error!, onRetry: _loadMore);
          if (_loading) return const LoadingView(padding: EdgeInsets.all(20));
          return const SizedBox(height: 8);
        },
      ),
    );
  }
}

/// Banner shown when the device is offline, showing last-sync time and pending operations.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    if (online) return const SizedBox.shrink();

    final status = ref.watch(syncStatusProvider);
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);

    final lastSyncText = status.lastSuccessfulSync != null
        ? f.time(status.lastSuccessfulSync!)
        : null;
    final pending = status.pendingCount;

    final String bannerText;
    if (lastSyncText != null && pending > 0) {
      bannerText = l.offlineBannerWithSync(lastSyncText, pending);
    } else if (lastSyncText != null) {
      bannerText = l.offlineBannerNoPending(lastSyncText);
    } else if (pending > 0) {
      bannerText = l.offlineBannerNoSync(pending);
    } else {
      bannerText = l.offlineBanner;
    }

    return Material(
      color: AppColors.maroonDark,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const SyncStatusSheet(),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.goldLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bannerText,
                  style: context.sans(12, color: Colors.white, weight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.goldLight),
            ],
          ),
        ),
      ),
    );
  }
}
