// Example of a simple line chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

enum ChartType { RR, HR, FFT }

class HrvLineChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;
  final ChartType chartType;

  HrvLineChart(this.seriesList, {this.animate, this.chartType = ChartType.RR});

  /// Creates a [LineChart] with sample data and no transition.
  factory HrvLineChart.withSampleData() {
    return new HrvLineChart(
      _createSampleData(),
      // Disable animations for image tests.
      animate: false,
    );
  }

  String formatTicks(num ticks) {
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

  factory HrvLineChart.withData(List<int> rrData, ChartType chartType) {
    return new HrvLineChart(
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
            tickFormatterSpec: charts.BasicNumericTickFormatterSpec(formatTicks),
            showAxisLine: false,
          ),
        ));
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<RRValues, int>> _createSampleData() {
    List<int> rawData = [1500, 1700, 1900, 1800, 1500, 1700, 1900, 1800];
    return _createData(rawData, ChartType.RR);
  }

  static List<charts.Series<RRValues, int>> _createData(List<int> rawData, ChartType chartType) {
    DateTime startTime = DateTime.now();
    DateTime time = startTime;
    List<RRValues> data = List.empty(growable: true);
    for (var rr in rawData) {
      if (chartType == ChartType.RR)
        data.add(RRValues(time, rr));
      else if (chartType == ChartType.HR) data.add(RRValues(time, rr == 0 ? 0 : 60000 ~/ rr));
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
