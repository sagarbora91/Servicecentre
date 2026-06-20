import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_placeholder_screen.dart';

/// Provides the app's [GoRouter].
///
/// M0 exposes a single placeholder home route. Role-based route guards and the
/// real feature routes (board, job detail, etc.) are added from M1 onward.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
    ],
  );
});
