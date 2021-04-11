import 'package:flutter_blue/flutter_blue.dart';

import 'event.dart';

class HrDevice {
  BluetoothDevice device;
  BluetoothService service;
  BluetoothDeviceState state;
  Event stateChanged = Event();
}
