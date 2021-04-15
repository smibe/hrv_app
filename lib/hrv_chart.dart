// Example of a simple line chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class HrvLineChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  HrvLineChart(this.seriesList, {this.animate});

  /// Creates a [LineChart] with sample data and no transition.
  factory HrvLineChart.withSampleData() {
    return new HrvLineChart(
      _createSampleData(),
      // Disable animations for image tests.
      animate: false,
    );
  }

  factory HrvLineChart.withData(List<int> rrData) {
    return new HrvLineChart(
      _createData(rrData),
      // Disable animations for image tests.
      animate: false,
    );
  }
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 200,
        child: new charts.LineChart(
          seriesList,
          animate: animate,
        ));
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<RRValues, int>> _createSampleData() {
    List<int> rawData = [1500, 1700, 1900, 1800, 1500, 1700, 1900, 1800];
    return _createData(rawData);
  }

  static List<charts.Series<RRValues, int>> _createData(List<int> rawData) {
    DateTime startTime = DateTime.now();
    DateTime time = startTime;
    List<RRValues> data = List.empty(growable: true);
    for (var rr in rawData) {
      data.add(RRValues(time, rr));
      time = time.add(Duration(milliseconds: rr));
    }

    return [
      new charts.Series<RRValues, int>(
        id: 'RR',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (RRValues rrValues, _) => rrValues.time.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch,
        measureFn: (RRValues rrValues, _) => rrValues.rr,
        data: data,
      )
    ];
  }
}

/// Sample linear data type.
class RRValues {
  final DateTime time;
  final int rr;

  RRValues(this.time, this.rr);
}
