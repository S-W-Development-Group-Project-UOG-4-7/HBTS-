import "dart:io";

Future<String?> saveBytes(String filename, List<int> bytes) async {
  final dir = Directory.systemTemp;
  final file = File("${dir.path}${Platform.pathSeparator}$filename");
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
