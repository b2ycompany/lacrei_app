// lib/screens/admin/access_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AccessApprovalScreen extends StatefulWidget {
  const AccessApprovalScreen({super.key});

  @override
  State<AccessApprovalScreen> createState() => _AccessApprovalScreenState();
}

class _AccessApprovalScreenState extends State<AccessApprovalScreen> {
  
  Future<void> _updateUserStatus(String userId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'accountStatus': status,
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Usuário ${status == 'approved' ? 'aprovado' : 'negado'} com sucesso."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao atualizar status: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aprovação de Acessos"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('accountStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Ocorreu um erro ao carregar as solicitações."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Nenhuma solicitação de acesso pendente.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final pendingUsers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pendingUsers.length,
            itemBuilder: (context, index) {
              final userDoc = pendingUsers[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              
              final Timestamp timestamp = userData['createdAt'] ?? Timestamp.now();
              final requestDate = DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userData['name'] ?? 'Nome não informado', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("E-mail: ${userData['email'] ?? 'N/A'}"),
                      Text("Perfil Solicitado: ${userData['role'] ?? 'N/A'}"),
                      Text("Empresa/Escola: ${userData['companyName'] ?? userData['schoolName'] ?? 'N/A'}"),
                      Text("Data da Solicitação: $requestDate"),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            label: const Text("NEGAR", style: TextStyle(color: Colors.redAccent)),
                            onPressed: () => _updateUserStatus(userDoc.id, 'denied'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text("APROVAR"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _updateUserStatus(userDoc.id, 'approved'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}