/// Shared chrome for the multiplayer controller screens — background,
/// avatar, and the one "leave" exit path every screen funnels through.
///
/// Deliberately small: the widget layer stays thin per [[Multiplayer Client
/// (Mobile)]] and reuses the single-player visual language, no new theme.
library;

import 'package:flutter/material.dart';

import '../../../core/challenge.dart';
import '../../../i18n/app_locale.dart';
import '../../../i18n/strings.dart';
import '../../../multiplayer/engine/party_session.dart';
import '../../theme.dart';
import '../../widgets/ays_button.dart';

/// Full-screen dark gradient + safe area, matching every other screen.
class MpBackground extends StatelessWidget {
  const MpBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: Ays.pageGradient),
        child: SafeArea(child: Padding(padding: padding, child: child)),
      );
}

const _kAvatarColors = [
  GameColor.red,
  GameColor.blue,
  GameColor.green,
  GameColor.purple,
  GameColor.orange,
  GameColor.pink,
  GameColor.yellow,
];

/// Colored-circle-and-initial avatar, optional emoji — no assets
/// ([[Multiplayer Product]] "Avatars"). The color is stable per player id/name
/// so the same seat keeps its color across roster refreshes.
class MpAvatar extends StatelessWidget {
  const MpAvatar({
    super.key,
    required this.seed,
    required this.name,
    this.emoji = '',
    this.size = 40,
  });

  /// Stable key for color assignment (playerId, or name if that's all you have).
  final String seed;
  final String name;
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _kAvatarColors[seed.hashCode.abs() % _kAvatarColors.length];
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Ays.of(color), shape: BoxShape.circle),
      child: Text(
        emoji.isNotEmpty ? emoji : initial,
        style: Ays.label(size * 0.44, color: Ays.inkOn(color)),
      ),
    );
  }
}

/// The one themed text input used across the join flow (name, room code) —
/// no Material defaults, matches [AysButton]'s flat/dark language.
class MpTextField extends StatelessWidget {
  const MpTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Ays.surface,
        borderRadius: Ays.radius,
        border: Border.all(color: Ays.surfaceHigh, width: 2),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textAlign: textAlign,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        onSubmitted: onSubmitted,
        style: Ays.label(24, weight: FontWeight.w900),
        cursorColor: Ays.ink,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle: Ays.label(24, color: Ays.inkDim, weight: FontWeight.w900),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
    );
  }
}

/// The multiplayer permissions primer: explains Local Network (required) and
/// Camera (optional, QR only) *before* the OS asks. Resolves true on
/// CONTINUE, false on NOT NOW ([[Multiplayer Client (Mobile)]]
/// "Permissions").
Future<bool> showMpPermissionsPrimer(BuildContext context, AppLocale locale) async {
  String t(String key) => Strings.t(locale, key);
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (context) => Dialog(
      backgroundColor: Ays.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: Ays.radius),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('ui.mp.primer.title'), style: Ays.title(30), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              t('ui.mp.primer.body'),
              textAlign: TextAlign.center,
              style: Ays.label(14, color: Ays.inkDim),
            ),
            const SizedBox(height: 20),
            _PrimerItem(
              icon: Icons.wifi_rounded,
              title: t('ui.mp.primer.network_title'),
              body: t('ui.mp.primer.network_body'),
            ),
            const SizedBox(height: 14),
            _PrimerItem(
              icon: Icons.qr_code_scanner_rounded,
              title: t('ui.mp.primer.camera_title'),
              body: t('ui.mp.primer.camera_body'),
            ),
            const SizedBox(height: 20),
            Text(
              t('ui.mp.primer.footer'),
              textAlign: TextAlign.center,
              style: Ays.label(13, color: Ays.warning),
            ),
            const SizedBox(height: 20),
            AysButton(
              label: t('ui.mp.primer.continue'),
              height: 64,
              fontSize: 24,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            AysButton(
              label: t('ui.mp.primer.not_now'),
              height: 52,
              fontSize: 16,
              outlined: true,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return accepted ?? false;
}

class _PrimerItem extends StatelessWidget {
  const _PrimerItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Ays.ink, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ays.label(16, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(body, style: Ays.label(13, color: Ays.inkDim)),
              ],
            ),
          ),
        ],
      );
}

/// A denied-permission notice with one fix-it action (OPEN SETTINGS).
class MpPermissionNotice extends StatelessWidget {
  const MpPermissionNotice({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Ays.surface,
          borderRadius: Ays.radiusSmall,
          border: Border.all(color: Ays.warning, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, textAlign: TextAlign.center, style: Ays.label(14)),
            const SizedBox(height: 12),
            AysButton(label: actionLabel, height: 52, fontSize: 17, onTap: onAction),
          ],
        ),
      );
}

/// Leaves the room (best-effort) and disposes [session], then pops every
/// multiplayer screen back to the app's home screen. Every "back"/"leave"
/// exit point in the flow funnels through here so a live socket never gets
/// left dangling underneath another route.
Future<void> leaveAndExit(BuildContext context, PartySession session) async {
  try {
    session.leaveRoom();
  } catch (_) {
    // Best-effort: the transport may already be closed (host gone, etc).
  }
  await session.dispose();
  if (context.mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
