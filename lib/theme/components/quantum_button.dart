import 'package:flutter/material.dart';
import '../colors/quantum_colors.dart';

enum QuantumButtonType { primary, secondary, outline, ghost }
enum QuantumButtonSize { small, medium, large }

class QuantumButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final QuantumButtonType type;
  final QuantumButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isActive;
  final double? width;

  const QuantumButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = QuantumButtonType.primary,
    this.size = QuantumButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isActive = false,
    this.width,
  }) : super(key: key);

  @override
  State<QuantumButton> createState() => _QuantumButtonState();
}

class _QuantumButtonState extends State<QuantumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final height = _getHeight();
    final padding = _getPadding();
    final textStyle = _getTextStyle(context);
    final backgroundColor = _getBackgroundColor();
    final foregroundColor = _getForegroundColor();
    final borderSide = _getBorderSide();
    final glowColor = _getGlowColor();

    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: height,
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (widget.type == QuantumButtonType.primary || widget.isActive)
                  ...QuantumColors.glowShadow(glowColor),
                ...QuantumColors.bevelShadow,
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.type == QuantumButtonType.primary
                      ? QuantumColors.primaryGradient
                      : null,
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderSide.color,
                    width: borderSide.width,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onPressed,
                    child: Padding(
                      padding: padding,
                      child: Center(
                        child: widget.isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    foregroundColor,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.icon != null) ...[
                                    Icon(
                                      widget.icon,
                                      color: foregroundColor,
                                      size: _getIconSize(),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    widget.text,
                                    style: textStyle.copyWith(
                                      color: foregroundColor,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getHeight() {
    switch (widget.size) {
      case QuantumButtonSize.small:
        return 36;
      case QuantumButtonSize.medium:
        return 48;
      case QuantumButtonSize.large:
        return 56;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case QuantumButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16);
      case QuantumButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24);
      case QuantumButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32);
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    switch (widget.size) {
      case QuantumButtonSize.small:
        return Theme.of(context).textTheme.labelMedium!;
      case QuantumButtonSize.medium:
        return Theme.of(context).textTheme.labelLarge!;
      case QuantumButtonSize.large:
        return Theme.of(context).textTheme.titleMedium!;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case QuantumButtonSize.small:
        return 16;
      case QuantumButtonSize.medium:
        return 20;
      case QuantumButtonSize.large:
        return 24;
    }
  }

  Color? _getBackgroundColor() {
    switch (widget.type) {
      case QuantumButtonType.primary:
        return null; // Uses gradient
      case QuantumButtonType.secondary:
        return QuantumColors.neonMagenta;
      case QuantumButtonType.outline:
      case QuantumButtonType.ghost:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    switch (widget.type) {
      case QuantumButtonType.primary:
      case QuantumButtonType.secondary:
        return QuantumColors.textOnAccent;
      case QuantumButtonType.outline:
        return QuantumColors.neonCyan;
      case QuantumButtonType.ghost:
        return QuantumColors.textSecondary;
    }
  }

  BorderSide _getBorderSide() {
    switch (widget.type) {
      case QuantumButtonType.primary:
      case QuantumButtonType.secondary:
        return const BorderSide(color: Colors.transparent, width: 0);
      case QuantumButtonType.outline:
        return BorderSide(
          color: QuantumColors.neonCyan.withOpacity(0.5),
          width: 2,
        );
      case QuantumButtonType.ghost:
        return const BorderSide(color: Colors.transparent, width: 0);
    }
  }

  Color _getGlowColor() {
    switch (widget.type) {
      case QuantumButtonType.primary:
        return QuantumColors.neonCyan;
      case QuantumButtonType.secondary:
        return QuantumColors.neonMagenta;
      case QuantumButtonType.outline:
        return QuantumColors.neonCyan;
      case QuantumButtonType.ghost:
        return QuantumColors.textSecondary;
    }
  }
}

class QuantumPillButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback? onPressed;
  final IconData? icon;

  const QuantumPillButton({
    Key? key,
    required this.text,
    this.isActive = false,
    this.onPressed,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? QuantumColors.neonCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? QuantumColors.neonCyan
                : QuantumColors.neonCyan.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isActive
              ? QuantumColors.glowShadow(QuantumColors.neonCyan)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? QuantumColors.textOnAccent
                    : QuantumColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: isActive
                        ? QuantumColors.textOnAccent
                        : QuantumColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}