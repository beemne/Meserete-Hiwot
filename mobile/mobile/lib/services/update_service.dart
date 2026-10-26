import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/json.dart';
import '../repositories/providers.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentCode,
    required this.currentName,
    this.available = false,
    this.force = false,
    this.latestName,
    this.latestCode,
    this.notes,
    this.pageUrl,
  });

  final int currentCode;
  final String currentName;
  final bool available;
  final bool force;
  final String? latestName;
  final int? latestCode;
  final String? notes;
  final String? pageUrl;
}

/// Checks the backend for a newer app version (on start and on resume).
/// A forced update blocks the app (router redirect) until the new version is installed
/// from the download page.
class UpdateController extends Notifier<UpdateInfo?> {
  @override
  UpdateInfo? build() => null;

  Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber) ?? 0;
      final j = await ref.read(accountRepositoryProvider).versionCheck(code);
      state = UpdateInfo(
        currentCode: code,
        currentName: info.version,
        available: asBool(j['update_available']),
        force: asBool(j['force_update']),
        latestName: asStr(j['latest_version_name']),
        latestCode: asInt(j['latest_version_code']),
        notes: asStr(j['release_notes']),
        pageUrl: asStr(j['download_page_url']),
      );
    } catch (e) {
      // Offline or server unreachable: never block the app on a failed check.
      debugPrint('version check failed: $e');
    }
    return state;
  }

  Future<void> openDownloadPage() async {
    final url = state?.pageUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateInfo?>(UpdateController.new);
