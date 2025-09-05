import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_salesperson_screen.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  Future<void> _deleteSalesperson(DocumentSnapshot salespersonDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text("Tem certeza que deseja excluir este vendedor? Esta ação é irreversível e irá remover o perfil do vendedor e o usuário associado."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = _firestore.batch();
        
        // 1. Deleta o documento do vendedor na coleção 'salespeople'
        batch.delete(_firestore.collection('salespeople').doc(salespersonDoc.id));

        // 2. Busca e deleta o usuário associado na coleção 'users'
        final userQuery = await _firestore.collection('users').where('salespersonId', isEqualTo: salespersonDoc.id).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          batch.delete(userQuery.docs.first.reference);
        }

        await batch.commit();
        _showSnackBar("Vendedor e dados associados excluídos com sucesso!", isError: false);
      } catch (e) {
        _showSnackBar("Erro ao excluir vendedor: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de Vendedores"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditSalespersonScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('salespeople').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar dados: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum vendedor cadastrado."));
          }

          final salespeopleDocs = snapshot.data!.docs;
          final totalSalespeople = salespeopleDocs.length;
          final totalSales = salespeopleDocs.fold<num>(0, (sum, doc) => sum + (doc.data() as Map<String, dynamic>)['salesCount'] ?? 0);

          return Column(
            children: [
              // Dashboard de métricas
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDashboardMetric("Total de Vendedores", totalSalespeople.toString()),
                    _buildDashboardMetric("Total de Vendas", totalSales.toString()),
                  ],
                ),
              ),
              const Divider(),
              // Lista de vendedores
              Expanded(
                child: ListView.builder(
                  itemCount: salespeopleDocs.length,
                  itemBuilder: (context, index) {
                    final salespersonDoc = salespeopleDocs[index];
                    final data = salespersonDoc.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(data['name'] ?? 'Nome não disponível', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "Comissão: ${data['commission']?.toString() ?? 'N/A'}% | Vendas: ${data['salesCount'] ?? 0} | Total: R\$ ${(data['totalSalesValue'] as num? ?? 0).toStringAsFixed(2)}"
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteSalesperson(salespersonDoc),
                        ),
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => EditSalespersonScreen(salespersonId: salespersonDoc.id)
                          )
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}