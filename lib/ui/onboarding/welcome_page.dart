import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../widgets/neon.dart';
import '../widgets/saxify_logo.dart';

/// First-launch profile setup. The name is stored locally and used throughout
/// Saxify; there is no email sign-up or account requirement.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onComplete});

  final Future<void> Function(String name) onComplete;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final String value = _name.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter a name to continue.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onComplete(value);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save your name. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Scaffold(
      backgroundColor: SaxifyColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SaxifyLogo(size: constraints.maxWidth < 360 ? 82 : 104, accent: accent),
                      const SizedBox(height: 28),
                      Text(
                        "Who's listening?",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: constraints.maxWidth < 360 ? 27 : 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: SaxifyColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a name for your music space. You can change it later in Settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: SaxifyColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _name,
                        autofocus: true,
                        maxLength: 32,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _continue(),
                        decoration: InputDecoration(
                          hintText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: accent.primary),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      NeonButton(
                        label: _saving ? 'Saving…' : 'Enter Saxify',
                        icon: Icons.arrow_forward_rounded,
                        expand: true,
                        onPressed: _saving ? null : _continue,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
