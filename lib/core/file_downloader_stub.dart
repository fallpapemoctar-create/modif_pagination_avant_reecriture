Future<void> downloadBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  // Downloads are only supported on web; no-op elsewhere.
}
