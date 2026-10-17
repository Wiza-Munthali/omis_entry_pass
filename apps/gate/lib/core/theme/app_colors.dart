import 'package:flutter/painting.dart';

/// Design tokens — the only colours allowed in the gate app.
/// Source of truth: docs/SPEC.md → "Design system".
/// test/design_tokens_test.dart fails if these drift from the spec or if a
/// colour literal appears anywhere else under lib/.
abstract final class AppColors {
  // Brand
  static const brand = Color(0xFF34C5A0);
  static const brandStrong = Color(0xFF1F9E7E);
  static const brandSoft = Color(0xFFDDF5EF);

  // Neutrals
  static const ink = Color(0xFF111111);
  static const ink2 = Color(0xFF1C1C1E);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF6B6B6B);
  static const bg = Color(0xFFEEEEEA);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF5F5F2);
  static const border = Color(0xFFE4E4E0);

  // Status (foreground on soft background)
  static const success = Color(0xFF1F9E7E);
  static const successSoft = Color(0xFFDDF5EF);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFDF1DC);
  static const danger = Color(0xFFC0392B);
  static const dangerSoft = Color(0xFFFBE3E0);
  static const info = Color(0xFF2F6FB0);
  static const infoSoft = Color(0xFFE1ECF8);

  /// Token name (as written in the spec) → colour. Used by the token test.
  static const bySpecName = <String, Color>{
    'brand': brand,
    'brand-strong': brandStrong,
    'brand-soft': brandSoft,
    'ink': ink,
    'ink-2': ink2,
    'text': text,
    'text-muted': textMuted,
    'bg': bg,
    'surface': surface,
    'surface-2': surface2,
    'border': border,
    'success': success,
    'success-soft': successSoft,
    'warning': warning,
    'warning-soft': warningSoft,
    'danger': danger,
    'danger-soft': dangerSoft,
    'info': info,
    'info-soft': infoSoft,
  };
}
