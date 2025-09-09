// lib/screens/student/student_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lacrei_app/screens/ranking_screen.dart';
import '../profile_selection_screen.dart';

class GamifiedDashboardData {
  final String studentName;
  final String studentImageUrl;
  final String schoolLinkStatus;
  final String schoolId;
  final String schoolName;
  final String luckyNumber;
  final List<DocumentSnapshot> activeCampaigns;

  GamifiedDashboardData({
    required this.studentName,
    required this.studentImageUrl,
    required this.schoolLinkStatus,
    required this.schoolId,
    required this.schoolName,
    required this.luckyNumber,
    required this.activeCampaigns,
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
    if (user == null) throw Exception("Usuário não logado.");

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception("Perfil do usuário não encontrado.");

    final userData = userDoc.data()!;
    final schoolId = userData['schoolId'] as String?;
    final schoolLinkStatus = userData['schoolLinkStatus'] as String? ?? 'none';
    final luckyNumber = userData['luckyNumber'] as String? ?? 'N/A';
    
    if (schoolId == null || schoolLinkStatus != 'approved') {
      return GamifiedDashboardData(
        studentName: userData['name'] ?? 'Aluno(a)',
        studentImageUrl: userData['userImageUrl'] ?? '',
        schoolLinkStatus: schoolLinkStatus,
        schoolId: '',
        schoolName: '',
        luckyNumber: luckyNumber,
        activeCampaigns: [],
      );
    }

    final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
    if (!schoolDoc.exists) throw Exception("Escola não encontrada.");

    // CORREÇÃO: Busca TODAS as campanhas/prêmios ativos para a escola
    final activeCampaignsSnapshot = await FirebaseFirestore.instance
        .collection('campaigns')
        .where('associatedSchoolIds', arrayContains: schoolId)
        .get();

    return GamifiedDashboardData(
      studentName: userData['name'] ?? 'Aluno(a)',
      studentImageUrl: userData['userImageUrl'] ?? '',
      schoolLinkStatus: schoolLinkStatus,
      schoolId: schoolId,
      schoolName: schoolDoc.data()?['schoolName'] ?? 'Nome da Escola',
      activeCampaigns: activeCampaignsSnapshot.docs,
      luckyNumber: luckyNumber,
    );
  }

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
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Erro ao carregar dados: ${snapshot.error}", style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
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

  Widget _buildApprovedDashboard(GamifiedDashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('schools').doc(data.schoolId).snapshots(),
            builder: (context, schoolSnapshot) {
              if (!schoolSnapshot.hasData) return const SizedBox.shrink();
              final schoolData = schoolSnapshot.data!.data() as Map<String, dynamic>;
              final totalKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();

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
                      Text("${totalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      const Text("Total Arrecadado pela Escola", style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              );
            },
          ),
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
                      const SizedBox(height: 12),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('schools').doc(data.schoolId).snapshots(),
                        builder: (context, schoolSnapshot) {
                          if (!schoolSnapshot.hasData) return const SizedBox.shrink();
                          final schoolData = schoolSnapshot.data!.data() as Map<String, dynamic>;
                          final totalKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();
                          final goalKg = (prizeData['goalKg'] as num? ?? 1).toDouble();
                          
                          // Garante que a meta não seja 0 para evitar divisão por zero
                          final safeGoalKg = goalKg == 0 ? 1.0 : goalKg;
                          final percentage = (totalKg / safeGoalKg).clamp(0.0, 1.0);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  minHeight: 15,
                                  backgroundColor: Colors.purple.shade900.withOpacity(0.5),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${(percentage * 100).toStringAsFixed(1)}% CONCLUÍDO",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, letterSpacing: 1),
                              ),
                              Text(
                                "${totalKg.toStringAsFixed(1)} / ${goalKg.toStringAsFixed(1)} kg",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          );
                        },
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

  Widget _buildNoActiveCampaignScreen(GamifiedDashboardData data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text('Olá, ${data.studentName}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'A sua escola ainda não iniciou uma nova campanha.\n\nAguarde a próxima missão!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

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