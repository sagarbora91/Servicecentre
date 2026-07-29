import 'dart:typed_data';

/// A generated branch backup ready for local save or future Drive upload.
class BackupFile {
  /// Creates a backup artifact.
  const BackupFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  /// Suggested file name.
  final String fileName;

  /// Content MIME type.
  final String mimeType;

  /// Complete backup payload.
  final Uint8List bytes;
}
