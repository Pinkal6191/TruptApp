import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/order_model.dart';

class CrateSalesBreakdown extends StatefulWidget {
  final List<OrderModel> orders;

  const CrateSalesBreakdown({super.key, required this.orders});

  @override
  State<CrateSalesBreakdown> createState() => _CrateSalesBreakdownState();
}

class _CrateSalesBreakdownState extends State<CrateSalesBreakdown> {
  String _selectedPeriod = 'All Time'; // 'All Time', 'This Month', 'This Year'

  @override
  Widget build(BuildContext context) {
    // 1. Filter orders based on selected period
    final now = DateTime.now();
    final filteredOrders = widget.orders.where((order) {
      if (_selectedPeriod == 'This Month') {
        return order.createdAt.month == now.month && order.createdAt.year == now.year;
      } else if (_selectedPeriod == 'This Year') {
        return order.createdAt.year == now.year;
      }
      return true; // All Time
    }).toList();

    // 2. Aggregate crate sales
    int count200ml = 0;
    int count500ml = 0;
    int count1L = 0;
    double rev200ml = 0.0;
    double rev500ml = 0.0;
    double rev1L = 0.0;

    for (var order in filteredOrders) {
      for (var item in order.items) {
        final name = item.productName.toLowerCase();
        if (name.contains('200')) {
          count200ml += item.quantity;
          rev200ml += item.pricePerCrate * item.quantity;
        } else if (name.contains('500')) {
          count500ml += item.quantity;
          rev500ml += item.pricePerCrate * item.quantity;
        } else if (name.contains('1l') || name.contains('1 l') || name.contains('1ltr') || name.contains('1 ltr')) {
          count1L += item.quantity;
          rev1L += item.pricePerCrate * item.quantity;
        }
      }
    }

    final totalCrates = count200ml + count500ml + count1L;
    
    final avgCost200ml = count200ml > 0 ? (rev200ml / count200ml) : 0.0;
    final avgCost500ml = count500ml > 0 ? (rev500ml / count500ml) : 0.0;
    final avgCost1L = count1L > 0 ? (rev1L / count1L) : 0.0;

    // Helper to calculate percentages
    double pct200 = totalCrates > 0 ? (count200ml / totalCrates) : 0.0;
    double pct500 = totalCrates > 0 ? (count500ml / totalCrates) : 0.0;
    double pct1L = totalCrates > 0 ? (count1L / totalCrates) : 0.0;

    // Determine the highest-selling size
    String topSeller = 'None';
    int maxVal = [count200ml, count500ml, count1L].reduce((curr, next) => curr > next ? curr : next);
    if (totalCrates > 0 && maxVal > 0) {
      if (maxVal == count200ml) topSeller = '200ml';
      else if (maxVal == count500ml) topSeller = '500ml';
      else if (maxVal == count1L) topSeller = '1L';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFBFDFF)],
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Time filter dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crate Sales Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      'Sales volume by product size',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    items: <String>['All Time', 'This Month', 'This Year']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedPeriod = newValue!;
                      });
                    },
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1D4ED8)),
                    dropdownColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),

            // Total Crate Sales Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Crates Sold:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  Text(
                    '$totalCrates Crates',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (totalCrates == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text(
                    'No crate sales data for this period.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              // Pie Chart and Legend
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                if (count200ml > 0)
                                  PieChartSectionData(
                                    color: const Color(0xFF3B82F6),
                                    value: count200ml.toDouble(),
                                    title: '${(pct200 * 100).toStringAsFixed(1)}%',
                                    radius: 40,
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                if (count500ml > 0)
                                  PieChartSectionData(
                                    color: const Color(0xFF10B981),
                                    value: count500ml.toDouble(),
                                    title: '${(pct500 * 100).toStringAsFixed(1)}%',
                                    radius: 40,
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                if (count1L > 0)
                                  PieChartSectionData(
                                    color: const Color(0xFF8B5CF6),
                                    value: count1L.toDouble(),
                                    title: '${(pct1L * 100).toStringAsFixed(1)}%',
                                    radius: 40,
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                          // Center Text for Top Seller
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Top', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                topSeller,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem('200ml', count200ml, avgCost200ml, const Color(0xFF3B82F6)),
                          const SizedBox(height: 12),
                          _buildLegendItem('500ml', count500ml, avgCost500ml, const Color(0xFF10B981)),
                          const SizedBox(height: 12),
                          _buildLegendItem('1L', count1L, avgCost1L, const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String sizeName, int quantity, double avgCost, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sizeName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  Text(
                    '$quantity Crates',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (quantity > 0) ...[
                    const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      '₹${avgCost.toStringAsFixed(2)} avg',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
