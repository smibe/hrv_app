import 'dart:convert';
import 'dart:io';
import 'package:stats/stats.dart';

import 'package:flutter/material.dart';
import 'package:hrv_app/hrv_chart.dart';
import 'package:share/share.dart';
import 'package:path_provider/path_provider.dart';
import 'fft_chart.dart';
import 'storage.dart';
import 'dart:math';
import 'settings.dart' as settings;

class StoragePage extends StatefulWidget {
  final Storage _storage;
  StoragePage(this._storage);

  @override
  _StoragePageState createState() => _StoragePageState(_storage);
}

class _StoragePageState extends State<StoragePage> {
  List<String> _files = List<String>.empty();
  Storage _storage;
  late List<int> _data;
  double _rmssd = 0;
  num _sdnn = 0;
  late double _hrMedian;
  Duration duration = Duration(milliseconds: 0);
  String _currentFileName = "";
  ChartType _chartType = ChartType.HR;

  _StoragePageState(this._storage);

  String dataFileToString(String dataFilename) {
    var idx = dataFilename.lastIndexOf('.');
    if (idx > 0) dataFilename = dataFilename.substring(0, idx);
    idx = dataFilename.lastIndexOf('T');
    if (idx > 0) {
      dataFilename = dataFilename.substring(0, idx) +
          " " +
          dataFilename.substring(idx + 1).replaceAll("-", ":");
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

  int calcAverageOfPrevious(List<int> data, int idx, int numOfPoints) {
    int sum = 0;
    int count = 0;
    idx--;
    while (idx > 0) {
      if (data[idx] != 0) {
        sum += data[idx];
        count++;
      }

      idx--;
      if (count > numOfPoints) {
        break;
      }
    }
    return sum ~/ count;
  }

  void normalizeData(List<int> data, int seconds) {
    int sum = data.sum;
    int startIdx = 0;
    int endIdx = data.length - 1;
    if (sum > seconds * 1000) {
      // cut 2/3 from start
      int cutFirst = ((sum - seconds * 1000) * 2) ~/ 3;
      int interval = 0;
      int idx = 0;
      while (interval < cutFirst) {
        interval += data[idx];
        idx++;
      }
      startIdx = idx;

      // remove outliers, we remove every number and successor if the difference is greater than 20% of the medium of previous 5 numbers
      for (int i = startIdx; i < data.length; i++) {
        var average = calcAverageOfPrevious(data, i, 5);
        if (average > 0 &&
            (data[i] < average - average * 15 ~/ 100 ||
                data[i] > average + average * 15 ~/ 100)) {
          data[i] = 0;
        }
      }

      // remove all nulls
      data.removeWhere((element) => element == 0);

      // now calculate last index to have an interval of seconds
      startIdx = idx;
      interval = 0;
      while (interval < seconds * 1000) {
        if (idx >= data.length) break;
        interval += data[idx];
        idx++;
      }
      endIdx = idx;
    }

    data.removeRange(0, startIdx);
    data.removeRange(endIdx - startIdx, data.length);
  }

  void prepareData(int idx) async {
    var fileName = widget._storage.files[idx];
    var appDocDir = await settings.dataDirectory();
    File file = File('${appDocDir}/$fileName');
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

    normalizeData(data, 300);

    if (data.isEmpty) return;

    if (_chartType == ChartType.HR) data.map((e) => 60000 / e);

    var stats = Stats.fromData(data);
    int squareSum = 0;
    for (int i = 0; i < data.length - 1; i++) {
      int diff = data[i] - data[i + 1];
      squareSum += diff * diff;
    }

    setState(() {
      _currentFileName = fileName;
      _data = data;
      _hrMedian = 60000 / stats.median;
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
        if (Platform.isWindows && _data != null && _chartType == ChartType.FFT)
          FftLineChart.withData(_data, _chartType),
        if (_data != null && _chartType != ChartType.FFT)
          HrvLineChart.withData(_data, _chartType),
        if (_data != null) Text("Duration: ${getDuration(duration)}"),
        if (_data != null) Text("SDNN: ${_sdnn.toStringAsFixed(2)}"),
        if (_data != null) Text("RMSSD: ${_rmssd.toStringAsFixed(2)}"),
        if (_data != null) Text("HR median: ${_hrMedian.toStringAsFixed(1)}"),
        if (_data != null)
          Row(
            children: [
              TextButton(
                  onPressed: () => setState(() => _chartType = ChartType.values[
                      (_chartType.index + 1) % ChartType.values.length]),
                  child: Text(_chartType.toString())),
            ],
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(10, 20, 10, 20),
            itemCount: _files.length,
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                  padding: EdgeInsets.fromLTRB(30, 0, 10, 0),
                  height: 30,
                  color: _currentFileName == widget._storage.files[index]
                      ? Colors.grey[200]
                      : Colors.white,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => prepareData(index),
                        child: Text(
                            dataFileToString(widget._storage.files[index])),
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
                            var appDocDir =
                                await getApplicationDocumentsDirectory();
                            var file = File(
                                '${appDocDir.path}/${widget._storage.files[index]}');
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
