// Stub classes to prevent compilation errors on mobile/desktop platforms
// ignore_for_file: camel_case_types

class Blob {
  Blob(List<dynamic> bytes);
}

class Url {
  static String createObjectUrlFromBlob(dynamic blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}
