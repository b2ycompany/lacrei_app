// lib/screens/admin/partner_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_edit_partner_screen.dart'; // Importa a nova tela

class PartnerManagementScreen extends StatefulWidget {
  const PartnerManagementScreen({super.key});

  @override
  State<PartnerManagementScreen> createState() => _PartnerManagementScreenState();
}

class _PartnerManagementScreenState extends State<PartnerManagementScreen> {

  // MELHORIA: Função para deletar um parceiro, com diálogo de confirmação.
  Future<void> _deletePartner(DocumentSnapshot partner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text("Tem certeza que deseja excluir este parceiro? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Deleta a imagem do Firebase Storage primeiro
        final imageUrl = partner['imageUrl'];
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        }
        // Deleta o documento do Firestore
        await partner.reference.delete();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parceiro excluído com sucesso!"), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao excluir parceiro: ${e.toString()}"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Parceiros")),
      // BOTÃO FLUTUANTE para adicionar um novo parceiro, navegando para a nova tela.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditPartnerScreen()));
        },
        tooltip: 'Adicionar Parceiro',
        child: const Icon(Icons.add),
      ),
      // NOVO: Usa um StreamBuilder para listar os parceiros em tempo real.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('partners').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Nenhum parceiro cadastrado.\nClique no botão '+' para começar.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final partners = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Espaço para o botão flutuante
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partner = partners[index];
              final data = partner.data() as Map<String, dynamic>;
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: data['imageUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.business, size: 40),
                  title: Text(data['name'] ?? 'Nome não disponível', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? 'Sem descrição', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deletePartner(partner),
                  ),
                  onTap: () {
                    // Navega para a tela de edição, passando os dados do parceiro.
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditPartnerScreen(partner: partner)));
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