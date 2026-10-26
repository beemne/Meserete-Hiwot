import 'json.dart';

class Crumb {
  const Crumb(this.id, this.name);
  final int id;
  final String name;
  factory Crumb.fromJson(Json j) => Crumb(asIntOr(j['id']), asStr(j['name']) ?? '');
}

class CategoryNode {
  const CategoryNode({
    required this.id,
    this.parentId,
    required this.name,
    this.description,
    this.imageUrl,
    this.icon,
    this.displayOrder = 0,
    this.isActive = true,
    this.isToday = false,
    this.depth = 0,
    this.mezmurCount = 0,
    this.totalMezmurCount = 0,
    this.childCount = 0,
    this.children = const [],
    this.breadcrumb = const [],
  });

  final int id;
  final int? parentId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? icon;
  final int displayOrder;
  final bool isActive;
  final bool isToday;
  final int depth;
  final int mezmurCount;
  final int totalMezmurCount;
  final int childCount;
  final List<CategoryNode> children;
  final List<Crumb> breadcrumb;

  factory CategoryNode.fromJson(Json j) {
    final children = asList(j['children'], CategoryNode.fromJson);
    return CategoryNode(
      id: asIntOr(j['id']),
      parentId: asInt(j['parent_id']),
      name: asStr(j['name']) ?? '',
      description: asStr(j['description']),
      imageUrl: asStr(j['image_url']),
      icon: asStr(j['icon']),
      displayOrder: asIntOr(j['display_order']),
      isActive: j['is_active'] == null || asBool(j['is_active']),
      isToday: asBool(j['is_today']),
      depth: asIntOr(j['depth']),
      mezmurCount: asIntOr(j['mezmur_count']),
      totalMezmurCount: asIntOr(j['total_mezmur_count'], asIntOr(j['mezmur_count'])),
      childCount: asIntOr(j['child_count'], children.length),
      children: children,
      breadcrumb: asList(j['breadcrumb'], Crumb.fromJson),
    );
  }

  Json toJson() => {
        'id': id,
        'parent_id': parentId,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'icon': icon,
        'display_order': displayOrder,
        'is_active': isActive,
        'is_today': isToday,
        'depth': depth,
        'mezmur_count': mezmurCount,
        'total_mezmur_count': totalMezmurCount,
        'child_count': childCount,
        'children': children.map((c) => c.toJson()).toList(),
      };

  /// Depth-first flatten (used by admin pickers and client-side category search).
  Iterable<CategoryNode> flatten() sync* {
    yield this;
    for (final c in children) {
      yield* c.flatten();
    }
  }
}

class MezmurSummary {
  const MezmurSummary({
    required this.id,
    required this.title,
    this.excerpt = '',
    this.categoryId,
    this.categoryName,
    this.coverUrl,
    this.hasAudio = false,
    this.audioUrl,
    this.audioDurationSec,
    this.isFeatured = false,
    this.isToday = false,
    this.isFavorite = false,
    this.favoriteCount = 0,
    this.status = 'published',
    this.contentVersion = 1,
    this.publishedAt,
  });

  final int id;
  final String title;
  final String excerpt;
  final int? categoryId;
  final String? categoryName;
  final String? coverUrl;
  final bool hasAudio;

  /// Streaming URL (list items), so the player can queue the next / previous Mezmur.
  final String? audioUrl;
  final int? audioDurationSec;
  final bool isFeatured;

  /// Marked by an admin as "ዛሬ የሚጠኑ" (practised today).
  final bool isToday;
  final bool isFavorite;
  final int favoriteCount;
  final String status;
  final int contentVersion;
  final DateTime? publishedAt;

  factory MezmurSummary.fromJson(Json j) {
    final cat = asJson(j['category']);
    return MezmurSummary(
      id: asIntOr(j['id']),
      title: asStr(j['title']) ?? '',
      excerpt: asStr(j['excerpt']) ?? '',
      categoryId: asInt(cat['id']),
      categoryName: asStr(cat['name']),
      coverUrl: asStr(j['cover_url']),
      hasAudio: asBool(j['has_audio']) || j['audio'] is Map,
      audioUrl: asStr(j['audio_url']) ?? asStr(asJson(j['audio'])['url']),
      audioDurationSec: asInt(j['audio_duration_sec']),
      isFeatured: asBool(j['is_featured']),
      isToday: asBool(j['is_today']),
      isFavorite: asBool(j['is_favorite']),
      favoriteCount: asIntOr(j['favorite_count']),
      status: asStr(j['status']) ?? 'published',
      contentVersion: asIntOr(j['content_version'], 1),
      publishedAt: asDate(j['published_at']),
    );
  }
}

class AudioInfo {
  const AudioInfo({required this.url, this.mime, this.size, this.durationSec});
  final String url;
  final String? mime;
  final int? size;
  final int? durationSec;
  factory AudioInfo.fromJson(Json j) =>
      AudioInfo(url: asStr(j['url']) ?? '', mime: asStr(j['mime']), size: asInt(j['size']), durationSec: asInt(j['duration_sec']));
}

class Mezmur {
  const Mezmur({
    required this.summary,
    required this.lyrics,
    this.description,
    this.tags = const [],
    this.audio,
    this.breadcrumb = const [],
    this.related = const [],
    this.queue = const [],
    this.isDownloaded = false,
    this.localAudioPath,
    this.localCoverPath,
    this.youtubeUrl,
    this.lrc,
    this.raw = const {},
  });

  final MezmurSummary summary;
  final String lyrics;

  /// Time-synced lyrics (.lrc), when an administrator added them.
  final String? lrc;
  final String? description;
  final List<String> tags;
  final AudioInfo? audio;
  final List<Crumb> breadcrumb;
  final List<MezmurSummary> related;

  /// The player queue: this Mezmur's category and subcategories in folder order (itself included).
  final List<MezmurSummary> queue;
  final bool isDownloaded;

  /// Set when served from the offline store.
  final String? localAudioPath;
  final String? localCoverPath;

  /// Optional YouTube link set by administrators.
  final String? youtubeUrl;

  /// Original JSON (persisted for offline copies).
  final Json raw;

  int get id => summary.id;
  String get title => summary.title;
  bool get hasAudio => audio != null || localAudioPath != null;

  factory Mezmur.fromJson(Json j, {String? localAudioPath, String? localCoverPath}) => Mezmur(
        summary: MezmurSummary.fromJson(j),
        lyrics: asStr(j['lyrics']) ?? '',
        description: asStr(j['description']),
        tags: (j['tags'] as List? ?? const []).map((e) => '$e').toList(),
        audio: j['audio'] is Map ? AudioInfo.fromJson(asJson(j['audio'])) : null,
        breadcrumb: asList(j['breadcrumb'], Crumb.fromJson),
        related: asList(j['related'], MezmurSummary.fromJson),
        queue: asList(j['queue'], MezmurSummary.fromJson),
        isDownloaded: asBool(j['is_downloaded']),
        localAudioPath: localAudioPath,
        localCoverPath: localCoverPath,
        youtubeUrl: asStr(j['youtube_url']),
        lrc: asStr(j['lrc']),
        raw: j,
      );
}

/// A file (PDF / image) or web link attached to a banner.
class BannerAttachment {
  const BannerAttachment({required this.id, required this.kind, this.title, required this.url, this.mime});
  final int id;
  final String kind; // file | link
  final String? title;
  final String url;
  final String? mime;

  bool get isPdf => mime == 'application/pdf' || url.toLowerCase().endsWith('.pdf');
  bool get isImage => (mime ?? '').startsWith('image/');

  factory BannerAttachment.fromJson(Json j) => BannerAttachment(
        id: asIntOr(j['id']),
        kind: asStr(j['kind']) ?? 'link',
        title: asStr(j['title']),
        url: asStr(j['url']) ?? '',
        mime: asStr(j['mime']),
      );
}

class Banner {
  const Banner({required this.id, required this.kind, required this.title, this.shortDescription, this.imageUrl, this.targetType, this.targetId, this.attachments = const []});
  final int id;
  final String kind;
  final String title;
  final String? shortDescription;
  final String? imageUrl;
  final String? targetType; // 'page' | 'program'
  final int? targetId;
  final List<BannerAttachment> attachments;

  factory Banner.fromJson(Json j) {
    final t = asJson(j['target']);
    return Banner(
      id: asIntOr(j['id']),
      kind: asStr(j['kind']) ?? 'advertisement',
      title: asStr(j['title']) ?? '',
      shortDescription: asStr(j['short_description']),
      imageUrl: asStr(j['image_url']),
      targetType: asStr(t['type']),
      targetId: asInt(t['id']),
      attachments: asList(j['attachments'], BannerAttachment.fromJson),
    );
  }
}

class PageContent {
  const PageContent({
    required this.id,
    required this.title,
    this.summary,
    this.coverUrl,
    this.content = '',
    this.eventDate,
    this.location,
    this.ctaLabel,
    this.ctaAction,
    this.ctaTargetId,
    this.ctaUrl,
    this.ctaTargetTitle,
    this.ctaClassId,
    this.programId,
    this.programTitle,
    this.images = const [],
    this.status = 'published',
  });

  final int id;
  final String title;
  final String? summary;
  final String? coverUrl;
  final String content;
  final DateTime? eventDate;
  final String? location;
  final String? ctaLabel;
  final String? ctaAction;
  final int? ctaTargetId;

  /// open_url: the https link.
  final String? ctaUrl;
  final String? ctaTargetTitle;

  /// open_course / open_assignment: the class that holds it (members open the class).
  final int? ctaClassId;
  final int? programId;
  final String? programTitle;
  final List<({int id, String url, String? caption})> images;
  final String status;

  factory PageContent.fromJson(Json j) {
    final cta = asJson(j['cta']);
    final program = asJson(j['program']);
    return PageContent(
      id: asIntOr(j['id']),
      title: asStr(j['title']) ?? '',
      summary: asStr(j['summary']),
      coverUrl: asStr(j['cover_url']),
      content: asStr(j['content']) ?? '',
      eventDate: asDate(j['event_date']),
      location: asStr(j['location']),
      ctaLabel: asStr(cta['label']),
      ctaAction: asStr(cta['action']),
      ctaTargetId: asInt(cta['target_id']),
      ctaUrl: asStr(cta['url']),
      ctaTargetTitle: asStr(cta['target_title']),
      ctaClassId: asInt(cta['class_id']),
      programId: asInt(program['id']),
      programTitle: asStr(program['title']),
      images: asJsonList(j['images']).map((i) => (id: asIntOr(i['id']), url: asStr(i['url']) ?? '', caption: asStr(i['caption']))).toList(),
      status: asStr(j['status']) ?? 'published',
    );
  }
}
