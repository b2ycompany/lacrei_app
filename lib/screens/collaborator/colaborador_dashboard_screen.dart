// lib/screens/collaborator/colaborador_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

class CollaboratorDashboardData {
  final String collaboratorName;
  final String companyId;
  final String companyName;
  final String luckyNumber;
  final List<DocumentSnapshot> activePrizes;
  // 1. Novos campos para a meta
  final double goalKg;
  final double totalCollectedKg;


  CollaboratorDashboardData({
    required this.collaboratorName,
    required this.companyId,
    required this.companyName,
    required this.luckyNumber,
    required this.activePrizes,
    required this.goalKg,
    required this.totalCollectedKg,
  });
}

class ColaboradorDashboardScreen extends StatefulWidget {
  const ColaboradorDashboardScreen({super.key});

  @override
  State<ColaboradorDashboardScreen> createState() => _ColaboradorDashboardScreenState();
}

class _ColaboradorDashboardScreenState extends State<ColaboradorDashboardScreen> {
  late Future<CollaboratorDashboardData> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboardData();
  }

  Future<CollaboratorDashboardData> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Usuário não logado.");

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception("Perfil do usuário não encontrado.");

    final userData = userDoc.data()!;
    final companyId = userData['companyId'] as String?;
    final luckyNumber = userData['luckyNumber'] as String? ?? 'N/A';
    
    if (companyId == null) {
      throw Exception("Usuário não está vinculado a nenhuma empresa.");
    }

    final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
    if (!companyDoc.exists) throw Exception("Empresa não encontrada.");

    // 2. Carrega os dados da meta diretamente do documento da empresa
    final companyData = companyDoc.data()!;
    final goalKg = (companyData['goalKg'] as num? ?? 0).toDouble();
    final totalCollectedKg = (companyData['totalCollectedKg'] as num? ?? 0).toDouble();

    final activePrizesSnapshot = await FirebaseFirestore.instance
        .collection('campaigns')
        .where('associatedCompanyIds', arrayContains: companyId)
        .get();

    return CollaboratorDashboardData(
      collaboratorName: userData['name'] ?? 'Colaborador(a)',
      companyId: companyId,
      companyName: companyData['companyName'] ?? 'Nome da Empresa',
      activePrizes: activePrizesSnapshot.docs,
      luckyNumber: luckyNumber,
      goalKg: goalKg, // Passa o valor carregado
      totalCollectedKg: totalCollectedKg, // Passa o valor carregado
    );
  }

  // ... (funções _logout e _showLogoutConfirmationDialog permanecem inalteradas)
  Future<void> _logout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.providerData.any((info) => info.providerId == 'google.com')) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao fazer logoff: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
  
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmar Saída"),
          content: const Text("Você tem certeza que deseja sair?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Sair", style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (build principal permanece o mesmo)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Colaborador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutConfirmationDialog,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: FutureBuilder<CollaboratorDashboardData>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.hasData) {
            final data = snapshot.data!;
            return _buildDashboard(data);
          }
          return const Center(child: Text("Nenhum dado para exibir."));
        },
      ),
    );
  }

  // 3. Novo Widget para o "Cartão de Missão" do Colaborador
  Widget _buildMissionCard(CollaboratorDashboardData data) {
    final progress = (data.goalKg > 0) ? (data.totalCollectedKg / data.goalKg).clamp(0.0, 1.0) : 0.0;
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          children: [
            Text(data.companyName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: "${data.totalCollectedKg.toStringAsFixed(1)} ", style: const TextStyle(color: Colors.greenAccent)),
                  TextSpan(text: "/ ${data.goalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 22, color: Colors.white70)),
                ]
              )
            ),
            const Text("Total Arrecadado pela Empresa", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.purple[900]?.withOpacity(0.5),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(CollaboratorDashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bem-vindo(a), ${data.collaboratorName}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Divider(height: 24),

          // Adicionado o novo cartão de missão aqui
          _buildMissionCard(data),
          
          Card(
            color: const Color.fromARGB(255, 26, 12, 41),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: "Seu Nº da Sorte: ",
                        style: const TextStyle(fontSize: 16),
                        children: [
                          TextSpan(
                            text: data.luckyNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          )
                        ]
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text("Prêmios Disponíveis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          data.activePrizes.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Nenhum prêmio disponível no momento.")))
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: data.activePrizes.length,
                itemBuilder: (context, index) {
                  final prizeData = data.activePrizes[index].data() as Map<String, dynamic>;
                  return Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                prizeData['prizeName'] ?? 'Prêmio',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prizeData['prizeDescription'] ?? 'Descrição do prêmio.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}