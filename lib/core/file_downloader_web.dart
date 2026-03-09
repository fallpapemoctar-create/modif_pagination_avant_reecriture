import 'dart:convert' as convert;

import 'package:web/web.dart' as web;

Future<void> downloadBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final dataUri = 'data:$mimeType;base64,${convert.base64Encode(bytes)}';
  final anchor = web.HTMLAnchorElement()
    ..href = dataUri
    ..style.display = 'none'
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
