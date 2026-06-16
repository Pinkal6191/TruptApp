import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';
import '../../invoices/services/invoice_service.dart';
import 'create_order_screen.dart';
import '../../../core/utils/route_tracker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderModel _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    RouteTracker.saveRoute('order_details', data: {'orderId': _currentOrder.id});
  }

  void _updateDeliveryStatus(String newStatus) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
    final userName = authState is Authenticated && authState.user.role != 'admin' ? authState.user.name : null;
    context.read<OrderBloc>().add(UpdateOrderStatus(
          orderId: _currentOrder.id,
          statusType: 'deliveryStatus',
          newStatus: newStatus,
          userId: userId,
          userName: userName,
        ));
    Navigator.pop(context);
  }

  void _recordPayment() {
    final double totalBill = _currentOrder.finalAmount;
    final double previouslyPaid = _currentOrder.paidAmount;
    final double currentPending = totalBill - previouslyPaid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double amountPaidNow = currentPending;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double totalPaidAfter = previouslyPaid + amountPaidNow;
            final double netRemaining = totalBill - totalPaidAfter; // negative = overpaid
            final bool isOverpaid = netRemaining < 0;
            final double returnToCustomer = isOverpaid ? netRemaining.abs() : 0.0;
            final double stillPending = isOverpaid ? 0.0 : netRemaining;

            String calculatedStatus = 'Paid';
            if (totalPaidAfter >= totalBill) {
              calculatedStatus = 'Paid';
            } else if (totalPaidAfter > 0) {
              calculatedStatus = 'Partial';
            } else {
              calculatedStatus = 'Pending';
            }

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
                  const Text(
                    'Record Payment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 16),
                  // Bill summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Bill:', style: TextStyle(color: Colors.grey)),
                            Text('₹${totalBill.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Previously Paid:', style: TextStyle(color: Colors.grey)),
                            Text('₹${previouslyPaid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Pending:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('₹${currentPending.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: currentPending.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received from Customer (₹)',
                      border: OutlineInputBorder(),
                      helperText: 'Enter the exact cash received (can be more than pending)',
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        amountPaidNow = double.tryParse(val.trim()) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Result card — changes color based on overpaid / partial / paid
                  if (isOverpaid) ...[
                    // OVERPAYMENT — show Return to Customer
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Bill Fully Settled ✓', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  const SizedBox(height: 2),
                                  const Text('Return to Customer:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(
                                '₹${returnToCustomer.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Customer gave:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text('₹${(previouslyPaid + amountPaidNow).toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Normal — show remaining pending
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: stillPending > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: stillPending > 0 ? Colors.orange.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Remaining after payment:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(
                                '₹${stillPending.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: stillPending > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          Chip(
                            label: Text(calculatedStatus),
                            backgroundColor: stillPending > 0 ? Colors.orange.shade100 : Colors.green.shade100,
                            labelStyle: TextStyle(
                              color: stillPending > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isOverpaid ? Colors.purple.shade600 : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (amountPaidNow < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment amount cannot be negative')),
                          );
                          return;
                        }
                        final authState = context.read<AuthBloc>().state;
                        final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
                        final userName = authState is Authenticated && authState.user.role != 'admin' ? authState.user.name : null;

                        // Store the actual total received (including overpayment) — no cap
                        final double totalReceivedAmount = previouslyPaid + amountPaidNow;

                        context.read<OrderBloc>().add(UpdateOrderPayment(
                              orderId: _currentOrder.id,
                              paidAmount: totalReceivedAmount,
                              paymentStatus: calculatedStatus,
                              userId: userId,
                              userName: userName,
                            ));
                        Navigator.pop(context);
                        if (isOverpaid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment recorded. Return ₹${returnToCustomer.toStringAsFixed(2)} to customer.'),
                              backgroundColor: Colors.purple.shade700,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      child: Text(
                        isOverpaid
                            ? 'Confirm & Return ₹${returnToCustomer.toStringAsFixed(2)}'
                            : 'Confirm Payment',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state as Authenticated;
    final bool isAdmin = authState.user.role == 'admin';
    final bool isCreator = authState.user.uid == _currentOrder.createdBy;
    final bool isReferredPartner = authState.user.role == 'partner' &&
        (_currentOrder.referredPartnerId == authState.user.uid ||
         _currentOrder.orderReference.toLowerCase().trim() == authState.user.name.toLowerCase().trim());
    final bool isTargetDistributor = authState.user.role == 'distributor' &&
        (_currentOrder.targetUserId == authState.user.uid);
    final bool canManage = isAdmin || isCreator || isReferredPartner || isTargetDistributor;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return BlocListener<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrdersLoaded) {
          try {
            final updated = state.orders.firstWhere((o) => o.id == widget.order.id);
            setState(() {
              _currentOrder = updated;
            });
            RouteTracker.saveRoute('order_details', data: {'orderId': updated.id});
          } catch (_) {}
        }
      },
      child: Scaffold(
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
                        '${_currentOrder.isSupplyOrder ? "Distributor" : (_currentOrder.creatorRole == "admin" && _currentOrder.referredPartnerId.isEmpty) ? "Admin" : "Partner"}: ${_currentOrder.partnerName}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_currentOrder.referredPartnerId.isNotEmpty && _currentOrder.orderReference.isNotEmpty && _currentOrder.orderReference != 'Direct (Online / Call)') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.handshake_outlined, size: 14, color: Colors.indigo.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Referred by: ${_currentOrder.orderReference}',
                              style: TextStyle(color: Colors.indigo.shade600, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(_currentOrder.createdAt)}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      if (_currentOrder.invoiceNumber.isNotEmpty)
                        Text('Invoice No: ${_currentOrder.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      if (_currentOrder.shopName.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shop/Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Expanded(child: Text(_currentOrder.shopName, textAlign: TextAlign.right)),
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
                          Expanded(child: Text(_currentOrder.customerMobile.isEmpty ? 'N/A' : _currentOrder.customerMobile, textAlign: TextAlign.right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_currentOrder.customerAddress.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Expanded(child: Text(_currentOrder.customerAddress, textAlign: TextAlign.right)),
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
                          Expanded(child: Text(_currentOrder.deliveryStatus, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Expanded(child: Text(_currentOrder.paymentStatus, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                      if (_currentOrder.additionalNote.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Note', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Expanded(child: Text(_currentOrder.additionalNote, textAlign: TextAlign.right, style: const TextStyle(fontStyle: FontStyle.italic))),
                          ],
                        ),
                      ],
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
                  itemCount: _currentOrder.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _currentOrder.items[index];
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
                          Text('₹${_currentOrder.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('SGST (2.5%)', style: TextStyle(color: Colors.white70)),
                          Text('₹${(_currentOrder.gstAmount / 2).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CGST (2.5%)', style: TextStyle(color: Colors.white70)),
                          Text('₹${(_currentOrder.gstAmount / 2).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const Divider(color: Colors.white30, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('₹${_currentOrder.finalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Paid Amount', style: TextStyle(color: Colors.white70)),
                          Text('₹${_currentOrder.paidAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _currentOrder.remainingAmount < 0 ? 'Return to Customer' : 'Remaining Balance',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            _currentOrder.remainingAmount < 0
                                ? '₹${_currentOrder.remainingAmount.abs().toStringAsFixed(2)}'
                                : '₹${_currentOrder.remainingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _currentOrder.remainingAmount < 0
                                  ? Colors.purpleAccent
                                  : _currentOrder.remainingAmount > 0
                                      ? Colors.orangeAccent
                                      : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                      InvoiceService.generateAndShareInvoice(_currentOrder, withGst: true);
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
                      InvoiceService.generateAndShareInvoice(_currentOrder, withGst: false);
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
                          InvoiceService.generateAndShareInvoice(_currentOrder, withGst: true);
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
                          InvoiceService.generateAndShareInvoice(_currentOrder, withGst: false);
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
                
                if (_currentOrder.deliveryStatus != 'Delivered' && _currentOrder.paymentStatus != 'Paid') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Edit Order Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateOrderScreen(
                              isRetailOrder: !_currentOrder.isSupplyOrder,
                              existingOrder: _currentOrder,
                            ),
                          ),
                        ).then((_) {
                          RouteTracker.saveRoute('order_details', data: {'orderId': _currentOrder.id});
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                if (_currentOrder.deliveryStatus != 'Delivered') ...[
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
                        onPressed: _currentOrder.deliveryStatus != 'Dispatched' && _currentOrder.deliveryStatus != 'Delivered'
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
                        onPressed: _currentOrder.deliveryStatus != 'Delivered'
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
                            onPressed: _currentOrder.deliveryStatus != 'Dispatched' && _currentOrder.deliveryStatus != 'Delivered'
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
                            onPressed: _currentOrder.deliveryStatus != 'Delivered'
                                ? () => _updateDeliveryStatus('Delivered')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                
                if (!(_currentOrder.deliveryStatus == 'Delivered' && _currentOrder.paymentStatus == 'Paid')) ...[
                  if (_currentOrder.paymentStatus == 'Paid') ...[
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
                          final userName = isAdmin ? null : authState.user.name;
                          context.read<OrderBloc>().add(UpdateOrderPayment(
                                orderId: _currentOrder.id,
                                paidAmount: 0.0,
                                paymentStatus: 'Pending',
                                userId: userId,
                                userName: userName,
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
                ],

                if (_currentOrder.deliveryStatus != 'Delivered' && _currentOrder.paymentStatus != 'Paid') ...[
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
                                  final userName = isAdmin ? null : authState.user.name;
                                  context.read<OrderBloc>().add(DeleteOrder(
                                        order: _currentOrder,
                                        userId: userId,
                                        userName: userName,
                                      ));
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
                ],
                const SizedBox(height: 32),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsRestoreLoader extends StatefulWidget {
  final String orderId;
  const OrderDetailsRestoreLoader({super.key, required this.orderId});

  @override
  State<OrderDetailsRestoreLoader> createState() => _OrderDetailsRestoreLoaderState();
}

class _OrderDetailsRestoreLoaderState extends State<OrderDetailsRestoreLoader> {
  OrderModel? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      if (doc.exists) {
        setState(() {
          _order = OrderModel.fromFirestore(doc);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Order not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Failed to load order')),
      );
    }
    return OrderDetailsScreen(order: _order!);
  }
}
