import 'package:flutter/material.dart';
import '../colors/quantum_colors.dart';

class QuantumToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final double scale;

  const QuantumToggle({
    Key? key,
    required this.value,
    required this.onChanged,
    this.label,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  State<QuantumToggle> createState() => _QuantumToggleState();
}

class _QuantumToggleState extends State<QuantumToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(QuantumToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 12),
          ],
          Transform.scale(
            scale: widget.scale,
            child: Container(
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: QuantumColors.innerBevelShadow,
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          ColorTween(
                            begin: QuantumColors.surface,
                            end: QuantumColors.neonCyan.withOpacity(0.3),
                          ).evaluate(_animation)!,
                          ColorTween(
                            begin: QuantumColors.surfaceElevated,
                            end: QuantumColors.neonCyan.withOpacity(0.5),
                          ).evaluate(_animation)!,
                        ],
                      ),
                      border: Border.all(
                        color: ColorTween(
                          begin: QuantumColors.textTertiary.withOpacity(0.3),
                          end: QuantumColors.neonCyan,
                        ).evaluate(_animation)!,
                        width: 2,
                      ),
                      boxShadow: widget.value
                          ? QuantumColors.glowShadow(QuantumColors.neonCyan)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          left: widget.value ? 30 : 4,
                          top: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ColorTween(
                                begin: QuantumColors.textTertiary,
                                end: QuantumColors.neonCyan,
                              ).evaluate(_animation),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorTween(
                                    begin: Colors.transparent,
                                    end: QuantumColors.neonCyan.withOpacity(0.5),
                                  ).evaluate(_animation)!,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuantumSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String Function(double)? displayValue;
  final Color? activeColor;

  const QuantumSlider({
    Key? key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.displayValue,
    this.activeColor,
  }) : super(key: key);

  @override
  State<QuantumSlider> createState() => _QuantumSliderState();
}

class _QuantumSliderState extends State<QuantumSlider> {
  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? QuantumColors.neonCyan;
    final displayText = widget.displayValue?.call(widget.value) ?? 
                       widget.value.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label!,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activeColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    displayText,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            inactiveTrackColor: activeColor.withOpacity(0.2),
            thumbColor: activeColor,
            overlayColor: activeColor.withOpacity(0.2),
            thumbShape: _CustomThumbShape(color: activeColor, radius: 12.0),
            trackHeight: 8,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: widget.value,
            onChanged: widget.onChanged,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
          ),
        ),
      ],
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  final Color color;
  final double radius;

  const _CustomThumbShape({
    required this.color,
    this.radius = 12.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(radius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius + 4, glowPaint);

    // Main thumb with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = RadialGradient(
      colors: [
        color.withOpacity(0.8),
        color,
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(center, radius, paint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..blendMode = BlendMode.overlay;
    canvas.drawCircle(
      center.translate(-radius * 0.3, -radius * 0.3),
      radius * 0.3,
      highlightPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }
}

class QuantumSegmentedControl<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onValueChanged;
  final String? label;

  const QuantumSegmentedControl({
    Key? key,
    required this.value,
    required this.options,
    required this.onValueChanged,
    this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: QuantumColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: QuantumColors.innerBevelShadow,
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: options.entries.map((entry) {
              final isSelected = entry.key == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onValueChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? QuantumColors.neonCyan : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? QuantumColors.glowShadow(QuantumColors.neonCyan)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              color: isSelected
                                  ? QuantumColors.textOnAccent
                                  : QuantumColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}