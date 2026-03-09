import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart' as downloader_impl;

Future<void> downloadBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) {
  return downloader_impl.downloadBytes(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
