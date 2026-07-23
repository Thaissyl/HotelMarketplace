import 'package:flutter/material.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../shared/widgets/srs_screen.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrsFieldLabel(label),
        Container(
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xs),
            border: Border.all(color: outlineColor),
          ),
          child: Row(
            children: [
              _StepperAction(
                tooltip: 'Decrease $label',
                icon: Icons.remove,
                enabled: value > minimum,
                onPressed: () => onChanged(value - 1),
              ),
              VerticalDivider(width: 1, thickness: 1, color: outlineColor),
              Expanded(
                child: Semantics(
                  label: '$label: $value',
                  liveRegion: true,
                  child: Text(
                    value.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: outlineColor),
              _StepperAction(
                tooltip: 'Increase $label',
                icon: Icons.add,
                enabled: value < maximum,
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperAction extends StatelessWidget {
  const _StepperAction({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: double.infinity,
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          disabledForegroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        icon: Icon(
          icon,
          size: 30,
          semanticLabel: tooltip,
        ),
      ),
    );
  }
}
