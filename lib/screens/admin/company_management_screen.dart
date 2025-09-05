import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_company_screen.dart'; 

class CompanyManagementScreen extends StatelessWidget {
  const CompanyManagementScreen({super.key});

  void _showSnackBar(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
    );
  }

  Future<void> _deleteCompany(BuildContext context, String companyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza de que deseja apagar esta empresa? Esta ação é irreversível e irá remover o perfil do usuário associado e desvincular todas as urnas.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // 1. Deleta o documento da empresa
        batch.delete(FirebaseFirestore.instance.collection('companies').doc(companyId));
        
        // 2. Deleta o usuário da empresa na coleção 'users'
        final userQuery = await FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: companyId).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          batch.delete(userQuery.docs.first.reference);
        }

        // 3. Desvincula as urnas que estavam atribuídas a esta empresa
        final urnsQuery = await FirebaseFirestore.instance.collection('urns').where('assignedToId', isEqualTo: companyId).get();
        for (var doc in urnsQuery.docs) {
          batch.update(doc.reference, {'assignedToId': null, 'assignedToName': null, 'status': 'Vazia'});
        }

        await batch.commit();

        _showSnackBar(context, 'Empresa e dados associados apagados com sucesso.', isError: false);
      } catch (e) {
        _showSnackBar(context, 'Erro ao apagar empresa: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de Empresas"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('companies').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar empresas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma empresa cadastrada."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final companyDoc = snapshot.data!.docs[index];
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditCompanyScreen(),
            ),
          );
        },
        tooltip: 'Adicionar Empresa',
        child: const Icon(Icons.add),
      ),
    );
  }
}