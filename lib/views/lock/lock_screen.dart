import 'package:flutter/material.dart';

import '../../services/biometric_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';

/// Android 生物识别门卫：
/// 若用户开启了指纹/面容锁，启动时先拦截，验证通过后才展示主界面（金额可见）
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _checking = true;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _initLock();
  }

  Future<void> _initLock() async {
    final enabled = await BiometricService.instance.isEnabled();
    final supported =
        enabled && await BiometricService.instance.canAuthenticate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _locked = supported;
    });
    if (supported) await _authenticate();
  }

  Future<void> _authenticate() async {
    final ok = await BiometricService.instance.authenticate();
    if (!mounted) return;
    if (ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        ),
      );
    }
    if (_locked) {
      return LockScreen(onUnlock: _authenticate);
    }
    return widget.child;
  }
}

/// 锁定遮罩页：金额等数据默认隐藏（显示为星号占位），验证通过后进入
class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: GlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 48, color: AppTheme.accent),
                  const SizedBox(height: 12),
                  const Text('智慧记账已锁定',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '¥ * * * * *\n金额数据已隐藏，请验证指纹 / 面容后查看',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: onUnlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('立即解锁'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
