// lib/screens/admin/company_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_company_screen.dart'; // Tela que criaremos no próximo passo

class CompanyManagementScreen extends StatelessWidget {
  const CompanyManagementScreen({super.key});

  // Função para apagar uma empresa com diálogo de confirmação
  Future<void> _deleteCompany(BuildContext context, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza de que deseja apagar esta empresa? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('companies').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa apagada com sucesso.'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao apagar empresa: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Empresas'),
      ),
      // StreamBuilder ouve as mudanças na coleção 'companies' em tempo real
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('companies').orderBy('companyName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Ocorreu um erro ao carregar as empresas.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma empresa cadastrada.\nClique no botão "+" para adicionar a primeira.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final companies = snapshot.data!.docs;

          return ListView.builder(
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final companyDoc = companies[index];
              final companyData = companyDoc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  title: Text(companyData['companyName'] ?? 'Nome não informado'),
                  subtitle: Text('CNPJ: ${companyData['cnpj'] ?? 'N/A'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteCompany(context, companyDoc.id),
                  ),
                  onTap: () {
                    // Navega para a tela de edição, passando o ID do documento
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditCompanyScreen(companyId: companyDoc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      // Botão para adicionar uma nova empresa
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega para a tela de edição sem ID, indicando a criação de um novo item
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditCompanyScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Empresa',
      ),
    );
  }
}