// lib/screens/admin/sales_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'salesperson_registration_screen.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {

  Future<void> _deleteSalesperson(DocumentSnapshot salespersonDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text("Tem certeza que deseja excluir o vendedor '${salespersonDoc['name']}'? Esta ação irá apagar o perfil, mas não o utilizador de login (isso deve ser feito no Firebase Authentication)."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(FirebaseFirestore.instance.collection('salespeople').doc(salespersonDoc.id));
        batch.delete(FirebaseFirestore.instance.collection('users').doc(salespersonDoc.id));
        await batch.commit();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perfil do vendedor excluído com sucesso!"), backgroundColor: Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao excluir: ${e.toString()}"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestão da Equipe de Vendas")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalespersonRegistrationScreen())),
        tooltip: "Adicionar Vendedor",
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('salespeople').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar vendedores."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum vendedor cadastrado."));
          }
          final salespeople = snapshot.data!.docs;
          
          // Lógica da Dashboard: Calcular os totais
          int totalSales = 0;
          double totalValue = 0.0;
          for (var doc in salespeople) {
            final data = doc.data() as Map<String, dynamic>;
            totalSales += (data['salesCount'] as int? ?? 0);
            totalValue += (data['totalSalesValue'] as num? ?? 0).toDouble();
          }

          return Column(
            children: [
              // Dashboard com os totais
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDashboardMetric("Vendedores", salespeople.length.toString()),
                    _buildDashboardMetric("Vendas Totais", totalSales.toString()),
                    _buildDashboardMetric("Valor Total", "R\$ ${totalValue.toStringAsFixed(2)}"),
                  ],
                ),
              ),
              const Divider(),
              // Lista de vendedores
              Expanded(
                child: ListView.builder(
                  itemCount: salespeople.length,
                  itemBuilder: (context, index) {
                    final salespersonDoc = salespeople[index];
                    final data = salespersonDoc.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(data['name'] ?? 'Nome não disponível', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Vendas: ${data['salesCount'] ?? 0} | Total: R\$ ${(data['totalSalesValue'] as num? ?? 0).toStringAsFixed(2)}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteSalesperson(salespersonDoc),
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SalespersonRegistrationScreen(salesperson: salespersonDoc))),
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