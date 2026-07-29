import '../../../../core/errors/result.dart';
import '../entities/branch_settings.dart';

/// Contract for reading and writing per-branch [BranchSettings].
///
/// Lives in `domain` (no Firebase imports); the `data` implementation adapts
/// Cloud Firestore. The live read exposes a [Stream] so screens react to config
/// changes; the write returns a [Result] and never throws across layers.
abstract interface class SettingsRepository {
  /// Streams the settings for [branchId], emitting [BranchSettings.defaults]
  /// when no document exists yet.
  Stream<BranchSettings> watchSettings(String branchId);

  /// Persists [settings] for its branch (owner-only in `firestore.rules`).
  Future<Result<void>> saveSettings(BranchSettings settings, String by);
}
