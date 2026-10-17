import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown with a message that can be shown to the user as-is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// Emits the signed-in user id, or null when signed out.
  Stream<String?> userIdChanges();
  String? get currentUserId;
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  Stream<String?> userIdChanges() =>
      _client.auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> sendCode(String email) async {
    try {
      // Operators are created by an admin; the gate app never creates accounts.
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
    } on AuthException catch (e) {
      if (e.code == 'otp_disabled' ||
          e.message.toLowerCase().contains('signups not allowed')) {
        throw const AuthFailure(
          'This email is not set up for the gate app. Ask an admin to invite you.',
        );
      }
      if (e.code == 'over_email_send_rate_limit') {
        throw const AuthFailure(
          'Too many codes requested. Wait a minute and try again.',
        );
      }
      throw const AuthFailure(
        'Could not send the code. Check the email and your connection.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Could not send the code. Check your connection.',
      );
    }
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
    } on AuthException {
      throw const AuthFailure(
        'That code is wrong or has expired. Check the latest email or send a new code.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Could not check the code. Check your connection.',
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
