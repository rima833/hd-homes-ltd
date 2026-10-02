import 'dart:typed_data';

void downloadExportBytes({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) {
  throw UnsupportedError('File download is only available in the browser.');
}
