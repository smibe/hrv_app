import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share/share.dart';
import 'package:path_provider/path_provider.dart';
import 'storage.dart';

class StoragePage extends StatefulWidget {
  final Storage _storage;
  StoragePage(this._storage);

  @override
  _StoragePageState createState() => _StoragePageState(_storage);
}

class _StoragePageState extends State<StoragePage> {
  List<String> _files = List<String>.empty();
  Storage _storage;

  _StoragePageState(this._storage);

  String dataFileToString(String dataFilename) {
    var idx = dataFilename.lastIndexOf('.');
    if (idx > 0) dataFilename = dataFilename.substring(0, idx);
    idx = dataFilename.lastIndexOf('T');
    if (idx > 0) {
      dataFilename = dataFilename.substring(0, idx) + " " + dataFilename.substring(idx + 1).replaceAll("-", ":");
    }
    return dataFilename;
  }

  void shareFile(String file) async {
    var appDocDir = await getApplicationDocumentsDirectory();
    Share.shareFiles(['${appDocDir.path}/$file'], text: 'HR data file');
  }

  void getFiles() async {
    var files = await _storage.getFiles();
    setState(() {
      _files = files;
    });
  }

  @override
  void initState() {
    getFiles();
    _storage.onFilesChanged.add(() {
      setState(() {
        getFiles();
      });
    });
    super.initState();
  }

  @override
  Widget build(Object context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(10, 20, 10, 20),
      itemCount: _files.length,
      itemBuilder: (BuildContext context, int index) {
        return Container(
            padding: EdgeInsets.fromLTRB(30, 0, 10, 0),
            height: 30,
            child: Row(
              children: [
                TextButton(
                    onPressed: () => shareFile(widget._storage.files[index]), child: Text(dataFileToString(widget._storage.files[index]))),
                IconButton(
                    icon: Icon(
                      Icons.share,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      shareFile(widget._storage.files[index]);
                    }),
                IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Colors.blue,
                    ),
                    onPressed: () async {
                      var appDocDir = await getApplicationDocumentsDirectory();
                      var file = File('${appDocDir.path}/${widget._storage.files[index]}');
                      file.delete();
                      setState(() {
                        widget._storage.files.removeAt((index));
                      });
                    })
              ],
            ));
      },
    );
  }
}
