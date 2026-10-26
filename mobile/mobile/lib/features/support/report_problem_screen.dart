import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/error_reporting_service.dart';

/// Screen allowing users and administrators to report problems with descriptions,
/// reproduction steps, optional screenshot attachments, and diagnostic telemetry.
class ReportProblemScreen extends ConsumerStatefulWidget {
  const ReportProblemScreen({
    super.key,
    this.initialModule,
    this.initialScreen,
    this.initialErrorMessage,
  });

  final String? initialModule;
  final String? initialScreen;
  final String? initialErrorMessage;

  @override
  ConsumerState<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _moduleController;
  late final TextEditingController _screenController;
  late final TextEditingController _descController;
  late final TextEditingController _stepsController;

  String? _screenshotPath;
  bool _includeDiagnostics = true;
  bool _isSubmitting = false;
  String? _submittedReportId;

  @override
  void initState() {
    super.initState();
    _moduleController = TextEditingController(text: widget.initialModule ?? 'general');
    _screenController = TextEditingController(text: widget.initialScreen ?? '');
    _descController = TextEditingController(
      text: widget.initialErrorMessage != null ? 'Error observed: ${widget.initialErrorMessage}' : '',
    );
    _stepsController = TextEditingController();
  }

  @override
  void dispose() {
    _moduleController.dispose();
    _screenController.dispose();
    _descController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _screenshotPath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        final l = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.isEn ? 'Failed to select image: $e' : 'ምስሉን መምረጥ አልተቻለም፦ $e')),
        );
      }
    }
  }

  void _removeScreenshot() {
    setState(() {
      _screenshotPath = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final module = _moduleController.text.trim();
    final screen = _screenController.text.trim();
    final desc = _descController.text.trim();
    final steps = _stepsController.text.trim();

    try {
      final reportId = await ref.read(errorReportingServiceProvider).submitProblemReport(
        module: module.isNotEmpty ? module : 'general',
        screen: screen.isNotEmpty ? screen : null,
        userDescription: desc,
        stepsToReproduce: steps.isNotEmpty ? steps : null,
        screenshotPath: _screenshotPath,
        includeDiagnostics: _includeDiagnostics,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittedReportId = reportId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        final l = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.errorGeneric}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;

    if (_submittedReportId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEn ? 'Report Submitted' : 'ሪፖርቱ ገብቷል'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
                const SizedBox(height: 16),
                Text(
                  isEn ? 'Thank You for Reporting' : 'ስለ ሪፖርትዎ እናመሰግናለን',
                  style: context.serif(20, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  isEn
                      ? 'Our technical administrators have received your report and are investigating.'
                      : 'የስርዓቱ አስተዳዳሪዎች ሪፖርትዎን ተቀብለው ችግሩን እየመረመሩት ነው።',
                  textAlign: TextAlign.center,
                  style: context.sans(14, color: context.palette.muted),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.palette.fill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isEn ? "Reference ID" : "የሪፖርት መለያ"}: ',
                        style: context.sans(13, color: context.palette.muted),
                      ),
                      SelectableText(
                        _submittedReportId!,
                        style: context.mono(15, weight: FontWeight.bold, color: AppColors.maroon),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: isEn ? 'Copy ID' : 'መለያውን ገልብጥ',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _submittedReportId!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEn ? 'Report ID copied' : 'የሪፖርት መለያው ተገልብጧል')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: Text(isEn ? 'Done' : 'ጨርስ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Report a Problem' : 'ችግር ሪፖርት ያድርጉ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEn
                    ? 'Found a defect, broken page, or unexpected error? Describe it below to notify administrators.'
                    : 'ስህተት፣ የማይከፈት ገጽ ወይም ያልተጠበቀ ችግር ካጋጠመዎት እባክዎ ከዚህ በታች ይግለጹት።',
                style: context.sans(14, color: context.palette.muted, height: 1.5),
              ),
              const SizedBox(height: 16),

              // Module (optional/auto-populated)
              TextFormField(
                controller: _moduleController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Module (e.g. Education, Sinksar, Files)' : 'ክፍል (ለምሳሌ፦ ትምህርት፣ ስንክሳር፣ ፋይሎች)',
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Screen (optional/auto-populated)
              TextFormField(
                controller: _screenController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Screen / Page Name' : 'የገጹ / ማያ ገጹ ስም',
                  prefixIcon: const Icon(Icons.layers_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: isEn ? 'Problem Description *' : 'የችግሩ ዝርዝር መግለጫ *',
                  hintText: isEn ? 'What happened? What did you expect to see?' : 'ምን አጋጠመ? ምን ማየት ጠብቀው ነበር?',
                  alignLabelWithHint: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return isEn ? 'Please describe the problem in at least 5 characters' : 'እባክዎ ችግሩን ቢያንስ በ5 ፊደላት ይግለጹ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Steps to reproduce
              TextFormField(
                controller: _stepsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isEn ? 'Steps to Reproduce (Optional)' : 'ችግሩን ለመድገም የሚወሰዱ እርምጃዎች (አማራጭ)',
                  hintText: isEn ? '1. Tap button\n2. Open tab\n3. Error appears' : '1. አዝራሩን መጫን\n2. ገጹን መክፈት\n3. ስህተቱ መታየት',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Screenshot upload & preview section
              Text(
                isEn ? 'Attach Screenshot (Optional)' : 'የስክሪን ቅጂ ያያይዙ (አማራጭ)',
                style: context.sans(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              if (_screenshotPath == null) ...[
                OutlinedButton.icon(
                  onPressed: _pickScreenshot,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(isEn ? 'Select Screenshot from Gallery' : 'የስክሪን ቅጂ ከማዕከለ-ስዕላት ይምረጡ'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.palette.fill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.divider),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_screenshotPath!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _screenshotPath!.split(RegExp(r'[/\\]')).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(12, color: context.palette.muted),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _removeScreenshot,
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            label: Text(isEn ? 'Remove' : 'አስወግድ', style: const TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              // Privacy notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.goldDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.goldDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Privacy Notice: Screenshots may contain private information. Please review the image before submitting.'
                            : 'የግላዊነት ማሳሰቢያ፦ የስክሪን ቅጂ የግል መረጃ ሊይዝ ስለሚችል ከማስገባትዎ በፊት ምስሉን ይገምግሙ።',
                        style: context.sans(11, color: context.palette.muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Include diagnostic telemetry checkbox
              CheckboxListTile(
                value: _includeDiagnostics,
                onChanged: (val) => setState(() => _includeDiagnostics = val ?? true),
                title: Text(
                  isEn ? 'Include safe diagnostic device data' : 'ደህንነቱ የተጠበቀ የመመርመሪያ መረጃዎችን አካትት',
                  style: context.sans(13),
                ),
                subtitle: Text(
                  isEn ? 'Includes app version and platform info (no passwords or personal tokens)' : 'የመተግበሪያውን ሥሪትና መድረክ ያካትታል (ምንም የሚስጥር ቃል ወይም ቶከን አይላክም)',
                  style: context.sans(11, color: context.palette.muted),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 20),

              // Submit button
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting
                      ? (isEn ? 'Submitting Report...' : 'ሪፖርቱን በመላክ ላይ...')
                      : (isEn ? 'Submit Problem Report' : 'ሪፖርቱን ላክ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
