// lib/screens/admin/school_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_edit_school_screen.dart'; // Importa a tela de edição

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {

  // Função para excluir uma escola, com diálogo de confirmação.
  Future<void> _deleteSchool(BuildContext context, DocumentSnapshot schoolDoc) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmar Exclusão"),
          content: Text("Tem a certeza de que deseja excluir a escola '${schoolDoc['schoolName']}'? Esta ação não pode ser desfeita."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("Excluir", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await schoolDoc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Escola excluída com sucesso!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao excluir escola: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciar Escolas"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega para a tela de ADIÇÃO
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditSchoolScreen()));
        },
        child: const Icon(Icons.add),
        tooltip: "Adicionar Escola",
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schools').orderBy('schoolName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar escolas: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma escola cadastrada."));
          }
          
          final schoolDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: schoolDocs.length,
            itemBuilder: (context, index) {
              final schoolDoc = schoolDocs[index];
              final data = schoolDoc.data() as Map<String, dynamic>;
              
              final hasAddress = data.containsKey('address') && data['address'] != null && (data['address'] as String).isNotEmpty;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(data['schoolName'] ?? 'Escola sem nome'),
                  subtitle: Text(data['city'] ?? 'Cidade não informada'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: hasAddress ? "Endereço cadastrado" : "Endereço pendente",
                        child: Icon(
                          hasAddress ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: hasAddress ? Colors.green : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteSchool(context, schoolDoc),
                        tooltip: "Excluir Escola",
                      ),
                    ],
                  ),
                  // CORREÇÃO APLICADA AQUI: Ao clicar, abre a tela de EDIÇÃO
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditSchoolScreen(school: schoolDoc)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}