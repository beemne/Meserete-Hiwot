import 'json.dart';

class GuidanceStep {
  const GuidanceStep({
    required this.title,
    required this.description,
    this.tip,
    this.step = 1,
    this.targetKey,
    this.actionRoute,
    this.titleEn,
    this.descriptionEn,
    this.tipEn,
  });

  final String title;
  final String description;
  final String? tip;
  final int step;
  final String? targetKey;
  final String? actionRoute;
  final String? titleEn;
  final String? descriptionEn;
  final String? tipEn;

  String get instruction => description;

  String titleFor(String lang) {
    if (lang == 'en') {
      if (titleEn != null && titleEn!.isNotEmpty) return titleEn!;
      final match = RegExp(r'\(([^)]+)\)').firstMatch(title);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        return match.group(1)!.trim();
      }
      return title;
    }
    // amharic
    if (title.contains('(')) {
      final am = title.split('(').first.trim();
      if (am.isNotEmpty) return am;
    }
    return title;
  }

  String descriptionFor(String lang) {
    if (lang == 'en' && descriptionEn != null && descriptionEn!.isNotEmpty) {
      return descriptionEn!;
    }
    return description;
  }

  String? tipFor(String lang) {
    if (lang == 'en' && tipEn != null && tipEn!.isNotEmpty) {
      return tipEn;
    }
    return tip;
  }

  factory GuidanceStep.fromJson(Json j) {
    final desc = asStr(j['description']) ?? asStr(j['instruction']) ?? '';
    final tipVal = asStr(j['tip']);
    final tKey = asStr(j['target_key']) ?? asStr(j['targetKey']);
    final aRoute = asStr(j['action_route']) ?? asStr(j['actionRoute']);
    return GuidanceStep(
      title: asStr(j['title']) ?? '',
      description: desc,
      tip: tipVal,
      step: asIntOr(j['step'], 1),
      targetKey: tKey,
      actionRoute: aRoute,
      titleEn: asStr(j['title_en']),
      descriptionEn: asStr(j['description_en']),
      tipEn: asStr(j['tip_en']),
    );
  }

  Json toJson() => {
        'step': step,
        'title': title,
        'description': description,
        'instruction': description,
        if (tip != null) 'tip': tip,
        if (targetKey != null) 'target_key': targetKey,
        if (actionRoute != null) 'action_route': actionRoute,
        if (titleEn != null) 'title_en': titleEn,
        if (descriptionEn != null) 'description_en': descriptionEn,
        if (tipEn != null) 'tip_en': tipEn,
      };
}

class GuidanceFaq {
  const GuidanceFaq({
    required this.question,
    required this.answer,
    this.questionEn,
    this.answerEn,
  });

  final String question;
  final String answer;
  final String? questionEn;
  final String? answerEn;

  String questionFor(String lang) {
    if (lang == 'en') {
      if (questionEn != null && questionEn!.isNotEmpty) return questionEn!;
      final match = RegExp(r'\(([^)]+)\)').firstMatch(question);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        return match.group(1)!.trim();
      }
      return question;
    }
    if (question.contains('(')) {
      final am = question.split('(').first.trim();
      if (am.isNotEmpty) return am;
    }
    return question;
  }

  String answerFor(String lang) {
    if (lang == 'en' && answerEn != null && answerEn!.isNotEmpty) {
      return answerEn!;
    }
    return answer;
  }

  factory GuidanceFaq.fromJson(Json j) => GuidanceFaq(
        question: asStr(j['q']) ?? asStr(j['question']) ?? '',
        answer: asStr(j['a']) ?? asStr(j['answer']) ?? '',
        questionEn: asStr(j['q_en']) ?? asStr(j['question_en']),
        answerEn: asStr(j['a_en']) ?? asStr(j['answer_en']),
      );

  Json toJson() => {
        'question': question,
        'answer': answer,
        'q': question,
        'a': answer,
        if (questionEn != null) 'question_en': questionEn,
        if (answerEn != null) 'answer_en': answerEn,
      };
}

class GuidanceArticle {
  const GuidanceArticle({
    required this.id,
    required this.slug,
    required this.category,
    required this.title,
    this.summary,
    this.content = '',
    this.targetRole = 'all',
    this.targetScreen,
    this.requiredPermission,
    this.steps = const [],
    this.tips = const [],
    this.faqItems = const [],
    this.tourId,
    this.icon,
    this.sortOrder = 0,
    this.status = 'published',
    this.createdAt,
    this.updatedAt,
    this.titleEn,
    this.summaryEn,
    this.contentEn,
    this.tipsEn = const [],
  });

  final int id;
  final String slug;
  final String category;
  final String title;
  final String? summary;
  final String content;
  final String targetRole;
  final String? targetScreen;
  final String? requiredPermission;
  final List<GuidanceStep> steps;
  final List<String> tips;
  final List<GuidanceFaq> faqItems;
  final String? tourId;
  final String? icon;
  final int sortOrder;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? titleEn;
  final String? summaryEn;
  final String? contentEn;
  final List<String> tipsEn;

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isRetired => status == 'retired';
  bool get hasTour => tourId != null && tourId!.isNotEmpty;

  String? get overview => summary;
  List<String> get quickTips => tips;
  List<GuidanceFaq> get faqs => faqItems;
  int get estimatedReadMinutes => 3;

  String titleFor(String lang) {
    if (lang == 'en') {
      if (titleEn != null && titleEn!.isNotEmpty) return titleEn!;
      final match = RegExp(r'\(([^)]+)\)').firstMatch(title);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        return match.group(1)!.trim();
      }
      return title;
    }
    // amharic
    if (title.contains('(')) {
      final am = title.split('(').first.trim();
      if (am.isNotEmpty) return am;
    }
    return title;
  }

  String? summaryFor(String lang) {
    if (lang == 'en' && summaryEn != null && summaryEn!.isNotEmpty) {
      return summaryEn;
    }
    return summary;
  }

  String contentFor(String lang) {
    if (lang == 'en' && contentEn != null && contentEn!.isNotEmpty) {
      return contentEn!;
    }
    return content;
  }

  List<String> tipsFor(String lang) {
    if (lang == 'en' && tipsEn.isNotEmpty) {
      return tipsEn;
    }
    return tips;
  }

  factory GuidanceArticle.fromJson(Json j) {
    final rawSteps = asJsonList(j['steps']);
    final rawTips = ((j['tips'] ?? j['quick_tips']) as List? ?? const []).map((e) => '$e').toList();
    final rawTipsEn = ((j['tips_en']) as List? ?? const []).map((e) => '$e').toList();
    final rawFaqs = asJsonList(j['faq_items'] ?? j['faqs']);
    final sum = asStr(j['summary']) ?? asStr(j['overview']);

    return GuidanceArticle(
      id: asIntOr(j['id']),
      slug: asStr(j['slug']) ?? '',
      category: asStr(j['category']) ?? 'general',
      title: asStr(j['title']) ?? '',
      summary: sum,
      content: asStr(j['content']) ?? sum ?? '',
      targetRole: asStr(j['target_role']) ?? 'all',
      targetScreen: asStr(j['target_screen']),
      requiredPermission: asStr(j['required_permission']),
      steps: rawSteps.map(GuidanceStep.fromJson).toList(),
      tips: rawTips,
      faqItems: rawFaqs.map(GuidanceFaq.fromJson).toList(),
      tourId: asStr(j['tour_id']),
      icon: asStr(j['icon']),
      sortOrder: asIntOr(j['sort_order']),
      status: asStr(j['status']) ?? 'published',
      createdAt: j['created_at'] != null ? DateTime.tryParse('${j['created_at']}') : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse('${j['updated_at']}') : null,
      titleEn: asStr(j['title_en']),
      summaryEn: asStr(j['summary_en']),
      contentEn: asStr(j['content_en']),
      tipsEn: rawTipsEn,
    );
  }

  Json toJson() => {
        'id': id,
        'slug': slug,
        'category': category,
        'title': title,
        if (summary != null) 'summary': summary,
        if (summary != null) 'overview': summary,
        'content': content,
        'target_role': targetRole,
        if (targetScreen != null) 'target_screen': targetScreen,
        if (requiredPermission != null) 'required_permission': requiredPermission,
        'steps': steps.map((s) => s.toJson()).toList(),
        'tips': tips,
        'quick_tips': tips,
        'faq_items': faqItems.map((f) => f.toJson()).toList(),
        'faqs': faqItems.map((f) => f.toJson()).toList(),
        if (tourId != null) 'tour_id': tourId,
        if (icon != null) 'icon': icon,
        'sort_order': sortOrder,
        'status': status,
        if (titleEn != null) 'title_en': titleEn,
        if (summaryEn != null) 'summary_en': summaryEn,
        if (contentEn != null) 'content_en': contentEn,
        if (tipsEn.isNotEmpty) 'tips_en': tipsEn,
      };
}

class TourProgress {
  const TourProgress({
    required this.tourId,
    required this.completed,
    this.dismissed = false,
    this.completedAt,
  });

  final String tourId;
  final bool completed;
  final bool dismissed;
  final DateTime? completedAt;

  factory TourProgress.fromJson(Json j) => TourProgress(
        tourId: asStr(j['tour_id']) ?? '',
        completed: asBool(j['completed']),
        dismissed: asBool(j['dismissed']),
        completedAt: j['completed_at'] != null ? DateTime.tryParse('${j['completed_at']}') : null,
      );

  Json toJson() => {
        'tour_id': tourId,
        'completed': completed,
        'dismissed': dismissed,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      };
}
