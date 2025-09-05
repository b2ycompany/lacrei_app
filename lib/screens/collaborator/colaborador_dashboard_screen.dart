// lib/screens/collaborator/colaborador_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

class ColaboradorDashboardScreen extends StatefulWidget {
  const ColaboradorDashboardScreen({super.key});

  @override
  State<ColaboradorDashboardScreen> createState() => _ColaboradorDashboardScreenState();
}

class _ColaboradorDashboardScreenState extends State<ColaboradorDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  DocumentSnapshot? _companyDoc;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuário não autenticado.");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception("Perfil do usuário não encontrado.");

      final companyId = userDoc.data()?['companyId'] as String?;
      if (companyId == null) throw Exception("ID da empresa não encontrado para este usuário.");

      final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (!companyDoc.exists) throw Exception("Documento da empresa não encontrado.");

      if (mounted) {
        setState(() {
          _companyDoc = companyDoc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    try {
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      if(mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if(mounted) {
        _showSnackBar("Erro ao fazer logout: ${e.toString()}");
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Tem certeza de que deseja sair da sua conta?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Sair'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Colaborador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text("Erro: $_errorMessage", style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bem-vindo(a), ${user?.displayName ?? ''}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Garantindo que _companyDoc.data() seja um Map<String, dynamic>
                      Text("Você é colaborador da empresa: ${(_companyDoc!.data() as Map<String, dynamic>)['companyName'] ?? ''}", style: const TextStyle(fontSize: 18, color: Colors.black54)),
                      const Divider(height: 32),
                      const Text("Acompanhe o desempenho:", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(Icons.scale, size: 40, color: Colors.green),
                          title: const Text("Total de Lacres Arrecadados (Kg)", style: TextStyle(fontWeight: FontWeight.bold)),
                          // Garantindo que _companyDoc.data() seja um Map<String, dynamic>
                          subtitle: Text(((_companyDoc!.data() as Map<String, dynamic>)['totalCollectedKg'] ?? 0).toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}