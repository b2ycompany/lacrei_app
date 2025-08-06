// lib/screens/student/student_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lacrei_app/screens/ranking_screen.dart';
// O import abaixo pode ser removido se o modelo SchoolProgress não for mais usado diretamente aqui
// import '../../models/school_progress.dart'; 
import '../profile_selection_screen.dart';

// LÓGICA FINAL: Modelo de dados simplificado para a nova lógica da dashboard
class GamifiedDashboardData {
  final String studentName;
  final String studentImageUrl;
  final String schoolLinkStatus;
  final String schoolId;
  final String schoolName;
  final DocumentSnapshot? activeCampaign; // Agora buscamos uma única campanha ativa da subcoleção

  GamifiedDashboardData({
    required this.studentName,
    required this.studentImageUrl,
    required this.schoolLinkStatus,
    required this.schoolId,
    required this.schoolName,
    this.activeCampaign,
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

  // LÓGICA FINAL: Função de busca de dados completamente atualizada para o fluxo correto
  Future<GamifiedDashboardData> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Usuário não logado.");

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception("Perfil do usuário não encontrado.");

    final userData = userDoc.data()!;
    final schoolId = userData['schoolId'] as String?;
    final schoolLinkStatus = userData['schoolLinkStatus'] as String? ?? 'none';
    
    // Se o aluno não estiver vinculado e aprovado, retornamos os dados básicos
    if (schoolId == null || schoolLinkStatus != 'approved') {
      return GamifiedDashboardData(
        studentName: userData['name'] ?? 'Aluno(a)',
        studentImageUrl: userData['userImageUrl'] ?? '',
        schoolLinkStatus: schoolLinkStatus,
        schoolId: '',
        schoolName: '',
      );
    }

    final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
    if (!schoolDoc.exists) throw Exception("Escola não encontrada.");

    // A MUDANÇA PRINCIPAL: Busca a campanha na subcoleção da escola com status 'active'
    final activeCampaignSnapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('activeCampaigns')
        .where('status', isEqualTo: 'active')
        .limit(1) // Pega a primeira campanha ativa que encontrar
        .get();

    return GamifiedDashboardData(
      studentName: userData['name'] ?? 'Aluno(a)',
      studentImageUrl: userData['userImageUrl'] ?? '',
      schoolLinkStatus: schoolLinkStatus,
      schoolId: schoolId,
      schoolName: schoolDoc.data()?['schoolName'] ?? 'Nome da Escola',
      activeCampaign: activeCampaignSnapshot.docs.isNotEmpty ? activeCampaignSnapshot.docs.first : null,
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
                if (data.activeCampaign == null) {
                  return _buildNoActiveCampaignScreen(data);
                }
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

  // ### WIDGET DA DASHBOARD GAMIFICADA E REDESENHADA ###
  Widget _buildApprovedDashboard(GamifiedDashboardData data) {
    final campaignData = data.activeCampaign!.data() as Map<String, dynamic>;
    final prizeName = campaignData['prizeName'] ?? 'Prêmio incrível!';
    final prizeDescription = campaignData['prizeDescription'] ?? 'Atinja a meta para desbloquear.';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').doc(data.schoolId).snapshots(),
      builder: (context, schoolSnapshot) {
        if (!schoolSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final schoolData = schoolSnapshot.data!.data() as Map<String, dynamic>;
        final totalKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();
        final goalKg = (campaignData['goalKg'] as num? ?? 1).toDouble();
        final percentage = (totalKg / goalKg).clamp(0.0, 1.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
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
                      Text(campaignData['campaignName'] ?? 'Missão Principal', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(data.schoolName, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 20,
                          backgroundColor: Colors.purple.shade900.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text("${(percentage * 100).toStringAsFixed(1)}% CONCLUÍDO", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, letterSpacing: 2)),
                      Text("${totalKg.toStringAsFixed(1)} / ${goalKg.toStringAsFixed(1)} kg", style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('🏆 RECOMPENSA DA MISSÃO 🏆', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                      const SizedBox(height: 12),
                      Text(prizeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(prizeDescription, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('PATROCINADORES OFICIAIS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white70)),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('partners').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final partners = snapshot.data!.docs;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: partners.length,
                      itemBuilder: (context, index) {
                        final partner = partners[index].data() as Map<String, dynamic>;
                        return Card(
                          elevation: 4,
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(child: Image.network(partner['imageUrl'] ?? '', fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.business))),
                                const SizedBox(height: 8),
                                Text(partner['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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