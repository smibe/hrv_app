import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:hrv_app/storage.dart';
import 'package:path_provider/path_provider.dart';

import 'hr_device.dart';

class HrPage extends StatefulWidget {
  final Storage storage;
  final HrDevice hrDevice;
  final void Function() connect;

  HrPage(this.storage, this.hrDevice, this.connect);

  @override
  _HrPageState createState() => _HrPageState(this.storage, hrDevice, connect);
}

class _HrPageState extends State<HrPage> {
  void Function() _connect;
  _HrPageState(this._storage, this._hrDevice, this._connect);
  int _hr = 0;
  int _rr = 0;
  bool _listening = false;
  String _state = "";

  HrDevice _hrDevice;
  Storage _storage;
  StreamSubscription<List<int>> _valuesSubscription;

  bool storing = false;
  List<int> buffer1 = List<int>.empty(growable: true);
  List<int> buffer2 = List<int>.empty(growable: true);
  List<int> currentBuffer;
  DateTime bufferStart;
  bool _storing = false;
  Stopwatch stopWatch = Stopwatch();
  Timer stopWatchTimer;
  var heartRateMeasurementGuid = Guid("00002a37-0000-1000-8000-00805f9b34fb");

  void initState() {
    currentBuffer = buffer1;
    stopWatchTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!stopWatch.isRunning) return;
      setState(() {});
    });
    _hrDevice.stateChanged.add(() {
      setState(() {
        _state = _hrDevice.state.toString();
      });
    });
    super.initState();
  }

  void stopListening() async {
    if (_hrDevice.service == null) return;
    var hrm = _hrDevice.service.characteristics.firstWhere((c) => c.uuid == heartRateMeasurementGuid, orElse: null);
    await storeRrData();
    _storage.files.add(_storage.storageFileName);
    _storage.onFilesChanged.invoke();

    _storage.storageFileName = "";

    if (hrm != null) {
      hrm.setNotifyValue(false);
      _valuesSubscription.cancel();
      setState(() {
        _hr = 0;
        _rr = 0;
        _listening = false;
      });
      stopWatch.stop();
      stopWatch.reset();
    }
  }

  Future initializeStorageFile() async {
    if (_storage.storageFileName == "") {
      var appDocDir = await getApplicationDocumentsDirectory();
      var now = DateTime.now().toIso8601String().replaceAll(':', '-');
      _storage.storageFileName = '${appDocDir.path}/hr_$now';
    }
  }

  Future storeRrData() async {
    _storing = true;
    await initializeStorageFile();
    var buffer = currentBuffer;
    currentBuffer = currentBuffer == buffer1 ? buffer2 : buffer1;

    var file = File(_storage.storageFileName);
    var record = {"time": bufferStart.toIso8601String(), "data": buffer};
    await file.writeAsString("RR=", mode: FileMode.append);
    await file.writeAsString(json.encode(record), mode: FileMode.append);
    await file.writeAsString("\n", mode: FileMode.append);
    buffer.clear();
    bufferStart = DateTime.now();
    _storing = false;
  }

  void storeActivity(String activity) async {
    await initializeStorageFile();
    var file = File(_storage.storageFileName);
    var record = {"time": DateTime.now().toIso8601String(), "activity": activity};
    await file.writeAsString("Activity=", mode: FileMode.append);
    await file.writeAsString(json.encode(record), mode: FileMode.append);
    await file.writeAsString("\n", mode: FileMode.append);
  }

  void startListening() {
    var hrm = _hrDevice.service.characteristics.firstWhere((c) => c.uuid == heartRateMeasurementGuid, orElse: null);
    if (hrm != null) {
      hrm.setNotifyValue(true);
      _valuesSubscription = hrm.value.listen((event) {
        setState(() {
          if (event.length >= 1) _hr = event[1];
          if (event.length >= 4) {
            _rr = 256 * event[3] + event[2];
            currentBuffer.add(_rr);
            if (currentBuffer.length > 25 && !_storing) {
              storeRrData();
            }
          }
        });
      });
      storeActivity(_selectedActivity);
      stopWatch.start();
      bufferStart = DateTime.now();
      setState(() {
        _listening = true;
      });
    }
  }

  List<String> _activities = ['Meditation', 'Chi Gong', 'Running', 'Sleeping', 'Sitting', 'Standing'];
  String _selectedActivity = 'Meditation';

  String durationToString(Duration duration) =>
      "${duration.inHours}:${duration.inMinutes.remainder(60)}:${(duration.inSeconds.remainder(60))}";

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_hrDevice.service == null) TextButton(onPressed: _connect, child: Text("Connect HeartRate device")),
          if (_hrDevice.device != null) Text("device: ${_hrDevice.device.name}"),
          if (_hrDevice.device != null) Text("status: $_state"),
          if (_listening)
            TextButton(
                onPressed: stopListening,
                child: Text(
                  "Stop",
                  style: TextStyle(fontSize: 30),
                ))
          else
            TextButton(onPressed: startListening, child: Text("Start", style: TextStyle(fontSize: 30))),
          Text(
            "HR: " + _hr.toString(),
            style: TextStyle(fontSize: 30, color: Colors.green[600]),
          ),
          Text(
            "RR: " + _rr.toString(),
            style: TextStyle(fontSize: 30, color: Colors.green[600]),
          ),
          Text(
            "Duration: " + durationToString(Duration(milliseconds: stopWatch.elapsedMilliseconds)),
            style: TextStyle(fontSize: 30, color: Colors.green[600]),
          ),
          DropdownButton<String>(
              items: _activities.map((e) => DropdownMenuItem(child: Text(e), value: e)).toList(),
              value: _selectedActivity,
              onChanged: (newValue) {
                setState(() {
                  _selectedActivity = newValue;
                });
              }),
          TextButton(onPressed: () => storeActivity(_selectedActivity), child: Text("Store Activity", style: TextStyle(fontSize: 30))),
        ],
      ),
    );
  }
}
