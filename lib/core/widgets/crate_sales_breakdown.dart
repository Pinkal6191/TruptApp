import 'package:flutter/material.dart';
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

            // Crate Progress list
            _buildProductRow('200ml', count200ml, pct200, avgCost200ml, const Color(0xFF3B82F6), topSeller == '200ml'),
            const SizedBox(height: 16),
            _buildProductRow('500ml', count500ml, pct500, avgCost500ml, const Color(0xFF10B981), topSeller == '500ml'),
            const SizedBox(height: 16),
            _buildProductRow('1L (1 Liter)', count1L, pct1L, avgCost1L, const Color(0xFF8B5CF6), topSeller == '1L'),

            if (totalCrates > 0 && topSeller != 'None') ...[
              const Divider(height: 40),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFF059669), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Color(0xFF065F46), fontSize: 13),
                          children: [
                            const TextSpan(text: 'Top Selling Size: '),
                            TextSpan(
                              text: topSeller,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: ' is your most popular packaging size in this period, contributing ',
                            ),
                            TextSpan(
                              text: '${((topSeller == '200ml' ? pct200 : topSeller == '500ml' ? pct500 : pct1L) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' of all orders!'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(String sizeName, int quantity, double percentage, double avgCost, Color color, bool isTopSeller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  sizeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (isTopSeller) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 10, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text(
                          'TOP SELLER',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                Text(
                  '$quantity Crates ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '(${((percentage) * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Avg: ₹${avgCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            return Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 10,
                  width: trackWidth * percentage,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
