import '../domain/entities/app_user.dart';
import '../domain/entities/user_role.dart';

/// Route path constants, shared by the router and the guard so the two never
/// drift apart.
abstract final class Routes {
  const Routes._();

  /// Role-aware landing screen for signed-in staff.
  static const String home = '/';

  /// Public sign-in screen.
  static const String login = '/login';

  /// Finance area (estimates/invoices/payments) — finance roles only.
  static const String billing = '/billing';

  /// Staff management — owner only.
  static const String adminUsers = '/admin/users';

  /// Kanban jobs board — any active staff.
  static const String board = '/board';

  /// Jobs area prefix (covers `/jobs/:id` detail etc.) — any active staff.
  static const String jobs = '/jobs';

  /// New-job intake screen — any active staff.
  static const String jobIntake = '/jobs/new';

  /// Job search screen — any active staff.
  static const String jobSearch = '/jobs/search';

  /// Path to a single job's detail screen.
  static String jobDetail(String id) => '/jobs/$id';

  /// Path to a job's QR box-label screen.
  static String jobLabel(String id) => '/jobs/$id/label';
}

/// Every staff role. Used for routes that any *active* staff may open (jobs are
/// read/write for all staff per `firestore.rules`); listing them still bounces
/// signed-in users with no profile or a deactivated account back to home.
const Set<UserRole> _anyStaff = {
  UserRole.owner,
  UserRole.supervisor,
  UserRole.counter,
  UserRole.technician,
  UserRole.store,
};

/// Routes reachable without signing in.
const Set<String> _publicRoutes = {Routes.login};

/// Per-route role requirements. A route absent here is reachable by any active,
/// signed-in staff member; a present route additionally requires one of the
/// listed roles. These mirror — and must stay consistent with —
/// `firestore.rules`.
const Map<String, Set<UserRole>> routeRoleRequirements = {
  Routes.billing: {UserRole.owner, UserRole.supervisor},
  Routes.adminUsers: {UserRole.owner},
  Routes.board: _anyStaff,
  Routes.jobs: _anyStaff,
};

/// The roles allowed at [location], or `null` if the route has no role
/// restriction beyond being signed in. Matches a path and its sub-paths.
Set<UserRole>? requiredRolesFor(String location) {
  for (final entry in routeRoleRequirements.entries) {
    if (location == entry.key || location.startsWith('${entry.key}/')) {
      return entry.value;
    }
  }
  return null;
}

/// Pure redirect decision used by the GoRouter `redirect` callback.
///
/// Kept side-effect free so every role/route combination is unit-testable
/// without a widget tree.
///
/// - While auth is still loading ([authLoading]), stay put.
/// - Signed in but the profile is still loading ([profileLoading]) on a
///   guarded route: stay put rather than bouncing an authorized user.
/// - Signed out: allow public routes, otherwise go to [Routes.login].
/// - Signed in on a public route: go to [Routes.home].
/// - Signed in on a role-guarded route without an active, permitted profile:
///   bounce to [Routes.home] (which explains the lack of access).
///
/// Returns the path to redirect to, or `null` to proceed.
String? resolveRedirect({
  required bool authLoading,
  required bool profileLoading,
  required String? uid,
  required AppUser? user,
  required String location,
}) {
  if (authLoading) return null;

  final isPublic = _publicRoutes.contains(location);

  if (uid == null) {
    return isPublic ? null : Routes.login;
  }

  if (isPublic) return Routes.home;

  final required = requiredRolesFor(location);
  if (required != null) {
    // Wait for the profile before deciding access, so an authorized user is
    // not bounced during the profile-load window.
    if (profileLoading) return null;
    final permitted =
        user != null && user.active && required.contains(user.role);
    if (!permitted) return Routes.home;
  }

  return null;
}
