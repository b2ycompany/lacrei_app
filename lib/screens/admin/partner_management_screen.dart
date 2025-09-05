import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_edit_partner_screen.dart';
import 'package:flutter/services.dart';

class PartnerManagementScreen extends StatefulWidget {
  const PartnerManagementScreen({super.key});

  @override
  State<PartnerManagementScreen> createState() => _PartnerManagementScreenState();
}

class _PartnerManagementScreenState extends State<PartnerManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  Future<void> _deletePartner(DocumentSnapshot partner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text("Tem certeza que deseja excluir este parceiro? Esta ação é irreversível e irá remover todos os dados associados, incluindo o perfil do usuário."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = _firestore.batch();
        final partnerId = partner.id;

        // 1. Deleta a imagem do Firebase Storage, se existir.
        final imageUrl = partner.get('imageUrl');
        if (imageUrl != null && imageUrl.isNotEmpty) {
          final imageRef = _storage.refFromURL(imageUrl);
          await imageRef.delete();
        }

        // 2. Deleta o documento do parceiro no Firestore
        batch.delete(_firestore.collection('partners').doc(partnerId));

        // 3. Deleta o documento do usuário associado na coleção 'users'
        final userQuery = await _firestore.collection('users').where('partnerId', isEqualTo: partnerId).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          batch.delete(userQuery.docs.first.reference);
        }

        // 4. Deleta o documento do usuário associado na coleção 'partner_users' (se for o caso)
        final partnerUserQuery = await _firestore.collection('partner_users').where('partnerId', isEqualTo: partnerId).limit(1).get();
        if (partnerUserQuery.docs.isNotEmpty) {
          batch.delete(partnerUserQuery.docs.first.reference);
        }

        // 5. Confirma todas as operações do batch
        await batch.commit();

        _showSnackBar("Parceiro excluído com sucesso!", isError: false);
      } catch (e) {
        _showSnackBar("Erro ao excluir parceiro: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de Parceiros"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditPartnerScreen()));
            },
            tooltip: 'Adicionar novo parceiro',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('partners').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar parceiros."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum parceiro cadastrado."));
          }

          final partners = snapshot.data!.docs;
          
          return ListView.builder(
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partner = partners[index];
              final data = partner.data() as Map<String, dynamic>;
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: data['imageUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            data['imageUrl'], 
                            width: 60, 
                            height: 60, 
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 40),
                          ),
                        )
                      : const Icon(Icons.business, size: 40, color: Colors.blueGrey),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditPartnerScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}