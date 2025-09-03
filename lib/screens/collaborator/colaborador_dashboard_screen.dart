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
      if (companyId == null) throw Exception("Usuário não vinculado a uma empresa.");

      final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (!companyDoc.exists) throw Exception("Empresa vinculada não encontrada.");

      if (mounted) {
        setState(() {
          _companyDoc = companyDoc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel do Colaborador"),
        actions: [ IconButton(icon: const Icon(Icons.logout), onPressed: _logout) ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text("Erro: $_errorMessage", style: const TextStyle(color: Colors.red)));
    
    if (_companyDoc != null) {
      final companyData = _companyDoc!.data() as Map<String, dynamic>;
      final user = FirebaseAuth.instance.currentUser;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bem-vindo(a), ${user?.displayName ?? ''}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Você é colaborador da empresa: ${companyData['companyName'] ?? ''}", style: const TextStyle(fontSize: 18, color: Colors.white70)),
            const Divider(height: 32),
            const Text("Acompanhe o desempenho:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.scale, size: 40),
                title: const Text("Total de Lacres Arrecadados (Kg)"),
                subtitle: Text((companyData['totalCollectedKg'] ?? 0).toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ),
            ),
          ],
        ),
      );
    }
    
    return const Center(child: Text("Nenhum dado para exibir."));
  }
}