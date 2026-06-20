/// Staff roles, in increasing order of privilege (BUILD_BRIEF.md §5.1).
///
/// The role stored in `users/{uid}.role` is the source of truth and is also
/// enforced in `firestore.rules`. Client-side route guards (see `auth_guard`)
/// mirror — never replace — those server checks.
enum UserRole {
  /// Full access, including user management and finance.
  owner,

  /// Manages a branch; finance access, no user management.
  supervisor,

  /// Front-counter staff: intake, customers, jobs.
  counter,

  /// Repairs jobs; no finance or user management.
  technician,

  /// Store / inventory keeper: manages parts and stock, but no finance or user
  /// management. Ratified addition to the §5.1 role list.
  store;

  /// Parses a stored role string, returning `null` if it is missing or
  /// unrecognized (e.g. a future role this build does not know about).
  static UserRole? fromName(String? name) {
    for (final role in UserRole.values) {
      if (role.name == name) return role;
    }
    return null;
  }

  /// Whether this role may view and edit finance (invoices/payments).
  bool get canFinance => this == owner || this == supervisor;

  /// Whether this role may manage staff accounts and assign roles.
  bool get canManageUsers => this == owner;

  /// Whether this role may manage inventory (parts/stock writes).
  bool get canManageInventory =>
      this == owner || this == supervisor || this == store;
}
