import 'package:flutter/material.dart';

import '../data/models.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'time.dart';

/// Initials in a tinted circle: teal for staff, blue for visitors.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.isStaff = true,
    this.size = 56,
    this.danger = false,
  });

  final String name;
  final bool isStaff;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = danger
        ? (AppColors.dangerSoft, AppColors.danger)
        : isStaff
        ? (AppColors.brandSoft, AppColors.brandStrong)
        : (AppColors.infoSoft, AppColors.info);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// "Staff" / "Visitor" chip with a person icon.
class PassTypeChip extends StatelessWidget {
  const PassTypeChip({super.key, required this.type, this.danger = false});

  final PassType? type;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isStaff = type == PassType.staff;
    final label = switch (type) {
      PassType.staff => 'Staff',
      PassType.day || PassType.week => 'Visitor',
      null => 'Pass',
    };
    final (bg, fg) = danger
        ? (AppColors.dangerSoft, AppColors.danger)
        : isStaff
        ? (AppColors.brandSoft, AppColors.brandStrong)
        : (AppColors.warningSoft, AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 16, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 48 px round icon button on surface-2 (back, menu, torch…).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background = AppColors.surface2,
    this.foreground = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: foreground),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    );
  }
}

/// Teal highlight stat card: big number, label, icon.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s2),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: AppColors.brandStrong),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandStrong,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon + text pair used in cards ("BT 4521", "In 08:42").
class IconText extends StatelessWidget {
  const IconText({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
