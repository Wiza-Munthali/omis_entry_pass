import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'scan_result_sheet.dart';
import 'scan_session.dart';

/// G4 Scanner: full-screen camera, teal-cornered viewfinder, torch and close.
/// Each code goes to record_scan; the result sheet (G5/G6) slides up over the camera.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  ScanSession? _session;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ScanSession _sessionFor(String gateId) => _session ??= ScanSession(
    repository: ref.read(gateRepositoryProvider),
    gateId: gateId,
  );

  Future<void> _onDetect(BarcodeCapture capture) async {
    final gate = ref.read(selectedGateProvider).value;
    if (gate == null || capture.barcodes.isEmpty) return;
    final session = _sessionFor(gate.id);
    final event = await session.handle(capture.barcodes.first.rawValue);
    if (event == null || !mounted) return;

    switch (event) {
      case ScanSucceeded(:final result):
        unawaited(
          OutcomeView.of(result).allowed
              ? HapticFeedback.mediumImpact()
              : HapticFeedback.heavyImpact(),
        );
        if (!mounted) return;
        final canApprove = ref.read(profileProvider).value?.canApprove ?? false;
        final reviewId =
            canApprove &&
                result.outcome == ScanOutcome.pending &&
                result.passId != null
            ? result.passId
            : null;
        var review = false;
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (sheetContext) => ScanResultSheet(
            result: result,
            onReview: reviewId == null
                ? null
                : () {
                    review = true;
                    Navigator.of(sheetContext).pop();
                  },
          ),
        );
        if (review && mounted) await context.push('/approvals/$reviewId');
      case ScanFailed(:final message):
        unawaited(HapticFeedback.heavyImpact());
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          builder: (_) => ScanErrorSheet(message: message),
        );
    }
    session.done();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          const IgnorePointer(
            child: CustomPaint(painter: _ViewfinderPainter()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleIconButton(
                        icon: Icons.close,
                        tooltip: 'Close scanner',
                        background: AppColors.ink2,
                        foreground: AppColors.surface,
                        onPressed: () => context.pop(),
                      ),
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (_, state, _) => CircleIconButton(
                          icon: state.torchState == TorchState.on
                              ? Icons.flashlight_off
                              : Icons.flashlight_on,
                          tooltip: state.torchState == TorchState.on
                              ? 'Torch off'
                              : 'Torch on',
                          background: state.torchState == TorchState.on
                              ? AppColors.brand
                              : AppColors.ink2,
                          foreground: state.torchState == TorchState.on
                              ? AppColors.ink
                              : AppColors.surface,
                          onPressed: state.torchState == TorchState.unavailable
                              ? null
                              : _controller.toggleTorch,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Point at the QR code',
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4 * 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dims everything outside a rounded square and draws teal corners around it.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * 0.7;
    final rect = Rect.fromCenter(
      center: size.center(Offset(0, -size.height * 0.05)),
      width: side,
      height: side,
    );
    final hole = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(AppRadii.card),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = AppColors.ink.withValues(alpha: 0.55),
    );

    final corner = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const len = 40.0;
    const r = AppRadii.card;
    void cornerAt(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x, y + dy * len)
        ..lineTo(x, y + dy * r)
        ..quadraticBezierTo(x, y, x + dx * r, y)
        ..lineTo(x + dx * len, y);
      canvas.drawPath(path, corner);
    }

    cornerAt(rect.left, rect.top, 1, 1);
    cornerAt(rect.right, rect.top, -1, 1);
    cornerAt(rect.left, rect.bottom, 1, -1);
    cornerAt(rect.right, rect.bottom, -1, -1);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) => false;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 56,
                color: AppColors.brand,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                denied ? 'Camera access is off' : 'The camera could not start',
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                denied
                    ? 'Allow camera access for OMIS Entry in the phone\'s Settings, then open the scanner again.'
                    : 'Close the scanner and try again. If it keeps failing, restart the phone.',
                style: const TextStyle(color: AppColors.surface, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
