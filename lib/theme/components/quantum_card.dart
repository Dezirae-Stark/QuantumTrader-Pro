import 'package:flutter/material.dart';
import '../colors/quantum_colors.dart';

class QuantumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final bool isActive;
  final bool hasGlow;
  final Color? glowColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const QuantumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.borderRadius = 12.0,
    this.isActive = false,
    this.hasGlow = false,
    this.glowColor,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ??
        (isActive ? QuantumColors.neonCyan : QuantumColors.glowCyan);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            ...QuantumColors.bevelShadow,
            if (hasGlow || isActive) ...QuantumColors.glowShadow(effectiveGlowColor),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient ?? QuantumColors.cardGradient,
              color: gradient == null ? (color ?? QuantumColors.surface) : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isActive
                    ? QuantumColors.neonCyan.withOpacity(0.5)
                    : QuantumColors.neonCyan.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class QuantumInfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isActive;

  const QuantumInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return QuantumCard(
      isActive: isActive,
      onTap: onTap,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? QuantumColors.neonCyan).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? QuantumColors.neonCyan,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}