import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'hr_device.dart';

class ConnectPage extends StatefulWidget {
  final HrDevice _hrDevice;

  ConnectPage(this._hrDevice);

  @override
  _ConnectPageState createState() => _ConnectPageState(_hrDevice);
}

class _ConnectPageState extends State<ConnectPage> {
  HrDevice _hrDevice;
  bool _searching = false;
  Map<DeviceIdentifier, BluetoothDevice> _devices = Map<DeviceIdentifier, BluetoothDevice>();
  StreamSubscription<List<ScanResult>> _scanForDevices;
  StreamSubscription<BluetoothDeviceState> _stateSubscription;
  var heartRateService = Guid("0000180d-0000-1000-8000-00805f9b34fb");

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

  void connect(BluetoothDevice device) async {
    print('Connecting to device: ${device.name} ...');
    await device.connect(timeout: Duration(seconds: 10));
    print('Device ${device.name} connected.');
    _hrDevice.service = null;
    var services = await device.discoverServices();
    services.forEach((service) {
      print('Discovered servie: ${service.uuid}');
      if (_hrDevice.service == null && service.uuid == heartRateService) {
        print("Detected HR service.");
        _hrDevice.device = device;
        _hrDevice.service = service;
        _stateSubscription = _hrDevice.device.state.listen((event) {
          setState(() {
            _hrDevice.state = event;
            _hrDevice.stateChanged.invoke();
          });
        });
      }
    });
  }

  void disconnect(BluetoothDevice device) async {
    if (await device.state.first == BluetoothDeviceState.disconnected) return;
    await device.disconnect();
    setState(() {
      _hrDevice.service = null;
    });
  }

  _ConnectPageState(this._hrDevice);
  @override
  Widget build(BuildContext context) {
    return Center(
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
          if (_hrDevice.device != null && _hrDevice.state == BluetoothDeviceState.connected)
            TextButton(
                onPressed: () {
                  disconnect(_hrDevice.device);
                },
                child: Text("Disconnect")),
          if (_hrDevice.device != null) Text("device: ${_hrDevice.device.name}"),
          if (_hrDevice.device != null) Text("status: ${_hrDevice.state}"),
        ],
      ),
    );
  }
}
