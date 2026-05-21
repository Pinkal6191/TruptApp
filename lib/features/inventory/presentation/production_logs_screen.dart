import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/models/production_log_model.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../products/bloc/product_state.dart';
import '../repository/production_repository.dart';

class ProductionLogsScreen extends StatefulWidget {
  const ProductionLogsScreen({super.key});

  @override
  State<ProductionLogsScreen> createState() => _ProductionLogsScreenState();
}

class _ProductionLogsScreenState extends State<ProductionLogsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductionRepository _productionRepository = ProductionRepository();
  
  // Log Form State
  ProductModel? _selectedProduct;
  final _cratesController = TextEditingController();
  final _notesController = TextEditingController();
  int _cratesProduced = 0;
  DateTime _selectedDateTime = DateTime.now();

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E3A8A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1E3A8A),
                onPrimary: Colors.white,
                onSurface: Color(0xFF1E3A8A),
              ),
            ),
            child: child!,
          );
        },
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<ProductBloc>().add(LoadProducts());

    _cratesController.addListener(() {
      setState(() {
        _cratesProduced = int.tryParse(_cratesController.text) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cratesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _selectedProduct = null;
      _cratesController.clear();
      _notesController.clear();
      _cratesProduced = 0;
      _selectedDateTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Production Center', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A8A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E3A8A),
          tabs: const [
            Tab(icon: Icon(Icons.playlist_add), text: 'Log Production'),
            Tab(icon: Icon(Icons.history), text: 'Production History'),
          ],
        ),
      ),
      body: StreamBuilder<List<RawMaterialModel>>(
        stream: _productionRepository.watchRawMaterials(),
        builder: (context, materialSnapshot) {
          final rawMaterials = materialSnapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLogProductionTab(rawMaterials),
              _buildProductionHistoryTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogProductionTab(List<RawMaterialModel> rawMaterials) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ProductError) {
          return Center(child: Text('Error loading products: ${state.message}', style: const TextStyle(color: Colors.red)));
        }

        final List<ProductModel> products = (state is ProductLoaded) ? state.products : [];
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber.shade600),
                const SizedBox(height: 12),
                const Text('No products available. Create products first.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        // Active Recipe requirements
        final List<Map<String, dynamic>> recipeRequirements = [];
        bool hasInsufficientStock = false;

        if (_selectedProduct != null && _cratesProduced > 0) {
          for (var item in _selectedProduct!.recipe) {
            final String matId = item['materialId'] ?? '';
            final double qtyPerCrate = (item['quantityPerCrate'] ?? 0.0).toDouble();
            final double requiredQty = qtyPerCrate * _cratesProduced;

            final rawMat = rawMaterials.firstWhere(
              (m) => m.id == matId,
              orElse: () => RawMaterialModel(id: matId, name: 'Unknown Material', unit: 'pcs', stockCount: 0.0, minReorderLevel: 0.0),
            );

            final isInsufficient = rawMat.stockCount < requiredQty;
            if (isInsufficient) {
              hasInsufficientStock = true;
            }

            recipeRequirements.add({
              'materialId': matId,
              'name': rawMat.name,
              'unit': rawMat.unit,
              'required': requiredQty,
              'available': rawMat.stockCount,
              'isInsufficient': isInsufficient,
            });
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product selection card
              Card(
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
                      const Text(
                        'Select Product & Enter Quantity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ProductModel>(
                        value: _selectedProduct,
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_drink),
                        ),
                        items: products.map((ProductModel p) {
                          return DropdownMenuItem(value: p, child: Text(p.name));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProduct = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cratesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Crates Produced',
                          hintText: 'e.g. 50',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.grid_view),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDateTime(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Production Date & Time',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_month),
                                ),
                                child: Text(
                                  DateFormat('dd-MM-yyyy  hh:mm a').format(_selectedDateTime),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF1E3A8A),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedDateTime = DateTime.now();
                              });
                            },
                            icon: const Icon(Icons.autorenew, size: 18),
                            label: const Text('Auto / Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Optional Notes / Shift Details',
                          hintText: 'e.g. Morning Shift, Batch A',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recipe configuration reminder if product is selected but has empty recipe
              if (_selectedProduct != null && _selectedProduct!.recipe.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Color(0xFFD97706)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This product has no recipe set up yet! Please configure its recipe in the Product Management Screen to automatically deduct raw materials.',
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // Dynamic raw materials consumption calculation list
              if (recipeRequirements.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    'Recipe Materials Consumption Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                ),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recipeRequirements.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final req = recipeRequirements[index];
                            final isIns = req['isInsufficient'] as bool;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isIns 
                                        ? const Color(0xFFFEE2E2) 
                                        : const Color(0xFFE0F2FE),
                                    child: Icon(
                                      isIns ? Icons.error_outline : Icons.check_circle_outline,
                                      size: 18,
                                      color: isIns ? Colors.red : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req['name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Available: ${req['available']} ${req['unit']}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '-${req['required'].toStringAsFixed(2)} ${req['unit']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isIns ? Colors.red : const Color(0xFFEF4444),
                                        ),
                                      ),
                                      if (isIns)
                                        const Text(
                                          'Insufficient Stock',
                                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                        if (hasInsufficientStock) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.red, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Warning: Insufficient raw material stocks. Running this production will drive raw material stocks negative.',
                                    style: TextStyle(color: Color(0xFF9F1239), fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Log Production Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: (_selectedProduct == null || _cratesProduced <= 0) 
                      ? null 
                      : () async {
                          final List<Map<String, dynamic>> consumed = [];
                          for (var item in _selectedProduct!.recipe) {
                            final String matId = item['materialId'] ?? '';
                            final double qtyPerCrate = (item['quantityPerCrate'] ?? 0.0).toDouble();
                            final double totalQty = qtyPerCrate * _cratesProduced;

                            final rawMat = rawMaterials.firstWhere(
                              (m) => m.id == matId,
                              orElse: () => RawMaterialModel(id: matId, name: 'Unknown', unit: 'pcs', stockCount: 0.0, minReorderLevel: 0.0),
                            );

                            consumed.add({
                              'materialId': matId,
                              'name': rawMat.name,
                              'quantity': totalQty,
                              'unit': rawMat.unit,
                            });
                          }

                          final productionLog = ProductionLogModel(
                            id: '',
                            date: _selectedDateTime,
                            productId: _selectedProduct!.id,
                            productName: _selectedProduct!.name,
                            cratesProduced: _cratesProduced,
                            notes: _notesController.text.trim(),
                            consumedMaterials: consumed,
                          );

                          try {
                            // Show loading indicator
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );

                            await _productionRepository.logProductionRun(productionLog);

                            if (context.mounted) {
                              Navigator.pop(context); // Pop loading dialog
                              _resetForm();
                              _tabController.animateTo(1); // Swaps to history tab
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Daily production logged successfully! finished stock updated.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // Pop loading dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.save_as),
                  label: const Text('Log Daily Production', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductionHistoryTab() {
    return StreamBuilder<List<ProductionLogModel>>(
      stream: _productionRepository.watchProductionLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No production logs recorded.',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Completed daily production runs will show\nhere in chronological order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final formattedDate = DateFormat('EEEE, MMM dd, yyyy • hh:mm a').format(log.date);

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  child: const Icon(Icons.precision_manufacturing, color: Color(0xFF1E3A8A)),
                ),
                title: Text(
                  log.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 16),
                ),
                subtitle: Text('$formattedDate\nQuantity: ${log.cratesProduced} crates'),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                children: [
                  const Divider(),
                  if (log.notes.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Notes: ${log.notes}',
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Materials Consumed:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (log.consumedMaterials.isEmpty)
                    const Text('No ingredients/materials consumed (Recipe was not set).', style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: log.consumedMaterials.length,
                      itemBuilder: (context, itemIdx) {
                        final material = log.consumedMaterials[itemIdx];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_circle_down, size: 16, color: Color(0xFFEF4444)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      material['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${material['quantity'].toStringAsFixed(1)} ${material['unit']}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
