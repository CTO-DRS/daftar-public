import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/settings_service.dart';
import '../utils/platform_utils.dart';

/// قفل التطبيق ببصمة/قفل الجهاز. يقفل عند العودة بعد 30 ثانية في الخلفية.
class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});

  static final LocalAuthentication _auth = LocalAuthentication();

  /// هل يدعم الجهاز المصادقة؟
  static Future<bool> supported() async {
    if (!isMobilePlatform) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'افتح دفتر',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _locked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  bool get _enabled => isMobilePlatform && SettingsService.instance.appLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!_enabled) return;
    if (s == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (s == AppLifecycleState.resumed && !_busy) {
      final p = _pausedAt;
      if (p != null && DateTime.now().difference(p).inSeconds >= 30) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    final ok = await AppLock.authenticate();
    _busy = false;
    if (!mounted) return;
    if (ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 64),
          const SizedBox(height: 16),
          const Text('دفتر مقفل', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _unlock,
            icon: const Icon(Icons.fingerprint),
            label: const Text('فتح بالبصمة'),
          ),
        ]),
      ),
    );
  }
}
