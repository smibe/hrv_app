import 'package:flutter/material.dart';
import 'package:hrv_app/hr_device.dart';
import 'package:hrv_app/storage_page.dart';

import 'connect_page.dart';
import 'hr_page.dart';
import 'hr_device.dart';
import 'storage.dart';

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
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _storage = Storage();
  var _device = HrDevice();
  var _currentIdx = 0;
  late List<Widget> _children;

  @override
  void initState() {
    _children = [
      HrPage(_storage, _device, connect),
      ConnectPage(_device),
      StoragePage(_storage)
    ];
    super.initState();
  }

  void connect() {
    setState(() {
      _currentIdx = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: IndexedStack(index: _currentIdx, children: _children),
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
        currentIndex: _currentIdx,
        selectedItemColor: Colors.amber[800],
        onTap: (idx) {
          setState(() {
            _currentIdx = idx;
          });
        },
      ),
    );
  }
}
