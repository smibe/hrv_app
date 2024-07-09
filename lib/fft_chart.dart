// Example of a simple line chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

import 'hrv_chart.dart';

class FftLineChart extends StatelessWidget {
  final List<charts.Series<dynamic, num>> seriesList;
  final bool animate;

  FftLineChart(this.seriesList, {this.animate = false});

  String formatTicks(num? ticks) {
    if (ticks == null) return "";
    var milliseconds = (ticks % 1000) ~/ 100;
    var seconds = ticks ~/ 1000;
    var minutes = seconds ~/ 60;
    seconds = seconds - minutes * 60;
    var hours = minutes ~/ 60;
    minutes = minutes - hours * 60;
    var s = milliseconds == 0 ? seconds.toString() : "$seconds.$milliseconds";
    if (hours == 0) return "$minutes:$s";
    return "$hours:$minutes:$s";
  }

  factory FftLineChart.withData(List<int> rrData, ChartType chartType) {
    return new FftLineChart(
      _createData(rrData, chartType),
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
          behaviors: [charts.PanAndZoomBehavior()],
          domainAxis: new charts.NumericAxisSpec(
            tickFormatterSpec:
                charts.BasicNumericTickFormatterSpec(formatTicks),
            showAxisLine: false,
          ),
        ));
  }

  static void fillToPowerOfTwo(List<int> data) {
    int size = 2;
    while (data.length > size) size *= 2;
    for (int i = data.length; i < size; i++) data.add(0);
  }

  static List<charts.Series<RRValues, int>> _createData(
      List<int> rawData, ChartType chartType) {
    DateTime startTime = DateTime.now();
    DateTime time = startTime;
    List<RRValues> data = List.empty(growable: true);
    for (var rr in rawData) {
      if (chartType == ChartType.RR)
        data.add(RRValues(time, rr));
      else if (chartType == ChartType.HR) data.add(RRValues(time, 60000 ~/ rr));
      time = time.add(Duration(milliseconds: rr));
    }

    return [
      new charts.Series<RRValues, int>(
        id: 'RR',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (RRValues rrValues, _) =>
            rrValues.time.millisecondsSinceEpoch -
            startTime.millisecondsSinceEpoch,
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
