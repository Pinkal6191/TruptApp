import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../../invoices/services/invoice_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  void _updateDeliveryStatus(String newStatus) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
    context.read<OrderBloc>().add(UpdateOrderStatus(
          orderId: widget.order.id,
          statusType: 'deliveryStatus',
          newStatus: newStatus,
          userId: userId,
        ));
    Navigator.pop(context);
  }

  void _recordPayment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double amount = widget.order.finalAmount - widget.order.paidAmount;
        String status = 'Paid';

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Remaining Balance: ₹${amount.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: amount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (₹)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    amount = double.parse(val);
                    if (amount >= (widget.order.finalAmount - widget.order.paidAmount)) {
                      status = 'Paid';
                    } else if (amount > 0) {
                      status = 'Partial';
                    } else {
                      status = 'Pending';
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final authState = context.read<AuthBloc>().state;
                    final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
                    context.read<OrderBloc>().add(UpdateOrderPayment(
                          orderId: widget.order.id,
                          paidAmount: widget.order.paidAmount + amount,
                          paymentStatus: status,
                          userId: userId,
                        ));
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm Payment'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state as Authenticated;
    final bool isAdmin = authState.user.role == 'admin';
    final bool isCreator = authState.user.uid == widget.order.createdBy;
    final bool canManage = isAdmin || isCreator;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Info Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.order.isSupplyOrder ? "Distributor" : widget.order.creatorRole == "admin" ? "Admin" : "Partner"}: ${widget.order.partnerName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(widget.order.createdAt)}', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (widget.order.invoiceNumber.isNotEmpty)
                      Text('Invoice No: ${widget.order.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    if (widget.order.shopName.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Shop/Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Expanded(child: Text(widget.order.shopName, textAlign: TextAlign.right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Expanded(child: Text(widget.order.customerMobile.isEmpty ? 'N/A' : widget.order.customerMobile, textAlign: TextAlign.right)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.order.customerAddress.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Expanded(child: Text(widget.order.customerAddress, textAlign: TextAlign.right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Expanded(child: Text(widget.order.deliveryStatus, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Expanded(child: Text(widget.order.paymentStatus, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Items List
            const Text('Items Ordered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: Colors.black12,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.order.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = widget.order.items[index];
                  return ListTile(
                    title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Qty: ${item.quantity} x ₹${item.pricePerCrate}'),
                    trailing: Text('₹${(item.quantity * item.pricePerCrate).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Financial Summary
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: Colors.black12,
              color: const Color(0xFF1E3A8A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Taxable Value', style: TextStyle(color: Colors.white70)),
                        Text('₹${widget.order.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('SGST (2.5%)', style: TextStyle(color: Colors.white70)),
                        Text('₹${(widget.order.gstAmount / 2).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CGST (2.5%)', style: TextStyle(color: Colors.white70)),
                        Text('₹${(widget.order.gstAmount / 2).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Colors.white30, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('₹${widget.order.finalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paid Amount', style: TextStyle(color: Colors.white70)),
                        Text('₹${widget.order.paidAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            
            // Generate Invoice Buttons
            const SizedBox(height: 16),
            if (isMobile) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Bill (With GST)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: const Color(0xFF1E3A8A),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                  ),
                  onPressed: () {
                    InvoiceService.generateAndShareInvoice(widget.order, withGst: true);
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Bill (No GST)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                  ),
                  onPressed: () {
                    InvoiceService.generateAndShareInvoice(widget.order, withGst: false);
                  },
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Bill (With GST)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                      ),
                      onPressed: () {
                        InvoiceService.generateAndShareInvoice(widget.order, withGst: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Bill (No GST)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                      ),
                      onPressed: () {
                        InvoiceService.generateAndShareInvoice(widget.order, withGst: false);
                      },
                    ),
                  ),
                ],
              ),
            ],
            
            // Order Actions
            if (canManage) ...[
              const SizedBox(height: 32),
              const Text('Order Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 12),
              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Mark Dispatched'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: widget.order.deliveryStatus != 'Dispatched' && widget.order.deliveryStatus != 'Delivered'
                        ? () => _updateDeliveryStatus('Dispatched')
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Delivered'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: widget.order.deliveryStatus != 'Delivered'
                        ? () => _updateDeliveryStatus('Delivered')
                        : null,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.local_shipping),
                        label: const Text('Mark Dispatched'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: widget.order.deliveryStatus != 'Dispatched' && widget.order.deliveryStatus != 'Delivered'
                            ? () => _updateDeliveryStatus('Dispatched')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark Delivered'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: widget.order.deliveryStatus != 'Delivered'
                            ? () => _updateDeliveryStatus('Delivered')
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (widget.order.paymentStatus == 'Paid') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.money_off),
                    label: const Text('Mark Unpaid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      final userId = isAdmin ? null : authState.user.uid;
                      context.read<OrderBloc>().add(UpdateOrderPayment(
                            orderId: widget.order.id,
                            paidAmount: 0.0,
                            paymentStatus: 'Pending',
                            userId: userId,
                          ));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order marked as Pending (Unpaid)')),
                      );
                    },
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payments),
                    label: const Text('Record Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _recordPayment,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete Order'),
                        content: const Text('Are you sure you want to delete this order? This will also reverse all stock changes associated with this order.'),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () {
                              final userId = isAdmin ? null : authState.user.uid;
                              context.read<OrderBloc>().add(DeleteOrder(order: widget.order, userId: userId));
                              Navigator.pop(dialogContext); // Close dialog
                              Navigator.pop(context); // Go back to order history screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Order deleted successfully!')),
                              );
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ]
          ],
        ),
      ),
    );
  }
}
