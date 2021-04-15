import 'dart:convert';
import 'dart:io';
import 'package:stats/stats.dart';

import 'package:flutter/material.dart';
import 'package:hrv_app/hrv_chart.dart';
import 'package:share/share.dart';
import 'package:path_provider/path_provider.dart';
import 'storage.dart';
import 'dart:math';

class StoragePage extends StatefulWidget {
  final Storage _storage;
  StoragePage(this._storage);

  @override
  _StoragePageState createState() => _StoragePageState(_storage);
}

class _StoragePageState extends State<StoragePage> {
  List<String> _files = List<String>.empty();
  Storage _storage;
  List<int> _data;
  double _rmssd;
  double _sdnn;
  Duration duration = Duration(milliseconds: 0);
  String _currentFileName = "";

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
    files.sort((f, g) => g.compareTo(f));
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

  void prepareData(int idx) async {
    var fileName = widget._storage.files[idx];
    var appDocDir = await getApplicationDocumentsDirectory();
    File file = File('${appDocDir.path}/$fileName');
    List<int> data = List.empty(growable: true);
    var lines = await file.readAsLines();
    for (var line in lines) {
      if (line.startsWith("RR")) {
        int idx = line.indexOf('=');
        var decoded = json.decode(line.substring(idx + 1));
        if (decoded is Map) {
          data.addAll(decoded["data"].cast<int>());
        } else if (decoded is Iterable) {
          data.addAll(decoded.cast<int>());
        }
      }
    }

    if (data.isEmpty) return;

    var stats = Stats.fromData(data);
    int squareSum = 0;
    for (int i = 0; i < data.length - 1; i++) {
      int diff = data[i] - data[i + 1];
      squareSum += diff * diff;
    }

    setState(() {
      _currentFileName = fileName;
      _data = data;
      _sdnn = stats.standardDeviation;
      _rmssd = sqrt(squareSum / (data.length - 1));
      duration = Duration(milliseconds: data.sum);
    });
  }

  String getDuration(Duration duration) {
    String result = duration.toString();
    return result.substring(0, result.length - 7);
  }

  @override
  Widget build(Object context) {
    return Column(
      children: [
        if (_data != null) HrvLineChart.withData(_data),
        if (_data != null) Text("Duration: ${getDuration(duration)}"),
        if (_data != null) Text("SDNN: ${_sdnn.toStringAsFixed(2)}"),
        if (_data != null) Text("RMSSD: ${_rmssd.toStringAsFixed(2)}"),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(10, 20, 10, 20),
            itemCount: _files.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                  padding: EdgeInsets.fromLTRB(30, 0, 10, 0),
                  height: 30,
                  color: _currentFileName == widget._storage.files[index] ? Colors.grey[200] : Colors.white,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => prepareData(index),
                        child: Text(dataFileToString(widget._storage.files[index])),
                      ),
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
          ),
        ),
      ],
    );
  }
}
