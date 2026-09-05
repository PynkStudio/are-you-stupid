import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'ays_button.dart';

/// Placeholder ad unit. Same timing and same flow as a real one, so swapping
/// in a network SDK changes nothing about the UX.
class MockAdOverlay extends StatefulWidget {
  const MockAdOverlay({super.key, required this.seconds, required this.rewarded});

  final int seconds;
  final bool rewarded;

  @override
  State<MockAdOverlay> createState() => _MockAdOverlayState();
}

class _MockAdOverlayState extends State<MockAdOverlay> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left <= 0;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101018),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SPONSORED', style: Ays.mono(13)),
                    Text(
                      done ? 'READY' : '$_left',
                      style: Ays.mono(13, color: Ays.warning),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: Ays.radius,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Ays.purple, Ays.blue],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('YOUR AD HERE',
                              textAlign: TextAlign.center,
                              style: Ays.title(46)),
                          const SizedBox(height: 12),
                          Text(
                            widget.rewarded
                                ? 'WATCH TO CONTINUE'
                                : 'THIS SPACE PAYS THE BILLS',
                            textAlign: TextAlign.center,
                            style: Ays.label(16, color: Ays.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AysButton(
                  label: done
                      ? (widget.rewarded ? 'CLAIM' : 'CLOSE')
                      : 'PLEASE WAIT',
                  color: done ? Ays.ink : Ays.surfaceHigh,
                  textColor: done ? Ays.bg : Ays.inkDim,
                  onTap: () {
                    if (!done) return;
                    Navigator.of(context).pop(true);
                  },
                ),
                if (widget.rewarded) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('NO THANKS', style: Ays.mono(13)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
