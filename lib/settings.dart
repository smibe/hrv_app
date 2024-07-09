import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> dataDirectory() async {
  var dir = await getApplicationDocumentsDirectory();
  return Platform.isWindows ? '${dir.path}/hrv_data' : dir.path;
}
