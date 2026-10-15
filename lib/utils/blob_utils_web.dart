// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// This file is intentionally web-only — dart:html is required for blob URLs.
import 'dart:html' as html;
import 'dart:typed_data';

/// Creates a blob URL from bytes — web only.
String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrl(blob);
}
