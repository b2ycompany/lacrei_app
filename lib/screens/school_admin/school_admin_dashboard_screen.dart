// lib/screens/school_admin/school_admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

class SchoolAdminDashboardScreen extends StatefulWidget {
  const SchoolAdminDashboardScreen({super.key});

  @override
  State<SchoolAdminDashboardScreen> createState() => _SchoolAdminDashboardScreenState();
}

class _SchoolAdminDashboardScreenState extends State<SchoolAdminDashboardScreen> {
  String? _schoolId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchoolId();
  }

  Future<void> _fetchSchoolId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilizador não autenticado.");
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _schoolId = userDoc.data()?['schoolId'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Erro ao carregar dados do administrador.", isError: true);
      }
    }
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
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar("Erro ao fazer logoff: ${e.toString()}");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard da Escola"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(icon: Icon(Icons.dashboard), text: "Painel"),
              const Tab(icon: Icon(Icons.campaign), text: "Prémios"),
              const Tab(icon: Icon(Icons.inventory_2_outlined), text: "Urnas"),
              Tab(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _schoolId == null ? null : FirebaseFirestore.instance.collection('schools').doc(_schoolId!).collection('pendingRequests').snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [ Icon(Icons.person_add_alt_1), SizedBox(width: 8), Text("Solicitações") ],
                        ),
                        if (count > 0)
                          Positioned(
                            top: -8, right: -20,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          )
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _schoolId == null
                ? const Center(child: Text("Administrador não vinculado a uma escola."))
                : TabBarView(
                    children: [
                      SchoolDashboardView(schoolId: _schoolId!),
                      CampaignApprovalView(schoolId: _schoolId!),
                      UrnStatusView(assignedToId: _schoolId!),
                      PendingRequestsView(schoolId: _schoolId!),
                    ],
                  ),
      ),
    );
  }
}

// --- WIDGET DO PAINEL PRINCIPAL ATUALIZADO ---
class SchoolDashboardView extends StatelessWidget {
  final String schoolId;
  const SchoolDashboardView({super.key, required this.schoolId});

  // Widget reutilizável para o Cartão de Missão
  Widget _buildMissionCard({
    required String title,
    required double totalCollectedKg,
    required double goalKg,
  }) {
    final progress = (goalKg > 0) ? (totalCollectedKg / goalKg).clamp(0.0, 1.0) : 0.0;
    
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
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: "${totalCollectedKg.toStringAsFixed(1)} ", style: const TextStyle(color: Colors.greenAccent)),
                  TextSpan(text: "/ ${goalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 22, color: Colors.white70)),
                ]
              )
            ),
            const Text("Meta de Arrecadação", style: TextStyle(color: Colors.white70)),
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


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data?.data() == null) return const Card(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Dados da escola não encontrados.")));
              
              final schoolData = snapshot.data!.data() as Map<String, dynamic>;
              final totalKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();
              final goalKg = (schoolData['goalKg'] as num? ?? 0).toDouble();
              final schoolName = schoolData['schoolName'] ?? 'Sua Escola';

              // Retorna o novo Cartão de Missão
              return _buildMissionCard(
                title: schoolName,
                totalCollectedKg: totalKg,
                goalKg: goalKg,
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('schoolId', isEqualTo: schoolId).where('schoolLinkStatus', isEqualTo: 'approved').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final count = snapshot.data?.docs.length ?? 0;
              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text("Alunos e Funcionários Ativos", style: TextStyle(fontSize: 18, color: Colors.white70)),
                      const SizedBox(height: 12),
                      Text(count.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
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

// O restante dos widgets (UrnStatusView, CampaignApprovalView, PendingRequestsView) permanece inalterado.
class UrnStatusView extends StatelessWidget {
  final String assignedToId;
  const UrnStatusView({super.key, required this.assignedToId});

  Future<void> _signalUrnFull(BuildContext context, String urnId) async {
    try {
      await FirebaseFirestore.instance.collection('urns').doc(urnId).update({
        'status': 'Cheia',
        'lastFullTimestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alerta de urna cheia enviado à equipa de coleta!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao sinalizar: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('urns').where('assignedToId', isEqualTo: assignedToId).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        if (snapshot.hasError) {
          return const Center(child: Text("Erro ao carregar dados da urna."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhuma urna atribuída a este local."));
        }

        final urnDoc = snapshot.data!.docs.first;
        final data = urnDoc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'Desconhecido';
        final isFull = status == 'Cheia';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Gestão de Urnas", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(data['urnCode'] ?? 'URNA', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Chip(
                        label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: isFull ? Colors.redAccent : Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.notification_add),
                        label: const Text("Sinalizar Urna Cheia"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isFull ? Colors.grey : Colors.red,
                        ),
                        onPressed: isFull ? null : () => _signalUrnFull(context, urnDoc.id),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CampaignApprovalView extends StatelessWidget {
  final String schoolId;
  const CampaignApprovalView({super.key, required this.schoolId});
  
  Future<void> _activateCampaign(BuildContext context, String campaignId) async {
    try {
      await FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('activeCampaigns').doc(campaignId).update({'status': 'active'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prémio ativado com sucesso!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao ativar prémio: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('activeCampaigns').orderBy('startDate', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text("Erro ao carregar prémios."));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum prémio associado a esta escola."));
        
        final campaigns = snapshot.data!.docs;
        return ListView.builder(
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            final campaignDoc = campaigns[index];
            final data = campaignDoc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending_approval';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['campaignName'] ?? 'Prémio sem nome', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Oferecido por: ${data['prizeName'] ?? 'Não informado'}"),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(label: Text(status == 'active' ? 'Ativo' : 'Pendente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: status == 'active' ? Colors.green : Colors.orange),
                        if (status == 'pending_approval')
                          ElevatedButton(onPressed: () => _activateCampaign(context, campaignDoc.id), child: const Text("Ativar Prémio")),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PendingRequestsView extends StatelessWidget {
  final String schoolId;
  const PendingRequestsView({super.key, required this.schoolId});

  Future<void> _updateStudentStatus(BuildContext context, String studentUid, String status) async {
    try {
      final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);
      final requestRef = FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('pendingRequests').doc(studentUid);
      final batch = FirebaseFirestore.instance.batch();

      batch.update(studentRef, {'schoolLinkStatus': status});
      batch.delete(requestRef);

      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aluno ${status == 'approved' ? 'aprovado' : 'rejeitado'} com sucesso!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao processar solicitação: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('pendingRequests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text("Erro ao carregar solicitações."));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhuma solicitação pendente no momento."));
        
        final requests = snapshot.data!.docs;
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final studentUid = requests[index].id;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: requestData['studentImageUrl'] != null ? NetworkImage(requestData['studentImageUrl']) : null,
                  child: requestData['studentImageUrl'] == null ? const Icon(Icons.person) : null
                ),
                title: Text(requestData['studentName'] ?? 'Nome não informado'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _updateStudentStatus(context, studentUid, 'approved'), tooltip: 'Aprovar'),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _updateStudentStatus(context, studentUid, 'rejected'), tooltip: 'Rejeitar'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}