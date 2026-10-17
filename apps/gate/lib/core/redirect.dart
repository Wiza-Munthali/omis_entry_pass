import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';

/// Routes that only make sense before the app is ready.
const _setupRoutes = {'/sign-in', '/loading', '/not-operator'};

/// Where the app should be, given who is signed in and where this phone is posted.
/// Returns null to stay on [location]. Kept pure so it can be unit-tested.
String? resolveRedirect({
  required String location,
  required AsyncValue<String?> userId,
  required AsyncValue<Profile?> profile,
  required AsyncValue<Gate?> gate,
}) {
  String? go(String target) => location == target ? null : target;

  if (userId.isLoading && !userId.hasValue) return go('/loading');
  if (userId.value == null) return location == '/sign-in' ? null : '/sign-in';

  if (profile.isLoading && !profile.hasValue) return go('/loading');
  if (profile.hasError) {
    return go('/loading'); // shows the error with retry / sign out
  }
  if (profile.value?.isOperator != true) return go('/not-operator');

  if (gate.isLoading && !gate.hasValue) return go('/loading');
  if (gate.value == null) return go('/gate');

  if (_setupRoutes.contains(location)) return '/home';
  return null;
}
