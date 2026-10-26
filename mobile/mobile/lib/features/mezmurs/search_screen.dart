import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/content.dart';
import '../../repositories/providers.dart';
import '../../services/download_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';
import 'widgets.dart';

/// Search — design screen "04 Search": pill field with gold focus ring, recent searches,
/// then category and Mezmur results. Debounced; falls back to downloaded Mezmurs offline.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _q = '';
  bool _loading = false;
  bool _offline = false;
  Object? _error;
  List<MezmurSummary> _mezmurs = const [];
  List<CategoryNode> _categories = const [];
  List<CategoryNode> _allCategories = const [];

  @override
  void initState() {
    super.initState();
    ref.read(contentRepositoryProvider).categoryTree().then((t) {
      if (mounted) setState(() => _allCategories = t.expand((c) => c.flatten()).toList());
    }).catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
    setState(() {});
  }

  /// [submitted]: the user pressed the search button — only then is the query kept in recent searches.
  Future<void> _search(String q, {bool submitted = false}) async {
    setState(() {
      _q = q;
      _error = null;
    });
    if (q.isEmpty) {
      setState(() {
        _mezmurs = const [];
        _categories = const [];
      });
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      _loading = true;
      _categories = _allCategories.where((c) => c.name.toLowerCase().contains(lower)).take(5).toList();
    });
    try {
      final r = await ref.read(contentRepositoryProvider).mezmurs(q: q, log: submitted);
      if (!mounted || q != _q) return;
      setState(() {
        _mezmurs = r.items;
        _offline = false;
      });
      if (submitted && q.length >= 2) {
        await ref.read(localPrefsProvider).addRecentSearch(q);
        if (mounted) setState(() {});
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNetwork) {
        final local = await ref.read(downloadsProvider.notifier).searchOffline(q);
        setState(() {
          _mezmurs = local.map((m) => m.summary).toList();
          _offline = true;
        });
      } else {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useRecent(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _search(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final recent = ref.read(localPrefsProvider).recentSearches;

    return PatternScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 24), children: [
          Row(children: [
            CircleAction(icon: Icons.chevron_left_rounded, tooltip: l.back, onTap: () => context.pop()),
            const SizedBox(width: 12),
            Expanded(child: Text(l.searchTitle, style: context.serif(22))),
            const ContextualHelpButton(screenRoute: '/home/search'),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            onSubmitted: (v) {
              _debounce?.cancel();
              _search(v.trim(), submitted: true);
            },
            textInputAction: TextInputAction.search,
            style: context.sans(15),
            decoration: InputDecoration(
              hintText: l.searchHint,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, color: p.subtle, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        _search('');
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: p.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: p.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
            ),
          ),
          if (_q.isEmpty) ...[
            if (recent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
                child: Row(children: [
                  Expanded(child: Text(l.recentSearches, style: context.sans(12, weight: FontWeight.w600, color: p.muted))),
                  TextButton(
                    onPressed: () async {
                      await ref.read(localPrefsProvider).clearRecentSearches();
                      setState(() {});
                    },
                    child: Text(l.clearRecent),
                  ),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in recent) ActionChip(label: Text(r), onPressed: () => _useRecent(r)),
              ]),
            ] else
              Padding(padding: const EdgeInsets.only(top: 40), child: EmptyView(message: l.searchPrompt, icon: Icons.search_rounded)),
          ] else ...[
            if (_offline)
              Padding(padding: const EdgeInsets.only(top: 12), child: Pill(l.searchOfflineNote, icon: Icons.wifi_off_rounded)),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
              child: Text(l.results, style: context.sans(12, weight: FontWeight.w600, color: p.muted)),
            ),
            for (final c in _categories)
              TrackTile(
                title: c.name,
                subtitle: l.categoryResult(l.mezmurCount(c.totalMezmurCount)),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_rounded, color: AppColors.goldLight),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                onTap: () => context.push('/home/category/${c.id}'),
              ),
            for (final m in _mezmurs) MezmurTile(mezmur: m),
            if (_loading) const LoadingView(padding: EdgeInsets.all(20)),
            if (_error != null) ErrorView(error: _error!, onRetry: () => _search(_q)),
            if (!_loading && _error == null && _mezmurs.isEmpty && _categories.isEmpty) EmptyView(message: l.noResults, icon: Icons.search_off_rounded),
          ],
        ]),
      ),
    );
  }
}
