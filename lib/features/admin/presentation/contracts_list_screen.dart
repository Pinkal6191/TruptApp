import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../contracts/bloc/contract_bloc.dart';
import '../../contracts/bloc/contract_event.dart';
import '../../contracts/bloc/contract_state.dart';
import '../../../core/models/contract_model.dart';
import '../../../core/utils/route_tracker.dart';
import 'contract_generator_screen.dart';
import 'pdf_contract_service.dart';

class ContractsListScreen extends StatefulWidget {
  const ContractsListScreen({super.key});

  @override
  State<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends State<ContractsListScreen> {
  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('contracts_list');
    context.read<ContractBloc>().add(LoadContracts());
  }

  void _navigateToEdit(ContractModel contract) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractGeneratorScreen(contractToEdit: contract),
      ),
    );
  }

  void _deleteContract(ContractModel contract) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contract'),
        content: Text('Are you sure you want to delete the contract for ${contract.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ContractBloc>().add(DeleteContract(contract.id));
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(ContractModel contract) async {
    try {
      await PdfContractService.generateAndDownloadContract(
        customerName: contract.customerName,
        customerAddress: contract.customerAddress,
        customerContact: contract.customerContact,
        oneTimeFees: contract.oneTimeFees,
        price200ml: contract.price200ml,
        moq200ml: contract.moq200ml,
        price500ml: contract.price500ml,
        moq500ml: contract.moq500ml,
        price1L: contract.price1L,
        moq1L: contract.moq1L,
        duration: contract.duration,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract PDF generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Saved Contracts'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: BlocConsumer<ContractBloc, ContractState>(
        listener: (context, state) {
          if (state is ContractOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ContractError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is ContractLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ContractsLoaded) {
            if (state.contracts.isEmpty) {
              return const Center(child: Text('No saved contracts found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.contracts.length,
              itemBuilder: (context, index) {
                final contract = state.contracts[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                contract.customerName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy').format(contract.createdAt),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Duration: ${contract.duration}'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                              onPressed: () => _downloadPdf(contract),
                              tooltip: 'Download PDF',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _navigateToEdit(contract),
                              tooltip: 'Edit Contract',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteContract(contract),
                              tooltip: 'Delete Contract',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const Center(child: Text('Loading contracts...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContractGeneratorScreen()),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
