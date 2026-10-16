import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';

class PurchaseChart extends StatelessWidget {
  const PurchaseChart({
    super.key,
    required this.purchases,
    required this.supplierNames,
    required this.days,
  });

  final List<Purchase> purchases;
  final Map<String, String> supplierNames;
  final int days;

  static const _palette = [
    Color(0xFF1B7F3B),
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
  ];

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    final filtered = purchases.where((p) => !p.date.isBefore(cutoff)).toList();
    if (filtered.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Cần ≥ 2 lần nhập trong khoảng lọc để vẽ biểu đồ.'),
      );
    }

    final byKey = <String, List<Purchase>>{};
    for (final p in filtered) {
      final key = p.supplierId ?? '_none';
      byKey.putIfAbsent(key, () => []).add(p);
    }
    for (final list in byKey.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }

    final minMs = filtered.map((e) => e.date.millisecondsSinceEpoch).reduce(
          (a, b) => a < b ? a : b,
        );
    final maxMs = filtered.map((e) => e.date.millisecondsSinceEpoch).reduce(
          (a, b) => a > b ? a : b,
        );
    final span = (maxMs - minMs).clamp(1, 1 << 62);

    var colorIdx = 0;
    final lines = <LineChartBarData>[];
    final legend = <Widget>[];

    for (final entry in byKey.entries) {
      final color = _palette[colorIdx % _palette.length];
      colorIdx++;
      final name = entry.key == '_none'
          ? 'Không NCC'
          : (supplierNames[entry.key] ?? 'NCC');
      legend.add(
        Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: color),
              const SizedBox(width: 4),
              Text(name, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

      lines.add(
        LineChartBarData(
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
          spots: [
            for (final p in entry.value)
              FlSpot(
                (p.date.millisecondsSinceEpoch - minMs) / span,
                p.costPrice.toDouble(),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(children: legend),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 1,
              lineBarsData: lines,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (v, _) => Text(
                      formatVnd(v.round()).replaceAll('đ', ''),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
