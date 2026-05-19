import 'package:flutter/material.dart';
import '../models/order_model.dart';

class RegularCustomersGraph extends StatelessWidget {
  final List<OrderModel> orders;

  const RegularCustomersGraph({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // 1. Group orders by customer name / mobile number
    final Map<String, _CustomerStats> customerStatsMap = {};

    for (var order in orders) {
      if (order.customerName.isEmpty) continue;
      final key = '${order.customerName}_${order.customerMobile}';
      
      if (customerStatsMap.containsKey(key)) {
        final current = customerStatsMap[key]!;
        customerStatsMap[key] = _CustomerStats(
          name: order.customerName,
          mobile: order.customerMobile,
          orderCount: current.orderCount + 1,
          totalSpend: current.totalSpend + order.finalAmount,
        );
      } else {
        customerStatsMap[key] = _CustomerStats(
          name: order.customerName,
          mobile: order.customerMobile,
          orderCount: 1,
          totalSpend: order.finalAmount,
        );
      }
    }

    // 2. Convert to list and sort by order frequency descending
    final List<_CustomerStats> sortedList = customerStatsMap.values.toList()
      ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

    // Take top 5 regular customers
    final List<_CustomerStats> top5 = sortedList.take(5).toList();

    if (top5.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No customer order history available yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final int maxOrders = top5.first.orderCount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                const Text(
                  'Top Regular Customers (Loyalty)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
            const Text(
              'Ranking of repeat customers by order frequency',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: top5.length,
              itemBuilder: (context, index) {
                final customer = top5[index];
                final double percent = maxOrders > 0 ? (customer.orderCount / maxOrders) : 0.0;
                
                // Color mapping for ranks
                Color barColor = const Color(0xFF1E3A8A); // Gold/Dark Blue
                if (index == 0) barColor = const Color(0xFFD97706); // Amber
                if (index == 1) barColor = const Color(0xFF2563EB); // Royal Blue
                if (index == 2) barColor = const Color(0xFF10B981); // Emerald Green

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: barColor.withOpacity(0.1),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold, 
                                      color: barColor
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    customer.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${customer.orderCount} Orders  (₹${customer.totalSpend.toStringAsFixed(0)})',
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.grey.shade700
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerStats {
  final String name;
  final String mobile;
  final int orderCount;
  final double totalSpend;

  _CustomerStats({
    required this.name,
    required this.mobile,
    required this.orderCount,
    required this.totalSpend,
  });
}
