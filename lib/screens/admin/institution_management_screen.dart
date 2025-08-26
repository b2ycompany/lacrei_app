// lib/screens/admin/institution_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_institution_screen.dart';

class InstitutionManagementScreen extends StatelessWidget {
  const InstitutionManagementScreen({super.key});

  Future<void> _deleteInstitution(BuildContext context, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza de que deseja apagar esta instituição? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apagar')),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('institutions').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Instituição apagada com sucesso.'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao apagar instituição: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Instituições'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('institutions').orderBy('institutionName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Ocorreu um erro ao carregar as instituições.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma instituição cadastrada.'));
          }

          final institutions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: institutions.length,
            itemBuilder: (context, index) {
              final institutionDoc = institutions[index];
              final institutionData = institutionDoc.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(institutionData['institutionName'] ?? 'Nome não informado'),
                subtitle: Text('Telefone: ${institutionData['institutionPhone'] ?? 'N/A'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteInstitution(context, institutionDoc.id),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditInstitutionScreen(institutionId: institutionDoc.id),
                    ),
                  );
                },
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
              builder: (context) => const EditInstitutionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}