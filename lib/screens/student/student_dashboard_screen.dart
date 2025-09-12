// lib/screens/student/student_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lacrei_app/screens/ranking_screen.dart';
import '../profile_selection_screen.dart';

class GamifiedDashboardData {
  final String studentName;
  final String schoolLinkStatus;
  final String schoolId;
  final String schoolName;
  final String luckyNumber;
  final List<DocumentSnapshot> activeCampaigns;
  // 1. Novos campos para a meta
  final double goalKg;
  final double totalCollectedKg;

  GamifiedDashboardData({
    required this.studentName,
    required this.schoolLinkStatus,
    required this.schoolId,
    required this.schoolName,
    required this.luckyNumber,
    required this.activeCampaigns,
    required this.goalKg,
    required this.totalCollectedKg,
  });
}

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});
  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late Future<GamifiedDashboardData> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboardData();
  }

  Future<GamifiedDashboardData> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilizador não logado.");

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception("Perfil do utilizador não encontrado.");

    final userData = userDoc.data()!;
    final schoolId = userData['schoolId'] as String?;
    final schoolLinkStatus = userData['schoolLinkStatus'] as String? ?? 'none';
    final luckyNumber = userData['luckyNumber'] as String? ?? 'N/A';
    
    if (schoolId == null || schoolLinkStatus != 'approved') {
      return GamifiedDashboardData(
        studentName: userData['name'] ?? 'Aluno(a)',
        schoolLinkStatus: schoolLinkStatus,
        schoolId: '',
        schoolName: '',
        luckyNumber: luckyNumber,
        activeCampaigns: [],
        goalKg: 0.0, // Valor padrão
        totalCollectedKg: 0.0, // Valor padrão
      );
    }

    final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
    if (!schoolDoc.exists) throw Exception("Escola não encontrada.");

    // 2. Carrega os dados da meta diretamente do documento da escola
    final schoolData = schoolDoc.data()!;
    final goalKg = (schoolData['goalKg'] as num? ?? 0).toDouble();
    final totalCollectedKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();

    final activeCampaignsSnapshot = await FirebaseFirestore.instance
        .collection('campaigns')
        .where('associatedSchoolIds', arrayContains: schoolId)
        .get();

    return GamifiedDashboardData(
      studentName: userData['name'] ?? 'Aluno(a)',
      schoolLinkStatus: schoolLinkStatus,
      schoolId: schoolId,
      schoolName: schoolData['schoolName'] ?? 'Nome da Escola',
      activeCampaigns: activeCampaignsSnapshot.docs,
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
          SnackBar(content: Text("Erro ao fazer logoff: ${e.toString()}")),
        );
      }
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 48, 20, 78),
          title: const Text("Confirmar Saída", style: TextStyle(color: Colors.white)),
          content: const Text("Você tem certeza que deseja sair?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text("Não", style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Sim", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
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
        title: const Text('Minha Missão'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Ranking',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RankingScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
      ),
      body: FutureBuilder<GamifiedDashboardData>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Erro ao carregar dados: ${snapshot.error.toString().replaceAll('Exception: ', '')}", style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
          }
          if (snapshot.hasData) {
            final data = snapshot.data!;
            switch (data.schoolLinkStatus) {
              case 'approved':
                return _buildApprovedDashboard(data);
              case 'pending':
                return _buildPendingScreen(data);
              default:
                return _buildNoLinkScreen(data);
            }
          }
          return const Center(child: Text("Nenhum dado para exibir."));
        },
      ),
    );
  }

  // 3. Novo Widget para o "Cartão de Missão"
  Widget _buildMissionCard(GamifiedDashboardData data) {
    final progress = (data.goalKg > 0) ? (data.totalCollectedKg / data.goalKg).clamp(0.0, 1.0) : 0.0;
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          children: [
            Text(data.schoolName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
            const Text("Total Arrecadado pela Escola", style: TextStyle(color: Colors.white70)),
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

  Widget _buildApprovedDashboard(GamifiedDashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Substituído o StreamBuilder pelo novo Card
          _buildMissionCard(data),

          const SizedBox(height: 24),
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
          const Text("Recompensas Disponíveis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          data.activeCampaigns.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Nenhuma recompensa ativa para sua escola no momento.")))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.activeCampaigns.length,
            itemBuilder: (context, index) {
              final prizeData = data.activeCampaigns[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prizeData['prizeName'] ?? prizeData['campaignName'] ?? 'Recompensa',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prizeData['prizeDescription'] ?? 'Detalhes não disponíveis.',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
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

  // ... (buildPendingScreen e buildNoLinkScreen permanecem os mesmos)
  Widget _buildPendingScreen(GamifiedDashboardData data) {
    return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.amber),
      const SizedBox(height: 24),
      Text('Olá, ${data.studentName}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Sua solicitação para entrar na escola foi enviada.\n\nEstamos aguardando a aprovação do administrador. Por favor, aguarde.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5)),
    ])));
  }

  Widget _buildNoLinkScreen(GamifiedDashboardData data) {
    return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.school_outlined, size: 80, color: Colors.grey),
      const SizedBox(height: 24),
      Text('Olá, ${data.studentName}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Sua solicitação foi rejeitada ou você ainda não está vinculado a uma escola.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5)),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () {}, child: const Text("Escolher Escola")),
    ])));
  }
}