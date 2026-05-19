import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class SalesTrendGraph extends StatelessWidget {
  final List<OrderModel> orders;
  
  const SalesTrendGraph({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (index) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index)));
    
    final Map<String, double> dailySales = {};
    for (var date in last7Days) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      dailySales[key] = 0.0;
    }

    for (var order in orders) {
      final key = DateFormat('yyyy-MM-dd').format(order.createdAt);
      if (dailySales.containsKey(key)) {
        dailySales[key] = dailySales[key]! + order.finalAmount;
      }
    }

    final double maxSales = dailySales.values.isEmpty 
        ? 100.0 
        : dailySales.values.reduce((a, b) => a > b ? a : b);
    final double maxY = maxSales == 0 ? 100.0 : maxSales * 1.2;

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < last7Days.length; i++) {
      final date = last7Days[i];
      final key = DateFormat('yyyy-MM-dd').format(date);
      final sales = dailySales[key] ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sales,
              color: const Color(0xFF1E3A8A),
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Trend (Last 7 Days)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF1E3A8A),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₹${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < last7Days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E').format(last7Days[index]),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
