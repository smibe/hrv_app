import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'event.dart';

class Storage {
  String storageFileName = "";
  List<String> files = List<String>.empty(growable: true);

  Event onFilesChanged = Event();

  Future<List<String>> getFiles() async {
    var appDocDir = await getApplicationDocumentsDirectory();
    var directory = Directory(appDocDir.path);
    var files = directory.listSync();
    this.files.clear();
    for (var f in files) {
      var path = f.path;
      var idx = path.lastIndexOf(Platform.pathSeparator);
      if (idx > 0) {
        var filename = path.substring(idx + 1);
        if (filename.startsWith("hr_") && filename != storageFileName) this.files.add(filename);
      }
    }
    return this.files;
  }
}
