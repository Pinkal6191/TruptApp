import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../bloc/purchase_order_bloc.dart';
import '../bloc/purchase_order_event.dart';
import '../bloc/purchase_order_state.dart';
import '../services/purchase_order_pdf_service.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrdersListScreen extends StatelessWidget {
  const PurchaseOrdersListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PurchaseOrderBloc()..add(LoadPurchaseOrders()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Purchase Orders'),
          actions: [
            Builder(builder: (ctx) {
              return IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: BlocProvider.of<PurchaseOrderBloc>(ctx),
                        child: const CreatePurchaseOrderScreen(),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
        body: BlocBuilder<PurchaseOrderBloc, PurchaseOrderState>(
          builder: (context, state) {
            if (state is PurchaseOrderLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is PurchaseOrderError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is PurchaseOrdersLoaded) {
              final pos = state.purchaseOrders;
              if (pos.isEmpty) {
                return const Center(child: Text('No Purchase Orders Found.'));
              }
              return ListView.builder(
                itemCount: pos.length,
                itemBuilder: (context, index) {
                  final po = pos[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text('PO: ${po.poNumber} - ${po.vendorName}'),
                      subtitle: Text('Date: ${DateFormat('dd/MM/yyyy').format(po.createdAt)} | Items: ${po.items.length}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            onPressed: () async {
                              final pdfBytes = await PurchaseOrderPdfService.generatePdf(po);
                              Printing.layoutPdf(
                                onLayout: (format) async => pdfBytes,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
