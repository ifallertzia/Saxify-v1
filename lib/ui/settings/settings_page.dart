import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/branding.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/format.dart';
import '../widgets/neon.dart';
import '../widgets/saxify_logo.dart';
import '../downloads/music_downloads_page.dart';
import '../player/equalizer_page.dart';
import 'background_guide_sheet.dart';
import 'backup_sheet.dart';
import 'diagnostics_page.dart';
import 'playlist_sync_sheet.dart';
import 'update_dialog.dart';

/// Settings — the same panels the web app shows.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsService settings = context.watch<SettingsService>();
    final LibraryService library = context.watch<LibraryService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            title: Text('Settings',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            backgroundColor: SaxifyColors.background,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                // ------------------------------------------------ Account
                const _PanelHeader(
                  title: 'Account & Profile',
                  subtitle: 'Your identity and library portability',
                ),
                _SettingTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Display name',
                  subtitle: 'Shown across your dashboard',
                  trailing: Text(
                    settings.displayName,
                    style: const TextStyle(
                        fontSize: 13, color: SaxifyColors.textSecondary),
                  ),
                  onTap: () => _editText(
                    context,
                    title: 'Display name',
                    initial: settings.displayName,
                    onSave: settings.setDisplayName,
                  ),
                ),
                _SettingTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email',
                  subtitle: 'For sync and backup reminders',
                  trailing: Text(
                    settings.email,
                    style: const TextStyle(
                        fontSize: 13, color: SaxifyColors.textSecondary),
                  ),
                  onTap: () => _editText(
                    context,
                    title: 'Email',
                    initial: settings.email,
                    onSave: settings.setEmail,
                  ),
                ),
                _SettingTile(
                  icon: Icons.upload_file_rounded,
                  title: 'Backup library',
                  subtitle: 'Copy JSON, or paste a backup to merge or replace',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: SaxifyColors.textFaint),
                  onTap: () => showBackupSheet(context, library),
                ),
                _SettingTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Generate all playlist codes',
                  subtitle: 'Copies a cloud code to the clipboard',
                  onTap: () => shareAllPlaylistCodes(context),
                ),
                _SettingTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Import playlist code',
                  subtitle: 'Paste a code to restore playlists',
                  onTap: () => showImportCodeSheet(context),
                ),
                _SwitchTile(
                  icon: Icons.sync_rounded,
                  title: 'Auto-sync playlists',
                  subtitle: 'Saves a fresh cloud code after playlist changes',
                  value: settings.autoPlaylistSync,
                  onChanged: settings.setAutoPlaylistSync,
                ),
                _SettingTile(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Equalizer',
                  subtitle: 'Uses the current player session',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const EqualizerPage()),
                  ),
                ),
                _SettingTile(
                  icon: Icons.download_outlined,
                  title: 'Music downloads',
                  subtitle: 'Files in Download/Saxify, with delete',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MusicDownloadsPage()),
                  ),
                ),
                _SettingTile(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Downloader diagnostics',
                  subtitle: 'Backend health, version, boot log',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiagnosticsPage(
                        safeMode: context.read<bool>(),
                      ),
                    ),
                  ),
                ),

                // ------------------------------------------------ Appearance
                const _PanelHeader(
                  title: 'Appearance & Theme',
                  subtitle: 'Make Saxify unmistakably yours',
                ),
                const _ThemePanel(),

                // ------------------------------------------------ Playback
                const _PanelHeader(
                  title: 'Playback & Audio Engine',
                  subtitle: 'Streaming quality, gapless handoff and auto-next',
                ),
                _ChoiceTile(
                  icon: Icons.wifi_rounded,
                  title: 'Streaming quality · Wi-Fi',
                  subtitle: 'Quality badge shown in the player',
                  choices: const <String>['low', 'medium', 'high'],
                  value: settings.qualityWifi,
                  onChanged: settings.setQualityWifi,
                ),
                _ChoiceTile(
                  icon: Icons.network_cell_rounded,
                  title: 'Streaming quality · Mobile data',
                  subtitle: 'Save bandwidth on the go',
                  choices: const <String>['low', 'medium', 'high'],
                  value: settings.qualityMobile,
                  onChanged: settings.setQualityMobile,
                ),
                _SwitchTile(
                  icon: Icons.bolt_rounded,
                  title: 'Gapless playback',
                  subtitle: 'Preloads the next track for seamless transitions',
                  value: settings.gapless,
                  onChanged: settings.setGapless,
                ),
                _SwitchTile(
                  icon: Icons.autorenew_rounded,
                  title: 'Autoplay',
                  subtitle:
                      'Keep similar music flowing when your queue ends — playback never stops',
                  value: settings.autoplay,
                  onChanged: settings.setAutoplay,
                ),
                _SwitchTile(
                  icon: Icons.history_rounded,
                  title: 'Remember playback position',
                  subtitle: 'Resume exactly where you left off',
                  value: settings.rememberPosition,
                  onChanged: settings.setRememberPosition,
                ),
                _ChoiceTile(
                  icon: Icons.speed_rounded,
                  title: 'Playback speed',
                  subtitle: 'Applied instantly to the current track',
                  choices: const <String>['0.75x', '1x', '1.25x', '1.5x'],
                  value: '${settings.playbackSpeed}x',
                  onChanged: (String v) => context
                      .read<PlaybackService>()
                      .setSpeed(double.parse(v.replaceAll('x', ''))),
                ),

                // ------------------------------------------------ System
                const _PanelHeader(
                  title: 'System & Device Controls',
                  subtitle: 'How Saxify talks to your phone',
                ),
                _SettingTile(
                  icon: Icons.headphones_battery_rounded,
                  title: 'Instructions to play in background',
                  subtitle: 'Keep the music going with the screen off',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: SaxifyColors.textFaint),
                  onTap: () => showBackgroundGuideSheet(context),
                ),
                _SettingTile(
                  icon: Icons.bedtime_rounded,
                  title: 'Sleep timer',
                  subtitle: 'Pause playback automatically',
                  trailing: Text(
                    context.watch<PlaybackService>().sleepRemaining == null
                        ? 'Off'
                        : Fmt.clock(context.read<PlaybackService>().sleepRemaining!),
                    style: const TextStyle(
                        fontSize: 13, color: SaxifyColors.textSecondary),
                  ),
                  onTap: () => _sleepSheet(context),
                ),

                // ------------------------------------------------ Privacy
                const _PanelHeader(
                  title: 'Privacy & Storage',
                  subtitle: 'Control what Saxify remembers',
                ),
                _SettingTile(
                  icon: Icons.search_off_rounded,
                  title: 'Clear search history',
                  subtitle: 'Removes your recent search terms',
                  onTap: () async {
                    await library.clearSearchHistory();
                    if (context.mounted) _toast(context, 'Search history cleared');
                  },
                ),
                _SettingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear listening history',
                  subtitle: 'Deletes recently played from this device',
                  onTap: () async {
                    await library.clearHistory();
                    await settings.forgetPositions();
                    if (context.mounted) _toast(context, 'Listening history cleared');
                  },
                ),

                // ------------------------------------------------ About
                const _PanelHeader(
                  title: 'About & Support',
                  subtitle: 'Version info, legal and help',
                ),
                _SettingTile(
                  icon: Icons.system_update_rounded,
                  title: 'Check for updates',
                  subtitle: 'Silent in-app updates from GitHub Releases',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: SaxifyColors.textFaint),
                  onTap: () => checkAndPromptUpdate(context, silent: false),
                ),
                const _AboutCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final TextEditingController controller = TextEditingController(text: initial);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: title),
          onSubmitted: (String v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) await onSave(value.trim());
  }

  void _sleepSheet(BuildContext context) {
    final PlaybackService playback = context.read<PlaybackService>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SaxifyColors.surface,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 14),
            for (final int m in <int>[15, 30, 45, 60, 90])
              ListTile(
                title: Text('$m minutes'),
                onTap: () {
                  playback.startSleepTimer(Duration(minutes: m));
                  Navigator.of(sheetContext).pop();
                },
              ),
            ListTile(
              title: const Text('Turn off',
                  style: TextStyle(color: SaxifyColors.danger)),
              onTap: () {
                playback.cancelSleepTimer();
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// --------------------------------------------------------------------- theme
class _ThemePanel extends StatefulWidget {
  const _ThemePanel();

  @override
  State<_ThemePanel> createState() => _ThemePanelState();
}

class _ThemePanelState extends State<_ThemePanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Live "next switch in Ns" countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();
    final SaxifyAccent accent = context.accent;

    return NeonCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Accent colour',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text(
                      'Paints the neon across the whole app',
                      style: TextStyle(
                          fontSize: 12, color: SaxifyColors.textMuted),
                    ),
                  ],
                ),
              ),
              SaxifyLogo(size: 40, accent: accent),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final SaxifyAccent option in SaxifyAccents.all)
                _AccentSwatch(
                  accent: option,
                  selected: option.id == accent.id,
                  onTap: () => theme.pin(option.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: theme.autoRotate,
            onChanged: theme.setAutoRotate,
            title: const Text('Auto-rotate theme',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              theme.autoRotate
                  ? 'Switching every ${theme.rotateInterval.inMinutes > 0 ? '${theme.rotateInterval.inMinutes} min' : '${theme.rotateInterval.inSeconds}s'} · next in ${theme.secondsUntilNextSwitch()}s'
                  : 'Pick a colour above and it stays',
              style:
                  const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
            ),
          ),
          if (theme.autoRotate)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final Duration d in <Duration>[
                    const Duration(minutes: 1),
                    const Duration(minutes: 2),
                    const Duration(seconds: 150),
                    const Duration(minutes: 3),
                    const Duration(minutes: 5),
                  ])
                    ChoiceChip(
                      label: Text(d.inSeconds == 150
                          ? '2.5 min'
                          : '${d.inMinutes} min'),
                      selected: d.inSeconds == theme.rotateInterval.inSeconds,
                      onSelected: (_) => theme.setRotateInterval(d),
                      labelStyle: const TextStyle(fontSize: 11.5),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final SaxifyAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: accent.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.primary : SaxifyColors.border,
              width: selected ? 1.6 : 1,
            ),
            color: selected
                ? accent.primary.withValues(alpha: 0.10)
                : SaxifyColors.surfaceAlt,
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: accent.gradient,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.primary.withValues(alpha: selected ? 0.6 : 0.25),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 15, color: Colors.black)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                accent.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent.primary : SaxifyColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- about
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return NeonCard(
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SaxifyLogo(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GradientText(SaxifyBranding.appName,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Text('Stream beyond limits',
                        style: TextStyle(
                            fontSize: 11.5, color: SaxifyColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Saxify is a clean and simple music experience built for people who '
            'want to discover and listen to music without unnecessary '
            'distractions. Play ad-free music with a focused and minimal '
            'listening experience.',
            style: TextStyle(fontSize: 12.5, height: 1.55, color: SaxifyColors.textSecondary),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FeatureChip('Search songs easily'),
              _FeatureChip('Discover artists'),
              _FeatureChip('Background playback'),
              _FeatureChip('Favourites'),
              _FeatureChip('Playlists'),
              _FeatureChip('Listening history'),
              _FeatureChip('Auto-next'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('App version',
                        style: TextStyle(
                            fontSize: 12.5, color: SaxifyColors.textSecondary)),
                    SizedBox(height: 2),
                    Text('Saxify · ${SaxifyBranding.versionLabel}',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'Saxify',
                  applicationVersion: SaxifyBranding.versionLabel,
                  applicationIcon: const SaxifyLogo(size: 46),
                  children: <Widget>[
                    const Text(
                      'Saxify streams audio from YouTube. All artwork and '
                      'metadata belong to their respective owners. Saxify is not '
                      'affiliated with, or endorsed by, any third-party streaming '
                      'service.',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
                child: Text('Legal',
                    style: TextStyle(color: accent.primary, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contact / Report a problem',
            subtitle: 'dastaanenajdik@gmail.com',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: SaxifyColors.textFaint),
            onTap: () async {
              await Clipboard.setData(
                  const ClipboardData(text: 'dastaanenajdik@gmail.com'));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support email copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SaxifyColors.surfaceAlt,
        border: Border.all(color: SaxifyColors.border),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10.5, color: SaxifyColors.textSecondary)),
    );
  }
}

// --------------------------------------------------------------------- tiles
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: SaxifyColors.textMuted)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: context.accent.primary.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 18, color: context.accent.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, color: SaxifyColors.textMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: context.accent.primary.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 18, color: context.accent.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, color: SaxifyColors.textMuted)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> choices;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return NeonCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.primary.withValues(alpha: 0.14),
                ),
                child: Icon(icon, size: 18, color: accent.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: SaxifyColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String choice in choices)
                ChoiceChip(
                  label: Text(choice.toUpperCase()),
                  selected: choice == value,
                  onSelected: (_) => onChanged(choice),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: choice == value ? accent.primary : SaxifyColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
