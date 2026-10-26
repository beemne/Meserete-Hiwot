import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/library.dart';
import '../../repositories/providers.dart';
import '../../services/book_vault.dart';
import '../../services/narration_player_service.dart';
import '../../widgets/secure_screen.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show DateTimeField, SearchBox;
import '../auth/session.dart';

String bookRequestStatusLabel(AppLocalizations l, String s) => switch (s) {
      'approved' => l.libReqApproved,
      'rejected' => l.libReqRejected,
      'issued' => l.libReqIssued,
      'cancelled' => l.libReqCancelled,
      _ => l.libRequested,
    };

Color bookRequestStatusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' || 'cancelled' => AppColors.danger,
      'issued' => const Color(0xFF1F5F8B),
      _ => AppColors.goldDark,
    };

/// Upgraded PDF reader (F16):
/// - Restores last page (page memory & offline progress sync)
/// - Text search with PdfTextSearcher & in-memory highlights
/// - Page-number jump & zoom controls
/// - Landscape / auto-rotation support
/// - Integrated audio narration playback with background lock-screen controls
class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.book, this.initialBytes});
  final Book book;
  final Uint8List? initialBytes;

  static const _channel = MethodChannel('mezmur/settings');

  static Future<void> setSecure(bool on) async {
    try {
      await _channel.invokeMethod('setSecure', {'on': on});
    } catch (_) {
      // Not Android / tests: nothing to do.
    }
  }

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  late Future<Uint8List> _pdf;
  late final PdfViewerController _controller = PdfViewerController();
  late final PdfTextSearcher _searcher = PdfTextSearcher(_controller);

  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  late int _currentPage = widget.book.progress?.page ?? 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null) {
      _pdf = Future.value(widget.initialBytes!);
    } else {
      _pdf = _loadPdf();
    }
    SecureScreen.acquire();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _searcher.addListener(_onSearcherChanged);
  }

  Future<Uint8List> _loadPdf() async {
    try {
      return await BookVault.read(widget.book.id);
    } catch (_) {
      final pdf = await ref.read(libraryRepositoryProvider).downloadBook(widget.book);
      await BookVault.save(widget.book.id, pdf);
      return pdf;
    }
  }

  void _onSearcherChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searcher.removeListener(_onSearcherChanged);
    _searcher.dispose();
    _searchCtrl.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SecureScreen.release();
    super.dispose();
  }

  void _onPageChanged(int? page) {
    if (page == null || page == _currentPage) return;
    setState(() => _currentPage = page);
    ref.read(libraryRepositoryProvider).saveProgress(
          widget.book.id,
          page: page,
          pageCount: _controller.isReady ? _controller.pageCount : null,
        );
  }

  Future<void> _jumpToPageDialog() async {
    final l = context.l10n;
    final total = _controller.isReady ? _controller.pageCount : null;
    final pageCtrl = TextEditingController(text: '$_currentPage');

    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.libJumpToPage),
        content: TextField(
          controller: pageCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l.libPageNumber,
            hintText: total != null ? '1 – $total' : '1, 2…',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(pageCtrl.text.trim());
              Navigator.pop(ctx, n);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );

    if (target != null && target >= 1 && (total == null || target <= total)) {
      await _controller.goToPage(pageNumber: target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final narration = ref.watch(narrationControllerProvider);
    final isThisNarration = narration.book?.id == widget.book.id;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                key: const ValueKey('reader-search-input'),
                controller: _searchCtrl,
                autofocus: true,
                style: context.sans(14),
                decoration: InputDecoration(
                  hintText: l.libSearchInBook,
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _searcher.resetTextSearch();
                          },
                        )
                      : null,
                ),
                onChanged: (v) => _searcher.startTextSearch(v, caseInsensitive: true),
              )
            : Text(widget.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_showSearch) ...[
            if (_searcher.hasMatches) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${_searcher.currentIndex != null ? _searcher.currentIndex! + 1 : 0}/${_searcher.matches.length}',
                    style: context.sans(12, color: p.muted, weight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('reader-search-prev'),
                tooltip: l.libPrevMatch,
                icon: const Icon(Icons.arrow_upward_rounded),
                onPressed: _searcher.goToPrevMatch,
              ),
              IconButton(
                key: const ValueKey('reader-search-next'),
                tooltip: l.libNextMatch,
                icon: const Icon(Icons.arrow_downward_rounded),
                onPressed: _searcher.goToNextMatch,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _showSearch = false;
                  _searchCtrl.clear();
                  _searcher.resetTextSearch();
                });
              },
            ),
          ] else ...[
            IconButton(
              key: const ValueKey('reader-search-toggle'),
              tooltip: l.search,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              tooltip: l.libZoomIn,
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: () => _controller.zoomUp(),
            ),
            IconButton(
              tooltip: l.libZoomOut,
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: () => _controller.zoomDown(),
            ),
            TextButton(
              key: const ValueKey('reader-jump-page-btn'),
              onPressed: _jumpToPageDialog,
              child: Text(
                '$_currentPage${_controller.isReady ? ' / ${_controller.pageCount}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.maroon),
                    const SizedBox(height: 12),
                    Text(
                      l.isEn ? 'Could not open book' : 'መጽሐፉን መክፈት አልተቻለም',
                      style: context.serif(18, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: context.sans(12, color: context.palette.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.retry),
                      onPressed: () => setState(() => _pdf = _loadPdf()),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text(l.isEn ? 'Loading book...' : 'መጽሐፉ እየተከፈተ ነው...', style: context.sans(13)),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: PdfViewer.data(
                  snap.data!,
                  sourceName: 'library-book-${widget.book.id}',
                  controller: _controller,
                  params: PdfViewerParams(
                    backgroundColor: context.palette.fill,
                    calculateInitialPageNumber: (_, _) => _currentPage,
                    onPageChanged: _onPageChanged,
                    pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
                    textSelectionParams: const PdfTextSelectionParams(enabled: false),
                  ),
                ),
              ),
              // Optional Narration bar inside the reader
              if (widget.book.hasNarration)
                _ReaderNarrationBar(
                  book: widget.book,
                  isActive: isThisNarration,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderNarrationBar extends ConsumerWidget {
  const _ReaderNarrationBar({required this.book, required this.isActive});
  final Book book;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final narration = ref.watch(narrationControllerProvider);
    final ctrl = ref.read(narrationControllerProvider.notifier);

    final isPlaying = isActive && narration.isPlaying;
    final pos = isActive ? narration.position : Duration(milliseconds: book.progress?.audioPositionMs ?? 0);
    final dur = isActive && narration.duration > Duration.zero
        ? narration.duration
        : Duration(seconds: book.narrationDuration ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.headphones_rounded, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l.libNarration}: ${book.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.sans(12, weight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '-10s',
              icon: const Icon(Icons.replay_10_rounded, size: 20),
              onPressed: isActive ? () => ctrl.skip(const Duration(seconds: -10)) : null,
            ),
            IconButton.filled(
              key: const ValueKey('reader-narration-play-pause'),
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: () {
                if (isPlaying) {
                  ctrl.pause();
                } else {
                  ctrl.playBook(book, initialPosition: pos);
                }
              },
            ),
            IconButton(
              tooltip: '+30s',
              icon: const Icon(Icons.forward_30_rounded, size: 20),
              onPressed: isActive ? () => ctrl.skip(const Duration(seconds: 30)) : null,
            ),
            TextButton(
              onPressed: isActive
                  ? () {
                      final speeds = [0.75, 1.0, 1.25, 1.5];
                      final next = speeds[(speeds.indexOf(narration.speed) + 1) % speeds.length];
                      ctrl.setSpeed(next);
                    }
                  : null,
              child: Text('${narration.speed}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ]),
          if (dur > Duration.zero) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                max: dur.inMilliseconds.toDouble(),
                onChanged: isActive ? (v) => ctrl.seek(Duration(milliseconds: v.round())) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(Formatters.duration(pos), style: context.sans(10, color: p.subtle)),
                Text(Formatters.duration(dur), style: context.sans(10, color: p.subtle)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// The library of a section (ትምህርት: domain timhirt):
/// - Digital books: sub-categories filter, favorites toggle, reading progress, background narration
/// - Books to borrow: copy availability counts, request flow
/// - Circulation staff desk: per-copy checkout, borrower signatures, overdue tracking
class LibraryBooksScreen extends ConsumerWidget {
  const LibraryBooksScreen({
    super.key,
    this.domain = 'timhirt',
    this.borrowingsRoute = '/edu/borrowings',
    this.fromAdmin = false,
  });
  final String domain;
  final String borrowingsRoute;
  final bool fromAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final canCirculate = user?.can('library.circulate') == true || user?.isAdmin == true;
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (canPop) {
          Navigator.of(context).pop();
        } else if (fromAdmin) {
          context.go('/edu/admin');
        } else if (domain == 'timhirt') {
          context.go('/edu');
        } else {
          context.go('/home');
        }
      },
      child: DefaultTabController(
        length: 3,
        child: PatternScaffold(
          appBar: AppBar(
            leading: (fromAdmin || canPop)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      if (canPop) {
                        Navigator.of(context).pop();
                      } else if (fromAdmin) {
                        context.go('/edu/admin');
                      } else if (domain == 'timhirt') {
                        context.go('/edu');
                      } else {
                        context.go('/home');
                      }
                    },
                  )
                : null,
            title: Text(l.libTitle),
            actions: [
              if (canCirculate)
                IconButton(
                  key: const ValueKey('library-circulation-action-btn'),
                  tooltip: l.libCirculation,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: () => context.push('/edu/circulation'),
                ),
            ],
            bottom: TabBar(tabs: [
              Tab(text: l.libDigital),
              Tab(text: l.libPhysical),
              Tab(text: l.libMine),
            ]),
          ),
          body: TabBarView(children: [
            _BookList(domain: domain, kind: 'digital'),
            _BookList(domain: domain, kind: 'physical', canCirculate: canCirculate),
            _Mine(borrowingsRoute: borrowingsRoute),
          ]),
        ),
      ),
    );
  }
}

class _BookList extends ConsumerStatefulWidget {
  const _BookList({required this.domain, required this.kind, this.canCirculate = false});
  final String domain;
  final String kind;
  final bool canCirculate;

  @override
  ConsumerState<_BookList> createState() => _BookListState();
}

class _BookListState extends ConsumerState<_BookList> with AutomaticKeepAliveClientMixin {
  final _ctrl = PagedListController<Book>();
  String _q = '';
  int? _selectedCategoryId;
  bool _favoritesOnly = false;
  late final Future<List<LibraryCategory>> _categories = ref.read(libraryRepositoryProvider).categories(domain: widget.domain);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;

    return Column(children: [
      if (widget.kind == 'physical' && widget.canCirculate)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: TrackTile(
            key: const ValueKey('library-circulation-banner-tile'),
            title: l.libCirculation,
            subtitle: l.libCheckout,
            leading: const ListThumb(icon: Icons.swap_horiz_rounded, active: true),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/edu/circulation'),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SearchBox(onChanged: (v) => setState(() => _q = v)),
      ),
      // Categories filter chips & Favorites toggle (F16)
      if (widget.kind == 'digital') ...[
        FutureBuilder<List<LibraryCategory>>(
          future: _categories,
          builder: (context, snap) {
            final cats = snap.data ?? const [];
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                FilterChip(
                  key: const ValueKey('cat-chip-all'),
                  label: Text(l.all),
                  selected: _selectedCategoryId == null && !_favoritesOnly,
                  onSelected: (_) => setState(() {
                    _selectedCategoryId = null;
                    _favoritesOnly = false;
                  }),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  key: const ValueKey('cat-chip-favorites'),
                  avatar: Icon(
                    _favoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 16,
                    color: _favoritesOnly ? AppColors.goldDark : null,
                  ),
                  label: Text(l.libFavorites),
                  selected: _favoritesOnly,
                  onSelected: (val) => setState(() {
                    _favoritesOnly = val;
                    if (val) _selectedCategoryId = null;
                  }),
                ),
                for (final c in cats) ...[
                  const SizedBox(width: 6),
                  FilterChip(
                    key: ValueKey('cat-chip-${c.id}'),
                    label: Text(lang == 'en' && c.nameEn != null ? c.nameEn! : c.name),
                    selected: _selectedCategoryId == c.id,
                    onSelected: (_) => setState(() {
                      _selectedCategoryId = c.id;
                      _favoritesOnly = false;
                    }),
                  ),
                ],
              ]),
            );
          },
        ),
      ],
      Expanded(
        child: PagedListView<Book>(
          key: ValueKey('${widget.kind}-$_q-$_selectedCategoryId-$_favoritesOnly'),
          controller: _ctrl,
          emptyMessage: l.libNoBooks,
          emptyIcon: widget.kind == 'digital' ? Icons.picture_as_pdf_outlined : Icons.menu_book_outlined,
          fetch: (page) => ref.read(libraryRepositoryProvider).books(
                domain: widget.domain,
                kind: widget.kind,
                q: _q.isEmpty ? null : _q,
                categoryId: _selectedCategoryId,
                favoritesOnly: _favoritesOnly ? true : null,
                page: page,
              ),
          itemBuilder: (context, b, _) => BookCard(
            book: b,
            onChanged: () => _ctrl.refresh(),
          ),
        ),
      ),
    ]);
  }
}

/// One book card:
/// - Favorite toggle button (F16)
/// - Reading progress indicator (F16)
/// - Background Narration player button (F16)
/// - Availability counts (F17)
class BookCard extends ConsumerStatefulWidget {
  const BookCard({super.key, required this.book, required this.onChanged});
  final Book book;
  final VoidCallback onChanged;
  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _downloaded = false;
  double? _progress;
  late bool _isFavorite = widget.book.isFavorite;

  @override
  void initState() {
    super.initState();
    if (widget.book.isDigital) {
      BookVault.has(widget.book.id).then((v) => mounted ? setState(() => _downloaded = v) : null);
    }
  }

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    try {
      final res = await ref.read(libraryRepositoryProvider).toggleFavorite(widget.book.id);
      if (mounted && res != _isFavorite) setState(() => _isFavorite = res);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !next);
    }
  }

  bool _isSubmitting = false;

  void _handleTap() {
    final b = widget.book;
    final l = context.l10n;
    if (b.isDigital) {
      if (b.fileUrl == null || b.fileUrl!.isEmpty) {
        showSnack(context, l.isEn ? 'Book file is not available' : 'የመጽሐፉ ፋይል አልተገኘም');
        return;
      }
      if (_downloaded) {
        _open();
      } else if (_progress == null) {
        _download();
      }
    } else {
      if (b.myRequest != null) {
        final status = b.myRequest!;
        final msg = (status == 'issued' || status == 'borrowed' || status == 'active')
            ? (l.isEn ? 'You currently have this book borrowed.' : 'ይህንን መጽሐፍ ወስደዋል።')
            : (l.isEn ? 'Your request is currently: $status' : 'የውሰት ጥያቄዎ ሁኔታ፡ ${bookRequestStatusLabel(l, status)}');
        showSnack(context, msg);
      } else if (b.effectiveAvailable > 0 || (b.available ?? 0) > 0) {
        if (!_isSubmitting) {
          _request();
        }
      } else {
        showSnack(context, l.libNoneAvailable);
      }
    }
  }

  Future<void> _download() async {
    final b = widget.book;
    if (b.fileUrl == null || b.fileUrl!.isEmpty) {
      if (mounted) {
        showSnack(context, context.l10n.isEn ? 'Book file is not available' : 'የመጽሐፉ ፋይል አልተገኘም');
      }
      return;
    }
    setState(() => _progress = 0);
    try {
      final pdf = await ref.read(libraryRepositoryProvider).downloadBook(b, onProgress: (r, t) {
        if (t > 0 && mounted) setState(() => _progress = r / t);
      });
      await BookVault.save(b.id, pdf);
      if (mounted) setState(() => _downloaded = true);
      await _open();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _open() async {
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: widget.book)),
    );
    final still = await BookVault.has(widget.book.id);
    if (mounted && still != _downloaded) setState(() => _downloaded = still);
    widget.onChanged();
  }

  Future<void> _remove() async {
    await BookVault.remove(widget.book.id);
    if (mounted) setState(() => _downloaded = false);
  }

  Future<void> _playNarration() async {
    final narrationCtrl = ref.read(narrationControllerProvider.notifier);
    await narrationCtrl.playBook(widget.book);
  }

  Future<void> _request() async {
    if (_isSubmitting) return;
    final l = context.l10n;
    final note = TextEditingController();
    DateTime? needed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.libRequestTitle),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.book.title, style: context.sans(14, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: l.libRequestNote)),
            const SizedBox(height: 10),
            DateTimeField(label: l.libNeededOn, value: needed, withTime: false, clearable: true, onChanged: (d) => setS(() => needed = d)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(key: const ValueKey('book-request-send'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.libRequest)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      final r = await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).request(
          widget.book.id,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          neededOn: needed == null ? null : Formatters.isoDate(needed!),
        ),
        success: l.libRequestSent,
      );
      if (r != null && mounted) widget.onChanged();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final b = widget.book;

    final Widget action;
    if (b.isDigital) {
      if (b.fileUrl == null || b.fileUrl!.isEmpty) {
        action = Pill(
          l.isEn ? 'File not uploaded' : 'ፋይል አልተጫነም',
          color: p.muted,
        );
      } else {
        action = _progress != null
            ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(value: _progress, strokeWidth: 3))
            : _downloaded
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: l.libDeleteDownload, icon: const Icon(Icons.delete_outline_rounded), onPressed: _remove),
                    FilledButton.tonal(key: ValueKey('book-open-${b.id}'), onPressed: _open, child: Text(l.libRead)),
                  ])
                : FilledButton.icon(
                    key: ValueKey('book-download-${b.id}'),
                    onPressed: _download,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(l.libDownload),
                  );
      }
    } else if (b.myRequest != null) {
      final status = b.myRequest!;
      if (status == 'issued' || status == 'borrowed' || status == 'active') {
        action = Pill(l.isEn ? 'Borrowed' : 'ተወስዷል', color: const Color(0xFF1F5F8B));
      } else {
        action = Pill(bookRequestStatusLabel(l, status), color: bookRequestStatusColor(status));
      }
    } else if (b.effectiveAvailable <= 0 && (b.available ?? 0) <= 0) {
      action = OutlinedButton(
        onPressed: null,
        child: Text(l.libNoneAvailable),
      );
    } else {
      action = FilledButton(
        key: ValueKey('book-request-${b.id}'),
        onPressed: _isSubmitting ? null : _request,
        child: _isSubmitting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(l.libRequest),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: AppCard(
        onTap: _handleTap,
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 68,
            height: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CoverImage(
                url: b.coverUrl,
                placeholderIcon: b.isDigital ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.title, style: context.serif(15, weight: FontWeight.w600)),
                    if (b.author != null) Text(b.author!, style: context.sans(12, color: p.muted)),
                  ]),
                ),
                IconButton(
                  key: ValueKey('book-fav-btn-${b.id}'),
                  tooltip: _isFavorite ? l.libRemoveFromFavorites : l.libAddToFavorites,
                  icon: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFavorite ? AppColors.goldDark : p.subtle,
                    size: 22,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                [
                  b.code,
                  ?b.categoryName ?? b.category,
                  if (b.isDigital && b.fileSize != null) Formatters.fileSize(b.fileSize!),
                  if (b.isDigital && _downloaded) l.libDownloaded,
                  if (b.isDigital && _isFavorite && !_downloaded) l.libDownloadToReadOffline,
                  if (!b.isDigital)
                    b.effectiveTotal > 0
                        ? l.libCopiesAvailable(b.effectiveAvailable, b.effectiveTotal)
                        : (b.available ?? 0) > 0
                            ? l.libAvailable('${b.available}')
                            : l.libNoneAvailable,
                ].join(' · '),
                style: context.sans(11, color: p.subtle),
              ),
              if (b.progress != null && b.progress!.page > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.bookmark_added_rounded, size: 14, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(
                    b.progress!.pageCount != null
                        ? l.libProgress(b.progress!.page, b.progress!.pageCount!)
                        : 'Page ${b.progress!.page}',
                    style: context.sans(11, color: AppColors.goldDark, weight: FontWeight.w600),
                  ),
                ]),
              ],
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (b.hasNarration)
                  OutlinedButton.icon(
                    key: ValueKey('book-narration-btn-${b.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _playNarration,
                    icon: const Icon(Icons.headphones_rounded, size: 16, color: AppColors.gold),
                    label: Text(l.libListenNarration, style: const TextStyle(fontSize: 12)),
                  )
                else
                  const SizedBox.shrink(),
                action,
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Mine extends ConsumerStatefulWidget {
  const _Mine({required this.borrowingsRoute});
  final String borrowingsRoute;
  @override
  ConsumerState<_Mine> createState() => _MineState();
}

class _MineState extends ConsumerState<_Mine> {
  final _ctrl = PagedListController<BookRequest>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return PagedListView<BookRequest>(
      controller: _ctrl,
      emptyMessage: l.libNoRequests,
      emptyIcon: Icons.outbox_outlined,
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TrackTile(
          key: const ValueKey('library-my-borrowings'),
          title: l.myBorrowings,
          subtitle: l.eduBorrowingsSub,
          leading: const ListThumb(icon: Icons.menu_book_rounded, active: true),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(widget.borrowingsRoute),
        ),
        SectionHeader(title: l.libMyRequests),
      ]),
      fetch: (page) => ref.read(libraryRepositoryProvider).myRequests(page: page),
      itemBuilder: (context, r, _) => TrackTile(
        title: r.bookTitle,
        subtitle: [bookRequestStatusLabel(l, r.status), if (r.createdAt != null) f.date(r.createdAt), ?r.reviewNote].join(' · '),
        leading: ListThumb(icon: Icons.menu_book_outlined, imageUrl: r.bookCoverUrl),
        trailing: r.isOpen
            ? IconButton(
                tooltip: l.libCancelRequest,
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  if (!await showConfirm(context, '${l.libCancelRequest}?') || !context.mounted) return;
                  final x = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).cancel(r.id));
                  if (x != null) await _ctrl.refresh();
                },
              )
            : Icon(Icons.circle, size: 10, color: bookRequestStatusColor(r.status)),
        onTap: r.borrowingId != null ? () => context.push('${widget.borrowingsRoute}/${r.borrowingId}') : null,
      ),
    );
  }
}
