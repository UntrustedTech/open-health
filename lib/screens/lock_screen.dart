import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';

/// Covers the app while it's locked and asks to unlock straight away.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoUnlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoUnlock();
  }

  /// Prompts straight away, but only while the app is on screen.
  void _autoUnlock() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _unlock();
  }

  void _unlock() {
    if (mounted) unawaited(context.read<AppLock>().unlock());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurs whatever was on screen, without showing it.
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: ColoredBox(
              color: context.groupedBackground.withValues(alpha: 0.92),
            ),
          ),
          SafeArea(
            // Scrolls when large text or a short screen would push Unlock
            // out of reach.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const IconTile(
                            icon: Icons.lock_rounded,
                            color: AppTheme.accent,
                            size: 72,
                          ),
                          const SizedBox(height: 20),
                          Text('Health is Locked', style: context.title2),
                          const SizedBox(height: 6),
                          Text(
                            'Use your fingerprint, face or screen lock to open it.',
                            textAlign: TextAlign.center,
                            style: context.subheadline.copyWith(
                              color: context.secondaryLabel,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CupertinoButton.filled(
                            onPressed: _unlock,
                            child: const Text('Unlock'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
