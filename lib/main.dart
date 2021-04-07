import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:hrv_app/storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';

import 'hr_device.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: "Gerhard's Heart Rate Monitor"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _searching = false;
  Map<DeviceIdentifier, BluetoothDevice> _devices = Map<DeviceIdentifier, BluetoothDevice>();
  HrDevice _hrDevice = HrDevice();
  Storage _storage = new Storage();
  int _hr = 0;
  int _rr = 0;
  bool _listening = true;
  String _state = "";
  StreamSubscription<List<ScanResult>> _scanForDevices;
  StreamSubscription<List<int>> _valuesSubscription;
  StreamSubscription<BluetoothDeviceState> _stateSubscription;

  bool storing = false;
  List<int> buffer1 = List<int>.empty(growable: true);
  List<int> buffer2 = List<int>.empty(growable: true);
  List<int> currentBuffer;
  bool _storing = false;
  Stopwatch stopWatch = Stopwatch();
  Timer stopWatchTimer;

  @override
  void initState() {
    currentBuffer = buffer1;
    stopWatchTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!stopWatch.isRunning) return;
      setState(() {});
    });
    super.initState();
  }

  void searchForHrvDevice() {
    if (_searching) return;
    setState(() {
      _searching = true;
      _devices.clear();
    });
    FlutterBlue flutterBlue = FlutterBlue.instance;
    // Start scanning
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    // Listen to scan results
    _scanForDevices = flutterBlue.scanResults.listen((results) {
      // do something with scan results
      for (ScanResult r in results) {
        setState(() {
          if (r.device.name != "") _devices[r.device.id] = r.device;
        });
        print('${r.device.name} found! rssi: ${r.rssi}');
      }
    });
  }

  void stopSearch() {
    if (!_searching) return;
    FlutterBlue flutterBlue = FlutterBlue.instance;
    _scanForDevices.cancel();
    flutterBlue.stopScan();
    setState(() {
      _searching = false;
    });
  }

  void stopListening() {
    if (_hrDevice.service == null) return;
    var hrm = _hrDevice.service.characteristics.firstWhere((c) => c.uuid == heartRateMeasurementGuid, orElse: null);
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

  void connect(BluetoothDevice device) async {
    if (await device.state.first == BluetoothDeviceState.connected) return;

    await device.connect(timeout: Duration(seconds: 3));
    _hrDevice.service = null;
    var services = await device.discoverServices();
    services.forEach((service) {
      if (_hrDevice.service == null && service.uuid == heartRateService) {
        _hrDevice.device = device;
        _hrDevice.service = service;
        _stateSubscription = _hrDevice.device.state.listen((event) {
          setState(() {
            _state = event.toString();
          });
        });
        print("HR sensor found.");
      }
    });
    if (_hrDevice.service != null) {
      startListening();
    }
  }

  void storeRrData() async {
    _storing = true;
    if (_storage.storageFileName == "") {
      var appDocDir = await getApplicationDocumentsDirectory();
      var now = DateTime.now().toIso8601String().replaceAll(':', '-');
      _storage.storageFileName = '${appDocDir.path}/hr_$now';
    }
    var buffer = currentBuffer;
    currentBuffer = currentBuffer == buffer1 ? buffer2 : buffer1;

    String line = json.encode(buffer) + "\n";

    var file = File(_storage.storageFileName);
    await file.writeAsString(line, mode: FileMode.append);
    _storing = false;
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
        stopWatch.start();
      });
      setState(() {
        _listening = true;
      });
    }
  }

  bool _showFiles = false;
  var _files = List<String>.empty(growable: true);
  void showFiles(bool show) async {
    setState(() {
      _showFiles = show;
    });

    if (_showFiles) {
      var appDocDir = await getApplicationDocumentsDirectory();
      var directory = Directory(appDocDir.path);
      var files = directory.listSync();
      setState(() {
        _files.clear();
        for (var f in files) {
          var path = f.path;
          var idx = path.lastIndexOf('/');
          if (idx > 0) {
            var filename = path.substring(idx + 1);
            if (filename.startsWith("hr_") && filename != _storage.storageFileName) _files.add(filename);
          }
        }
      });
    } else {
      setState(() {
        _files.clear();
      });
    }
  }

  void shareFile(String file) async {
    var appDocDir = await getApplicationDocumentsDirectory();
    Share.shareFiles(['${appDocDir.path}/$file'], text: 'HR data file');
  }

  String dataFileToString(String dataFilename) {
    var idx = dataFilename.lastIndexOf('.');
    if (idx > 0) dataFilename = dataFilename.substring(0, idx);
    idx = dataFilename.lastIndexOf('T');
    if (idx > 0) {
      dataFilename = dataFilename.substring(0, idx) + " " + dataFilename.substring(idx + 1).replaceAll("-", ":");
    }
    return dataFilename;
  }

  String durationToString(Duration duration) =>
      "${duration.inHours}:${duration.inMinutes.remainder(60)}:${(duration.inSeconds.remainder(60))}";

  var heartRateService = Guid("0000180d-0000-1000-8000-00805f9b34fb");
  var heartRateMeasurementGuid = Guid("00002a37-0000-1000-8000-00805f9b34fb");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!_searching && _hrDevice.service == null)
              TextButton(onPressed: searchForHrvDevice, child: Text("Search for HeartRate device"))
            else if (_hrDevice.service == null)
              TextButton(onPressed: stopSearch, child: Text("Stop search")),
            if (_hrDevice.service == null && _devices != null && _devices.length > 0)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (BuildContext context, int index) {
                    var key = _devices.keys.toList()[index];
                    return TextButton(onPressed: () => connect(_devices[key]), child: Text(_devices[key].name));
                  },
                ),
              ),
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
            if (_showFiles)
              TextButton(onPressed: () => showFiles(false), child: Text("Hide files", style: TextStyle(fontSize: 30)))
            else
              TextButton(onPressed: () => showFiles(true), child: Text("Show files", style: TextStyle(fontSize: 30))),
            if (_showFiles)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                        padding: EdgeInsets.fromLTRB(30, 0, 10, 0),
                        height: 30,
                        child: Row(
                          children: [
                            TextButton(onPressed: () => shareFile(_files[index]), child: Text(dataFileToString(_files[index]))),
                            IconButton(
                                icon: Icon(
                                  Icons.share,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  shareFile(_files[index]);
                                }),
                            IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  var appDocDir = await getApplicationDocumentsDirectory();
                                  var file = File('${appDocDir.path}/${_files[index]}');
                                  file.delete();
                                  setState(() {
                                    _files.removeAt((index));
                                  });
                                })
                          ],
                        ));
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.healing),
            label: 'HR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.device_hub),
            label: 'Device',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage),
            label: 'Files',
          ),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.amber[800],
        onTap: (idx) {},
      ),
    );
  }
}
