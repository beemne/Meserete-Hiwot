import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../services/file_opening_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../../core/network/api_exception.dart';
import '../admin/admin_widgets.dart' show DateTimeField;
import '../guidance/contextual_help_sheet.dart';
import '../projects/pm_common.dart';
import '../settings/account_screens.dart' show SubPage;
import '../../widgets/typed_picker.dart';

/// Department chats the user belongs to (the Super Admin: every department), with unread counts.
final chatOverviewProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(chatRepositoryProvider).overview());

/// The conversation on screen (`department|thread`): its pushes are not shown as notifications.
final activeChat = ValueNotifier<String?>(null);

String _deptName(BuildContext context, Json d) {
  final en = Localizations.localeOf(context).languageCode == 'en';
  return (en ? asStr(d['name_en']) : null) ?? asStr(d['name']) ?? '—';
}

/// Chat list: one row per department.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final data = ref.watch(chatOverviewProvider);
    return SubPage(
      title: l.chatTitle,
      actions: const [
        ContextualHelpButton(screenRoute: '/chat'),
      ],
      body: AsyncView(
        value: data,
        onRetry: () => ref.invalidate(chatOverviewProvider),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(chatOverviewProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 80), child: EmptyView(message: l.chatNone, icon: Icons.forum_outlined)),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(builder: (context) {
                    final d = asJson(r['department']);
                    final last = asJson(r['last_message']);
                    final unread = asIntOr(r['unread_group']) + asIntOr(r['unread_private']);
                    return TrackTile(
                      key: ValueKey('chat-dept-${d['id']}'),
                      title: _deptName(context, d),
                      subtitle: last.isEmpty ? l.chatNoMessages : '${asJson(last['sender'])['full_name']}: ${_preview(l, last)}',
                      leading: ListThumb(icon: r['is_leader'] == true ? Icons.workspace_premium_rounded : Icons.forum_outlined, active: r['is_leader'] == true),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (last.isNotEmpty) Text(f.shortDate(asDate(last['created_at'])), style: context.sans(11, color: p.muted)),
                        if (unread > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Pill('$unread', background: AppColors.maroon, color: Colors.white)),
                      ]),
                      onTap: () async {
                        final isAdmin = GoRouterState.of(context).matchedLocation.startsWith('/admin');
                        final path = isAdmin ? '/admin/chat/${d['id']}' : '/settings/chat/${d['id']}';
                        await context.push(path);
                        ref.invalidate(chatOverviewProvider);
                      },
                    );
                  }),
                ),
              const SizedBox(height: 8),
              Text(l.chatVoiceInfo, style: context.sans(12, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

String _preview(AppLocalizations l, Json m) {
  if (m['deleted'] == true) return l.chatDeleted;
  return switch ('${m['kind']}') {
    'image' => '🖼 ${asStr(m['body']) ?? l.chatPhoto}',
    'audio' => '🎵 ${asStr(m['body']) ?? asStr(asJson(m['attachment'])['name']) ?? ''}',
    'video' => '🎬 ${asStr(m['body']) ?? asStr(asJson(m['attachment'])['name']) ?? ''}',
    'file' => '📄 ${asStr(asJson(m['attachment'])['name']) ?? asStr(m['body']) ?? ''}',
    'meeting' => '📞 ${l.chatMeetingTitle}',
    'task_bot' => (asStr(m['body']) ?? '').split('\n').first,
    _ => asStr(m['body']) ?? '',
  };
}

/// A department's room: the group conversation, with the private messages one tap away.
class DepartmentChatScreen extends ConsumerWidget {
  const DepartmentChatScreen({super.key, required this.departmentId});
  final int departmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConversationScreen(departmentId: departmentId, thread: 'group');
}

/// Private conversations in a department, and who the user may write to.
class ChatThreadsScreen extends ConsumerStatefulWidget {
  const ChatThreadsScreen({super.key, required this.departmentId});
  final int departmentId;

  @override
  ConsumerState<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends ConsumerState<ChatThreadsScreen> {
  late Future<List<Json>> _threads = ref.read(chatRepositoryProvider).threads(widget.departmentId);

  Future<void> _reload() async => setState(() => _threads = ref.read(chatRepositoryProvider).threads(widget.departmentId));

  Future<void> _newMessage() async {
    final l = context.l10n;
    final contacts = await runWithProgress(context, () => ref.read(chatRepositoryProvider).contacts(widget.departmentId));
    if (contacts == null || !mounted) return;
    final picked = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(l.chatNewPrivate, style: ctx.serif(17))),
            if (contacts.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noResults)),
            for (final c in contacts)
              ListTile(
                leading: _Avatar(url: asStr(c['avatar_url']), name: '${c['full_name']}'),
                title: Text('${c['full_name']}'),
                subtitle: Text([if (c['member_id'] != null) '${c['member_id']}', if (c['is_leader'] == true) l.chatLeader].join(' · ')),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final isAdmin = GoRouterState.of(context).matchedLocation.startsWith('/admin');
    final base = isAdmin ? '/admin/chat' : '/settings/chat';
    await context.push('$base/${widget.departmentId}/user/${picked['id']}?name=${Uri.encodeComponent('${picked['full_name']}')}');
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return SubPage(
      title: l.chatPrivate,
      fab: FloatingActionButton.extended(
        key: const ValueKey('chat-new-private'),
        onPressed: _newMessage,
        icon: const Icon(Icons.edit_outlined),
        label: Text(l.chatNewPrivate),
      ),
      body: FutureBuilder<List<Json>>(
        future: _threads,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final rows = snap.data!;
          if (rows.isEmpty) return EmptyView(message: l.chatNoThreads, icon: Icons.mark_chat_unread_outlined);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              for (final t in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(builder: (context) {
                    final peer = asJson(t['peer']);
                    final last = asJson(t['last_message']);
                    final unread = asIntOr(t['unread']);
                    return TrackTile(
                      title: '${peer['full_name']}',
                      subtitle: [if (peer['member_id'] != null) '${peer['member_id']}', _preview(l, last)].join(' · '),
                      leading: _Avatar(url: asStr(peer['avatar_url']), name: '${peer['full_name']}'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(f.shortDate(asDate(last['created_at'])), style: context.sans(11, color: p.muted)),
                        if (unread > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Pill('$unread', background: AppColors.maroon, color: Colors.white)),
                      ]),
                      onTap: () async {
                        final isAdmin = GoRouterState.of(context).matchedLocation.startsWith('/admin');
                        final base = isAdmin ? '/admin/chat' : '/settings/chat';
                        await context.push('$base/${widget.departmentId}/user/${peer['id']}?name=${Uri.encodeComponent('${peer['full_name']}')}');
                        unawaited(_reload());
                      },
                    );
                  }),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});
  final String? url;
  final String name;
  static const double radius = 20;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: context.palette.pill,
        backgroundImage: url != null ? NetworkImage(url!) : null,
        child: url == null ? Text(name.isEmpty ? '?' : name.characters.first, style: context.serif(radius * 0.8)) : null,
      );
}

/// One conversation (the group, or `user:<id>`): history with the sender of every message, new
/// messages by polling every few seconds while open, older ones on demand.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.departmentId, required this.thread, this.peerName});
  final int departmentId;
  final String thread;
  final String? peerName;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> with WidgetsBindingObserver {
  final _messages = <Json>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Json _dept = const {};
  bool _canSendMedia = false;
  bool _isLeader = false;
  bool _loading = true;
  bool _hasOlder = true;
  bool _sending = false;
  double? _progress;
  Object? _error;
  Timer? _poll;

  String get _key => '${widget.departmentId}|${widget.thread}';
  int get _lastId => _messages.isEmpty ? 0 : asIntOr(_messages.last['id']);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    activeChat.value = _key;
    unawaited(_load());
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_poll2()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (activeChat.value == _key) activeChat.value = null;
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      activeChat.value = _key;
      unawaited(_poll2());
    } else if (state == AppLifecycleState.paused && activeChat.value == _key) {
      activeChat.value = null;
    }
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(chatRepositoryProvider).messages(widget.departmentId, thread: widget.thread);
      if (!mounted) return;
      setState(() {
        _dept = asJson(r['department']);
        _canSendMedia = r['can_send_media'] == true;
        _isLeader = r['is_leader'] == true || _dept['is_leader'] == true || _dept['role'] == 'leader' || _dept['role'] == 'supervisor';
        _messages
          ..clear()
          ..addAll(asJsonList(r['items']));
        _hasOlder = _messages.length >= 50;
        _loading = false;
        _error = null;
      });
      _markRead();
      _toBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _poll2() async {
    if (_loading || _error != null || !mounted) return;
    try {
      final r = await ref.read(chatRepositoryProvider).messages(widget.departmentId, thread: widget.thread, after: _lastId);
      final fresh = asJsonList(r['items']).where((m) => !_messages.any((x) => x['id'] == m['id'])).toList();
      if (fresh.isEmpty || !mounted) return;
      final atBottom = !_scroll.hasClients || _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
      setState(() => _messages.addAll(fresh));
      _markRead();
      if (atBottom) _toBottom();
    } catch (_) {
      // offline — the next tick tries again
    }
  }

  Future<void> _older() async {
    if (_messages.isEmpty) return;
    try {
      final r = await ref.read(chatRepositoryProvider).messages(widget.departmentId, thread: widget.thread, before: asIntOr(_messages.first['id']));
      final items = asJsonList(r['items']);
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, items);
        _hasOlder = items.length >= 50;
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(context.l10n, e));
    }
  }

  void _markRead() {
    if (_messages.isEmpty) return;
    unawaited(ref.read(chatRepositoryProvider).markRead(widget.departmentId, widget.thread, _lastId).catchError((_) {}));
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _added(Json m) {
    if (!mounted) return;
    setState(() {
      if (!_messages.any((x) => x['id'] == m['id'])) _messages.add(m);
    });
    _toBottom();
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await ref.read(chatRepositoryProvider).sendText(widget.departmentId, widget.thread, text);
      _input.clear();
      _added(m);
    } catch (e) {
      if (mounted) showSnack(context, errorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendFile(String path, {String? name}) async {
    final caption = _input.text.trim();
    setState(() {
      _sending = true;
      _progress = 0;
    });
    try {
      final m = await ref.read(chatRepositoryProvider).sendFile(widget.departmentId, widget.thread, path,
          caption: caption, filename: name, onProgress: (v) => mounted ? setState(() => _progress = v) : null);
      _input.clear();
      _added(m);
    } catch (e) {
      if (mounted) showSnack(context, errorText(context.l10n, e));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _attach() async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_outlined), title: Text(l.chatPhoto), onTap: () => Navigator.pop(ctx, 'photo')),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l.chatCamera), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(key: const ValueKey('chat-attach-video'), leading: const Icon(Icons.video_library_outlined), title: Text(l.pickVideo), onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(key: const ValueKey('chat-attach-audio'), leading: const Icon(Icons.audiotrack_rounded), title: Text(l.pickAudio), onTap: () => Navigator.pop(ctx, 'audio')),
          ListTile(key: const ValueKey('chat-attach-document'), leading: const Icon(Icons.description_outlined), title: Text(l.pickDocument), onTap: () => Navigator.pop(ctx, 'document')),
          if (_isLeader)
            ListTile(key: const ValueKey('chat-attach-meeting'), leading: const Icon(Icons.record_voice_over_outlined), title: Text(l.chatMeeting), onTap: () => Navigator.pop(ctx, 'meeting')),
        ])),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'photo':
      case 'camera':
        final x = await ImagePicker().pickImage(source: choice == 'photo' ? ImageSource.gallery : ImageSource.camera, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
        if (x != null) await _sendFile(x.path, name: x.name);
      case 'video':
      case 'audio':
      case 'document':
        final f = await pickOfKind(choice);
        if (f != null) await _sendFile(f.path, name: f.name);
      case 'meeting':
        await _meeting();
    }
  }

  Future<void> _meeting() async {
    final l = context.l10n;
    final url = TextEditingController();
    final note = TextEditingController();
    DateTime? at;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(l.chatMeeting),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.chatVoiceInfo, style: ctx.sans(12, color: ctx.palette.muted)),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('chat-meeting-url'), controller: url, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: l.chatMeetingUrl, hintText: 'https://meet.jit.si/…')),
            const SizedBox(height: 8),
            TextField(controller: note, decoration: InputDecoration(labelText: l.chatMeetingNote)),
            const SizedBox(height: 8),
            DateTimeField(label: l.chatMeetingWhen, value: at, clearable: true, onChanged: (v) => setS(() => at = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.chatSend)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final m = await runWithProgress(context, () => ref.read(chatRepositoryProvider).sendMeeting(widget.departmentId, widget.thread, url: url.text.trim(), note: note.text.trim(), at: at));
    if (m != null) _added(m);
  }

  Future<void> _delete(Json m) async {
    final l = context.l10n;
    if (!await showConfirm(context, l.chatDeleteConfirm, destructive: true)) return;
    if (!mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(chatRepositoryProvider).delete(widget.departmentId, asIntOr(m['id']));
      return true;
    });
    if (ok == true && mounted) {
      setState(() {
        final i = _messages.indexWhere((x) => x['id'] == m['id']);
        if (i >= 0) _messages[i] = {..._messages[i], 'deleted': true, 'body': null, 'attachment': null, 'meeting': null};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final group = widget.thread == 'group';
    final title = group ? (_dept.isEmpty ? l.chatTitle : _deptName(context, _dept)) : (widget.peerName ?? l.chatPrivate);
    final isLeader = _isLeader;
    return SubPage(
      title: title,
      actions: [
        if (group)
          IconButton(
            key: const ValueKey('chat-private'),
            tooltip: l.chatPrivate,
            icon: const Icon(Icons.mark_chat_unread_outlined),
            onPressed: () {
              final isAdmin = GoRouterState.of(context).matchedLocation.startsWith('/admin');
              final base = isAdmin ? '/admin/chat' : '/settings/chat';
              context.push('$base/${widget.departmentId}/private');
            },
          ),
      ],
      body: Column(children: [
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(error: _error!, onRetry: () {
                      setState(() => _loading = true);
                      unawaited(_load());
                    })
                  : _messages.isEmpty
                      ? EmptyView(message: l.chatNoMessages, icon: Icons.forum_outlined)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: _messages.length + (_hasOlder ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (_hasOlder && i == 0) {
                              return Center(child: TextButton.icon(onPressed: _older, icon: const Icon(Icons.history_rounded), label: Text(l.chatLoadOlder)));
                            }
                            final m = _messages[i - (_hasOlder ? 1 : 0)];
                            final prev = i - (_hasOlder ? 1 : 0) > 0 ? _messages[i - (_hasOlder ? 1 : 0) - 1] : null;
                            final sameSender = prev != null && asJson(prev['sender'])['id'] == asJson(m['sender'])['id'] && prev['deleted'] != true;
                            final canDelete = m['deleted'] != true && (m['mine'] == true || (group && isLeader));
                            return _Bubble(
                              message: m,
                              showSender: group && !sameSender && m['mine'] != true,
                              onLongPress: canDelete ? () => _delete(m) : null,
                            );
                          },
                        ),
        ),
        if (_progress != null) LinearProgressIndicator(value: _progress, color: AppColors.gold),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (isLeader || _canSendMedia)
                IconButton(key: const ValueKey('chat-attach'), tooltip: l.chatAttach, onPressed: _sending ? null : _attach, icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.maroon)),
              Expanded(
                child: TextField(
                  key: const ValueKey('chat-input'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: l.chatTypeHint, counterText: '', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22))),
                ),
              ),
              IconButton(
                key: const ValueKey('chat-send'),
                tooltip: l.chatSend,
                onPressed: _sending ? null : _sendText,
                icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, color: AppColors.maroon),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showSender, this.onLongPress});
  final Json message;
  final bool showSender;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final kind = '${message['kind']}';
    // Task Bot messages are shown as the bot's, whoever triggered them.
    final bot = kind == 'task_bot';
    final mine = !bot && message['mine'] == true;
    final sender = asJson(message['sender']);
    final deleted = message['deleted'] == true;
    final body = asStr(message['body']);
    final at = asDate(message['created_at']);
    final bg = mine ? AppColors.maroon.withValues(alpha: 0.10) : p.card;
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: EdgeInsets.only(top: showSender ? 10 : 3),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: bot
                      ? Text(l.pmTaskBot, style: context.sans(12, weight: FontWeight.w700, color: AppColors.goldDark))
                      : Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text('${sender['full_name']}', style: context.sans(12, weight: FontWeight.w700, color: AppColors.maroon)),
                          if (sender['member_id'] != null) Text('${sender['member_id']}', style: context.sans(10, color: p.muted)),
                          if (sender['is_leader'] == true) Text('· ${l.chatLeader}', style: context.sans(10, weight: FontWeight.w600, color: AppColors.goldDark)),
                        ]),
                ),
              if (deleted)
                Text(l.chatDeleted, style: context.sans(13, color: p.muted).copyWith(fontStyle: FontStyle.italic))
              else ...[
                if (kind == 'image') _ChatImage(url: '${asJson(message['attachment'])['url']}'),
                if (kind == 'audio' || kind == 'video' || kind == 'file') _ChatFile(message: message),
                if (kind == 'meeting') _MeetingCard(meeting: asJson(message['meeting'])),
                if (body != null && body.isNotEmpty) Padding(padding: EdgeInsets.only(top: kind == 'text' || bot ? 0 : 6), child: SelectableText(body, style: context.sans(14, color: p.text))),
                if (bot) TaskBotActions(message: message),
              ],
              const SizedBox(height: 3),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text('${f.shortDate(at)} · ${f.time(at)}', style: context.sans(10, color: p.subtle)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Private attachments are fetched with the session (never public URLs) and kept in memory.
final _imageCache = <String, Uint8List>{};

class _ChatImage extends ConsumerStatefulWidget {
  const _ChatImage({required this.url});
  final String url;
  @override
  ConsumerState<_ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends ConsumerState<_ChatImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bytes = _imageCache[widget.url];
    if (_bytes == null) unawaited(_fetch());
  }

  Future<void> _fetch() async {
    try {
      final b = Uint8List.fromList(await ref.read(chatRepositoryProvider).attachment(widget.url));
      _imageCache[widget.url] = b;
      if (mounted) setState(() => _bytes = b);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Icon(Icons.broken_image_outlined, size: 40);
    if (_bytes == null) return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(insetPadding: const EdgeInsets.all(8), child: InteractiveViewer(child: Image.memory(_bytes!))),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_bytes!, width: 240, fit: BoxFit.cover)),
    );
  }
}

class _ChatFile extends ConsumerWidget {
  const _ChatFile({required this.message});
  final Json message;

  /// Downloads attachment via [FileOpeningService] with caching and previews in-app.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final a = asJson(message['attachment']);
    final url = asStr(a['url']);
    if (url == null || url.isEmpty) return;
    await ref.read(fileOpeningServiceProvider).openFile(
      context,
      source: url,
      filename: asStr(a['name']),
      mime: asStr(a['mime']),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final a = asJson(message['attachment']);
    final icon = switch ('${message['kind']}') { 'audio' => Icons.audiotrack_rounded, 'video' => Icons.movie_outlined, _ => Icons.description_outlined };
    return InkWell(
      onTap: () => _open(context, ref),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.maroon, size: 30),
        const SizedBox(width: 8),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(asStr(a['name']) ?? l.chatFile, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.sans(13, weight: FontWeight.w600)),
            Text('${Formatters.fileSize(asIntOr(a['size']))} · ${l.chatOpenFile}', style: context.sans(11, color: context.palette.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting});
  final Json meeting;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final url = asStr(meeting['url']);
    final at = asDate(meeting['at']);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.record_voice_over_rounded, color: AppColors.maroon),
          const SizedBox(width: 6),
          Text(l.chatMeetingTitle, style: context.sans(14, weight: FontWeight.w700)),
        ]),
        if (at != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(f.dateTime(at), style: context.sans(12))),
        if (url != null) Text(Uri.tryParse(url)?.host ?? url, style: context.sans(11, color: context.palette.muted)),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.call_rounded, size: 18),
          label: Text(l.chatMeetingJoin),
        ),
      ]),
    );
  }
}

/// Buttons under a Task Bot message. They change the REAL task (the same record as Project
/// Management); the server checks that the person is responsible for it or leads the department —
/// the buttons are only a hint, and anyone else gets "not authorized".
class TaskBotActions extends ConsumerStatefulWidget {
  const TaskBotActions({super.key, required this.message});
  final Json message;
  @override
  ConsumerState<TaskBotActions> createState() => _TaskBotActionsState();
}

class _TaskBotActionsState extends ConsumerState<TaskBotActions> {
  String? _done; // status set from here (until the next refresh)
  bool _busy = false;

  Future<void> _act(String status) async {
    final l = context.l10n;
    final body = await askStatusDetails(context, status);
    if (body == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(projectRepositoryProvider).botAction(asIntOr(widget.message['department_id']), asIntOr(widget.message['id']), body);
      if (mounted) {
        setState(() => _done = status);
        showSnack(context, l.pmBotUpdated);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 403) {
        showInfo(context, l.pmBotNotAllowed);
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bot = asJson(widget.message['bot']);
    final task = asJson(bot['task']);
    if (task.isEmpty) return const SizedBox.shrink();
    final status = _done ?? '${task['status']}';
    final actions = _done != null && const {'completed', 'cancelled'}.contains(_done) ? const <String>[] : asValues(bot['actions'], (e) => '$e');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(taskStatusIcon(status), size: 16, color: statusColor(status)),
          const SizedBox(width: 4),
          Expanded(child: Text('${task['title']} · ${taskStatusLabel(l, status)}', style: context.sans(12, weight: FontWeight.w600, color: statusColor(status)))),
          TextButton(onPressed: () => context.push('/projects/tasks/${task['id']}'), child: Text(l.pmOpenTask)),
        ]),
        if (actions.isNotEmpty && bot['can_update'] == true)
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final a in actions)
              if (a != status)
                ActionChip(
                  key: ValueKey('bot-${widget.message['id']}-$a'),
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(taskStatusIcon(a), size: 16, color: statusColor(a)),
                  label: Text(taskStatusLabel(l, a)),
                  onPressed: _busy ? null : () => _act(a),
                ),
          ]),
      ]),
    );
  }
}

