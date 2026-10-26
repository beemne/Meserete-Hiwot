import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/json.dart';
import 'brand.dart';
import 'secure_screen.dart';

/// Member uuid from a scanned QR: accepts the share URL (https://host/u/UUID) or a bare uuid.
String? memberUuidFromQr(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})').firstMatch(raw.trim());
  return m?.group(1)?.toLowerCase();
}

/// Full-screen camera scanner; returns the first member uuid it reads.
Future<String?> scanMemberQr(BuildContext context) => Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _ScannerScreen()));

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.scanQr),
        actions: [IconButton(tooltip: l.flashlight, icon: const Icon(Icons.flashlight_on_rounded), onPressed: _ctrl.toggleTorch)],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final uuid = memberUuidFromQr(b.rawValue);
                if (uuid != null) {
                  _done = true;
                  Navigator.pop(context, uuid);
                  return;
                }
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.cameraUnavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              l.scanQrHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// The member card: photo, name, QR, classes and departments with role labels.
class MemberCard extends StatelessWidget {
  const MemberCard({super.key, required this.card, this.showQr = true});
  final Json card;
  final bool showQr;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final departments = asJsonList(card['departments']);
    final classes = asJsonList(card['classes']);
    final avatar = asStr(card['avatar_url']);
    final name = asStr(card['full_name']) ?? '—';
    // The QR identifies the member: no screenshots / recordings while the card is shown.
    return SecureScreen(
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: p.pill,
                  backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                  child: avatar == null ? Text(name.characters.first, style: context.serif(22)) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.serif(18)),
                      if (asStr(card['member_id']) != null) MemberIdBadge(asStr(card['member_id'])!),
                      if (asStr(card['phone']) != null) Text(asStr(card['phone'])!, style: context.sans(12, color: p.muted)),
                      if (asStr(card['role_name']) != null) Padding(padding: const EdgeInsets.only(top: 4), child: Pill(asStr(card['role_name'])!)),
                    ],
                  ),
                ),
              ],
            ),
            if (showQr && asStr(card['qr']) != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: QrImageView(data: asStr(card['qr'])!, size: 200, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                l.memberQrHint,
                textAlign: TextAlign.center,
                style: context.sans(11, color: p.subtle),
              ),
            ],
            if (classes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l.myClasses, style: context.sans(13, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final c in classes) Pill('${c['name']} · ${asStr(c['program']) == 'distance' ? l.programDistance : l.programRegular}', icon: Icons.school_rounded)],
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.myDepartments, style: context.sans(13, weight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            if (departments.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l.noDepartments, style: context.sans(12, color: p.muted)),
              )
            else
              for (final d in departments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(d['is_lead'] == true ? Icons.star_rounded : Icons.groups_rounded, color: AppColors.gold),
                  title: Text('${d['name']}'),
                  subtitle: Text(d['is_lead'] == true ? l.deptLeader : l.deptMember),
                ),
          ],
        ),
      ),
    );
  }
}
