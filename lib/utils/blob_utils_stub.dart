import 'dart:typed_data';

/// Stub for non-web platforms. Never called due to kIsWeb guard.
String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Blob URLs are only available on web');
}
