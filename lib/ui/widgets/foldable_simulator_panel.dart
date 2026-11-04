import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/foldable.dart';
import '../theme.dart';

/// DEVELOPMENT ONLY — the virtual hinge ([[Foldable Simulator]]).
///
/// Only built when `kFoldableSimulatorEnabled` (debug build +
/// `--dart-define=AYS_FOLD_SIM=true`). Drives a [SimulatedHingeProvider]
/// and the [FoldableDeviceController] display/orientation setters — the same
/// normalized interface the iOS bridge feeds — so challenges can't tell it
/// from hardware. English-only on purpose: it's a dev tool, never shipped.
class FoldableSimulatorPanel extends StatefulWidget {
  const FoldableSimulatorPanel({
    super.key,
    required this.hinge,
    required this.device,
  });

  final SimulatedHingeProvider hinge;
  final FoldableDeviceController device;

  @override
  State<FoldableSimulatorPanel> createState() => _FoldableSimulatorPanelState();
}

class _FoldableSimulatorPanelState extends State<FoldableSimulatorPanel> {
  bool _open = true;
  StreamSubscription<FoldableEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.device.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openDevice() {
    widget.hinge.open();
    widget.device.setDisplay(DisplayConfiguration.expanded);
  }

  void _closeDevice() {
    widget.hinge.close();
    widget.device.setDisplay(DisplayConfiguration.compact);
  }

  void _toggleDisplay() {
    final now = widget.device.state.display;
    widget.device.setDisplay(
      now == DisplayConfiguration.compact
          ? DisplayConfiguration.expanded
          : DisplayConfiguration.compact,
    );
  }

  void _rotate() {
    final now = widget.device.state.orientation;
    widget.device.setOrientation(
      now == FoldOrientation.landscape
          ? FoldOrientation.portrait
          : FoldOrientation.landscape,
    );
  }

  void _reset() {
    widget.hinge.reset();
    widget.device.setDisplay(DisplayConfiguration.expanded);
    widget.device.setOrientation(FoldOrientation.portrait);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.device.state;
    final angle = widget.hinge.angle;
    final summary =
        '${widget.hinge.available ? '${angle.round()}°' : 'NO HINGE'} · '
        '${state.status.name} · ${state.display.name}';
    return Material(
      key: const ValueKey('fold-sim-panel'),
      color: Ays.surface.withValues(alpha: 0.94),
      borderRadius: Ays.radiusSmall,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const ValueKey('fold-sim-toggle'),
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Text('FOLD SIM', style: Ays.mono(11, color: Ays.warning)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary,
                      style: Ays.mono(11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                    color: Ays.inkDim,
                  ),
                ],
              ),
            ),
            if (_open) ...[
              Slider(
                key: const ValueKey('fold-sim-angle'),
                value: angle,
                max: 180,
                divisions: 36,
                label: '${angle.round()}°',
                onChanged: widget.hinge.setAngle,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _btn('OPEN', _openDevice),
                  _btn('CLOSE', _closeDevice),
                  _btn('DISPLAY', _toggleDisplay),
                  _btn('ROTATE', _rotate),
                  _btn('LOSE HINGE', widget.hinge.loseHinge),
                  _btn('RESET', _reset),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => OutlinedButton(
    key: ValueKey('fold-sim-$label'),
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      side: const BorderSide(color: Ays.inkDim),
    ),
    child: Text(label, style: Ays.mono(11)),
  );
}
