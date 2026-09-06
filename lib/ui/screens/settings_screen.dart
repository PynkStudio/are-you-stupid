import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/app_locale.dart';
import '../../i18n/strings.dart';
import '../../services/app_services.dart';
import '../../services/purchases/purchase_manager.dart';
import '../theme.dart';
import '../widgets/ays_button.dart';

/// Sentinel returned by the language dialog for "follow the system
/// language", distinct from `null` (dialog dismissed without a choice).
final Object _systemChoice = Object();

/// PynkStudio's own case-study page for the game. It ships in two languages
/// today, Italian and English; `_gameInfoUrlFor` picks the Italian page for
/// [AppLocale.it] and the English one for every other supported locale
/// (fr/es/pt/de included — there's no dedicated page for those yet, English
/// is the fallback). The privacy policy itself is English-only and shared by
/// both, since it's the same product regardless of UI language.
const _gameInfoUrlIt = 'https://pynkstudio.eu/it/lavori/are-you-stupid';
const _gameInfoUrlEn = '$_gameInfoUrlIt/en';
const _privacyPolicyUrl = '$_gameInfoUrlIt/privacy';
const _studioUrl = 'https://pynkstudio.eu';

String _gameInfoUrlFor(AppLocale locale) =>
    locale == AppLocale.it ? _gameInfoUrlIt : _gameInfoUrlEn;

Future<void> _openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Ays.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
            child: AnimatedBuilder(
              animation: services.settings,
              builder: (context, _) {
                final s = services.settings;
                final locale = s.locale;
                String t(String key, [Map<String, String>? args]) =>
                    Strings.t(locale, key, args);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('ui.settings.title'), style: Ays.title(48)),
                    const SizedBox(height: 28),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Toggle(
                              label: t('ui.settings.sound'),
                              value: s.soundEnabled,
                              onChanged: (v) {
                                s.setSound(v);
                                if (v) services.sound.button();
                              },
                            ),
                            _Toggle(
                              label: t('ui.settings.vibration'),
                              value: s.hapticsEnabled,
                              onChanged: (v) {
                                s.setHaptics(v);
                                if (v) services.haptics.tap();
                              },
                            ),
                            _Toggle(
                              label: t('ui.settings.savage_mode'),
                              caption: t('ui.settings.savage_caption'),
                              value: s.roastsEnabled,
                              onChanged: s.setRoasts,
                            ),
                            _LanguageRow(
                              label: t('ui.settings.language'),
                              currentName: s.localeIsSystemDefault
                                  ? t('ui.settings.language_system')
                                  : locale.nativeName,
                              onTap: () => _pickLanguage(context, services),
                            ),
                            _RemoveAdsSection(services: services, t: t),
                            _LinkRow(
                              label: t('ui.settings.about'),
                              onTap: () => _openUrl(_gameInfoUrlFor(locale)),
                            ),
                            _LinkRow(
                              label: t('ui.settings.privacy_policy'),
                              onTap: () => _openUrl(_privacyPolicyUrl),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AysButton(
                      label: t('ui.settings.reset_stats'),
                      height: 58,
                      fontSize: 17,
                      outlined: true,
                      onTap: () => _confirmReset(context, services, t),
                    ),
                    const SizedBox(height: 12),
                    AysButton(
                      label: t('ui.settings.back'),
                      height: 66,
                      fontSize: 24,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t('ui.settings.footer'),
                      textAlign: TextAlign.center,
                      style: Ays.mono(10),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: GestureDetector(
                        onTap: () => _openUrl(_studioUrl),
                        child: Text(
                          t('ui.settings.made_by'),
                          textAlign: TextAlign.center,
                          style: Ays.label(11,
                              color: Ays.inkDim, weight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, AppServices services) async {
    final locale = services.settings.locale;
    String t(String key) => Strings.t(locale, key);
    // A dismissed dialog (back button, tap outside) also resolves to `null`
    // from showDialog, so "follow the system" needs its own sentinel to stay
    // distinguishable from "nothing was chosen".
    final result = await showDialog<Object>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: Ays.surface,
        title: Text(t('ui.settings.language'), style: Ays.label(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: t('ui.settings.language_system'),
              selected: services.settings.localeIsSystemDefault,
              onTap: () => Navigator.of(context).pop(_systemChoice),
              isSystemOption: true,
            ),
            for (final l in AppLocale.values)
              _LanguageOption(
                label: l.nativeName,
                selected: !services.settings.localeIsSystemDefault &&
                    services.settings.locale == l,
                onTap: () => Navigator.of(context).pop(l),
              ),
          ],
        ),
      ),
    );
    if (result == null) return; // dismissed without choosing
    await services.settings.setLocale(
      identical(result, _systemChoice) ? null : result as AppLocale,
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AppServices services,
    String Function(String) t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Ays.surface,
        title: Text(t('ui.settings.reset_title'), style: Ays.label(20)),
        content: Text(
          t('ui.settings.reset_body'),
          style: Ays.label(14, color: Ays.inkDim, weight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ui.settings.keep'), style: Ays.label(14)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('ui.settings.reset'), style: Ays.label(14, color: Ays.red)),
          ),
        ],
      ),
    );
    if (ok ?? false) await services.scores.reset();
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  final String label;
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Ays.surface,
            borderRadius: Ays.radiusSmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Ays.label(20)),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        style: Ays.label(12,
                            color: Ays.inkDim, weight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Ays.bg,
                activeTrackColor: Ays.green,
                inactiveTrackColor: Ays.surfaceHigh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.currentName,
    required this.onTap,
  });

  final String label;
  final String currentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Ays.surface,
            borderRadius: Ays.radiusSmall,
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Ays.label(20))),
              Text(currentName, style: Ays.label(16, color: Ays.warning)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: Ays.inkDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row that opens an external link (browser) instead of toggling
/// or navigating in-app.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Ays.surface,
            borderRadius: Ays.radiusSmall,
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Ays.label(20))),
              Icon(Icons.open_in_new, color: Ays.inkDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "remove ads" IAP row + restore link. Owns its own listener on
/// `PurchaseManager` (separate from the settings `AnimatedBuilder` above) so
/// it can pop a one-shot [SnackBar] for restore/error feedback without the
/// whole screen reacting to it.
class _RemoveAdsSection extends StatefulWidget {
  const _RemoveAdsSection({required this.services, required this.t});

  final AppServices services;
  final String Function(String) t;

  @override
  State<_RemoveAdsSection> createState() => _RemoveAdsSectionState();
}

class _RemoveAdsSectionState extends State<_RemoveAdsSection> {
  @override
  void initState() {
    super.initState();
    widget.services.purchases.addListener(_onPurchasesChanged);
  }

  @override
  void dispose() {
    widget.services.purchases.removeListener(_onPurchasesChanged);
    super.dispose();
  }

  void _onPurchasesChanged() {
    final feedback = widget.services.purchases.feedback;
    if (feedback == null) return;
    widget.services.purchases.clearFeedback();
    if (!mounted) return;
    final t = widget.t;
    final message = switch (feedback) {
      PurchaseFeedback.purchased => t('ui.settings.remove_ads_owned'),
      PurchaseFeedback.restored => t('ui.settings.remove_ads_restored'),
      PurchaseFeedback.nothingToRestore =>
        t('ui.settings.remove_ads_not_found'),
      PurchaseFeedback.error => t('ui.settings.remove_ads_error'),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.services.purchases,
      builder: (context, _) {
        final purchases = widget.services.purchases;
        // Same rule as ads: no dead-end button when the store can't be
        // reached (or ships no implementation, e.g. desktop dev builds).
        if (!purchases.storeAvailable) return const SizedBox.shrink();
        final t = widget.t;

        if (purchases.isPurchased) {
          return _RemoveAdsRow(
            label: t('ui.settings.remove_ads_owned'),
            caption: t('ui.settings.remove_ads_owned_caption'),
            owned: true,
          );
        }

        final product = purchases.product;
        if (product == null) return const SizedBox.shrink();
        return Column(
          children: [
            _RemoveAdsRow(
              label: t('ui.settings.remove_ads'),
              caption: t('ui.settings.remove_ads_caption'),
              trailing: product.price,
              onTap: purchases.busy ? null : purchases.buyRemoveAds,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: GestureDetector(
                  onTap: purchases.busy ? null : purchases.restorePurchases,
                  child: Text(
                    t('ui.settings.restore_purchase'),
                    style: Ays.label(13, color: Ays.inkDim,
                        weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RemoveAdsRow extends StatelessWidget {
  const _RemoveAdsRow({
    required this.label,
    required this.caption,
    this.trailing,
    this.owned = false,
    this.onTap,
  });

  final String label;
  final String caption;
  final String? trailing;
  final bool owned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Ays.surface,
            borderRadius: Ays.radiusSmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Ays.label(20)),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: Ays.label(12,
                          color: Ays.inkDim, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (owned)
                Icon(Icons.check_circle, color: Ays.green)
              else if (trailing != null) ...[
                Text(trailing!, style: Ays.label(16, color: Ays.warning)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: Ays.inkDim),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSystemOption = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isSystemOption;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Ays.label(
                  16,
                  color: selected ? Ays.warning : Ays.ink,
                  weight: isSystemOption ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: Ays.warning, size: 18),
          ],
        ),
      ),
    );
  }
}
