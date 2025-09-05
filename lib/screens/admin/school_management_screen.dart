import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_edit_school_screen.dart';

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  Future<void> _deleteSchool(DocumentSnapshot schoolDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmar Exclusão"),
          content: Text("Tem certeza de que deseja excluir a instituição '${schoolDoc['schoolName']}'? Esta ação irá remover o perfil do usuário e desvincular todas as urnas."),
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
        final batch = _firestore.batch();
        final schoolId = schoolDoc.id;

        // 1. Deleta o documento da escola
        batch.delete(_firestore.collection('schools').doc(schoolId));
        
        // 2. Deleta o usuário da escola na coleção 'users'
        final userQuery = await _firestore.collection('users').where('schoolId', isEqualTo: schoolId).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          batch.delete(userQuery.docs.first.reference);
        }

        // 3. Desvincula as urnas que estavam atribuídas a esta escola
        final urnsQuery = await _firestore.collection('urns').where('assignedToId', isEqualTo: schoolId).get();
        for (var doc in urnsQuery.docs) {
          batch.update(doc.reference, {
            'assignedToId': null,
            'assignedToName': null,
            'status': 'Vazia',
          });
        }

        await batch.commit();
        _showSnackBar("Instituição de ensino e dados associados excluídos com sucesso!", isError: false);
      } catch (e) {
        _showSnackBar("Erro ao excluir instituição de ensino: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de Instituições de Ensino"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditSchoolScreen()));
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar dados: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma instituição de ensino cadastrada."));
          }
          
          final schoolDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: schoolDocs.length,
            itemBuilder: (context, index) {
              final schoolDoc = schoolDocs[index];
              final data = schoolDoc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(data['schoolName'] ?? 'Nome não informado'),
                  subtitle: Text(data['city'] ?? 'Cidade não informada'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteSchool(schoolDoc),
                    tooltip: "Excluir",
                  ),
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