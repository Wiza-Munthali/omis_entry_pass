import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_repository.dart';

/// G1 Sign in: work email, then the 6-digit code (same flow as the portal, P2–P3).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const AuthFailure('Enter your work email address.');
    }
    await ref.read(authRepositoryProvider).sendCode(email);
    if (mounted) setState(() => _codeSent = true);
  });

  // On success the router moves on by itself (profile, then gate, then home).
  Future<void> _verify() => _run(() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const AuthFailure('Enter the 6-digit code from your email.');
    }
    await ref
        .read(authRepositoryProvider)
        .verifyCode(_email.text.trim().toLowerCase(), code);
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const SizedBox(height: AppSpacing.s4),
            Center(
              child: Image.asset('assets/logo.png', width: 96, height: 96),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'OMIS Entry',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              _codeSent
                  ? 'Enter the 6-digit code'
                  : 'Sign in with your work email',
              style: t.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              _codeSent
                  ? 'Sent to ${_email.text.trim()}'
                  : 'We\'ll email you a code. No password needed.',
              style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s3),
            if (!_codeSent)
              TextField(
                key: const Key('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _busy ? null : _sendCode(),
                decoration: const InputDecoration(
                  hintText: 'name@organisation',
                ),
              )
            else
              TextField(
                key: const Key('code'),
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w600,
                ),
                onChanged: (v) {
                  if (v.length == 6 && !_busy) _verify();
                },
                decoration: const InputDecoration(hintText: '······'),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s1),
              Text(
                _error!,
                style: t.labelLarge?.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.s3),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : Text(_codeSent ? 'Continue' : 'Send code'),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _code.clear();
                        _error = null;
                      }),
                child: const Text(
                  'Use a different email',
                  style: TextStyle(color: AppColors.brandStrong),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
