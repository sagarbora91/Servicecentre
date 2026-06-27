import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_guard.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/guarded_placeholder_screens.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/manage_staff_screen.dart';
import '../features/auth/presentation/screens/role_home_screen.dart';
import '../features/customers/presentation/screens/customer_detail_screen.dart';
import '../features/customers/presentation/screens/customer_list_screen.dart';
import '../features/data_import/presentation/screens/import_screen.dart';
import '../features/inventory/presentation/screens/part_detail_screen.dart';
import '../features/inventory/presentation/screens/parts_list_screen.dart';
import '../features/jobs/presentation/screens/board_screen.dart';
import '../features/jobs/presentation/screens/intake_screen.dart';
import '../features/jobs/presentation/screens/job_detail_screen.dart';
import '../features/jobs/presentation/screens/job_scan_screen.dart';
import '../features/jobs/presentation/screens/job_search_screen.dart';
import '../features/jobs/presentation/screens/qr_label_screen.dart';

/// Provides the app's [GoRouter] with auth-aware redirects (M1).
///
/// Redirect logic is delegated to the pure [resolveRedirect] so it is
/// unit-testable; the router refreshes whenever auth state or the current
/// user's profile changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authUidProvider);
      final uid = authState.valueOrNull;
      final userAsync = ref.read(currentUserProvider);
      return resolveRedirect(
        authLoading: authState.isLoading,
        profileLoading: uid != null && userAsync.isLoading,
        uid: uid,
        user: userAsync.valueOrNull,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (context, state) => const RoleHomeScreen(),
      ),
      GoRoute(
        path: Routes.billing,
        name: 'billing',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: Routes.adminUsers,
        name: 'adminUsers',
        builder: (context, state) => const ManageStaffScreen(),
      ),
      GoRoute(
        path: Routes.dataImport,
        name: 'dataImport',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: Routes.board,
        name: 'board',
        builder: (context, state) => const BoardScreen(),
      ),
      // `/jobs/new` and `/jobs/search` MUST be registered before the
      // `/jobs/:id` param route — go_router matches greedily and would
      // otherwise capture "new"/"search" as an :id.
      GoRoute(
        path: Routes.jobIntake,
        name: 'jobIntake',
        builder: (context, state) => const IntakeScreen(),
      ),
      GoRoute(
        path: Routes.jobSearch,
        name: 'jobSearch',
        builder: (context, state) => const JobSearchScreen(),
      ),
      GoRoute(
        path: Routes.jobScan,
        name: 'jobScan',
        builder: (context, state) => const JobScanScreen(),
      ),
      // More specific (`/jobs/:id/label`) before `/jobs/:id`.
      GoRoute(
        path: '${Routes.jobs}/:id/label',
        name: 'jobLabel',
        builder: (context, state) =>
            QrLabelScreen(jobId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '${Routes.jobs}/:id',
        name: 'jobDetail',
        builder: (context, state) =>
            JobDetailScreen(jobId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.customers,
        name: 'customers',
        builder: (context, state) => const CustomerListScreen(),
      ),
      GoRoute(
        path: '${Routes.customers}/:id',
        name: 'customerDetail',
        builder: (context, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.parts,
        name: 'parts',
        builder: (context, state) => const PartsListScreen(),
      ),
      GoRoute(
        path: '${Routes.parts}/:id',
        name: 'partDetail',
        builder: (context, state) =>
            PartDetailScreen(partId: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
});

/// Bridges Riverpod auth providers to a [Listenable] so [GoRouter] re-runs its
/// redirect when sign-in state or the user's profile changes.
///
/// The `ref.listen` subscriptions are owned by `routerProvider` and torn down
/// automatically when it is disposed, so no manual cleanup is needed here.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref
      ..listen(authUidProvider, (_, __) => notifyListeners())
      ..listen(currentUserProvider, (_, __) => notifyListeners());
  }
}
