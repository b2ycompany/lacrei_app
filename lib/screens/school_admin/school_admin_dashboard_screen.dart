// lib/screens/school_admin/school_admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../profile_selection_screen.dart';

class SchoolAdminDashboardScreen extends StatefulWidget {
  const SchoolAdminDashboardScreen({super.key});

  @override
  State<SchoolAdminDashboardScreen> createState() => _SchoolAdminDashboardScreenState();
}

class _SchoolAdminDashboardScreenState extends State<SchoolAdminDashboardScreen> {
  String? _schoolId;
  bool _isLoading = true; // Inicia como true para mostrar o loading inicial

  @override
  void initState() {
    super.initState();
    _fetchSchoolId();
  }

  Future<void> _fetchSchoolId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuário não autenticado.");
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _schoolId = userDoc.data()?['schoolId'];
        });
      }
    } catch (e) {
      _showSnackBar("Erro ao carregar dados do administrador.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    // ALTERADO: Comprimento do TabController para 3
    return DefaultTabController(
      length: 3, 
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
          // ALTERADO: Adicionada a nova aba "Campanhas"
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.campaign), text: "Campanhas"),
              Tab(icon: Icon(Icons.add_task), text: "Registrar Coleta"),
              Tab(icon: Icon(Icons.person_add_alt_1), text: "Solicitações"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _schoolId == null
                ? const Center(child: Text("Administrador não vinculado a uma escola."))
                // ALTERADO: Adicionado o novo widget da aba de campanhas
                : TabBarView(
                    children: [
                      CampaignApprovalView(schoolId: _schoolId!),
                      RegisterCollectionView(schoolId: _schoolId!),
                      PendingRequestsView(schoolId: _schoolId!),
                    ],
                  ),
      ),
    );
  }
}

// NOVO: Widget completo para a aba de aprovação de campanhas
class CampaignApprovalView extends StatelessWidget {
  final String schoolId;
  const CampaignApprovalView({super.key, required this.schoolId});

  Future<void> _activateCampaign(BuildContext context, String campaignId) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('activeCampaigns')
          .doc(campaignId)
          .update({'status': 'active'});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Campanha ativada com sucesso!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao ativar campanha: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('activeCampaigns')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Erro ao carregar campanhas."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhuma campanha associada a esta escola."));
        }

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
                    Text(data['campaignName'] ?? 'Campanha sem nome', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Prêmio: ${data['prizeName'] ?? 'Não informado'}"),
                    Text("Meta: ${data['goalKg'] ?? 'N/A'} kg"),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(
                            status == 'active' ? 'Ativa' : 'Pendente',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: status == 'active' ? Colors.green : Colors.orange,
                        ),
                        if (status == 'pending_approval')
                          ElevatedButton(
                            onPressed: () => _activateCampaign(context, campaignDoc.id),
                            child: const Text("Ativar Campanha"),
                          ),
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


// Widget para a aba de Registro de Coleta (sem alterações)
class RegisterCollectionView extends StatefulWidget {
  final String schoolId;
  const RegisterCollectionView({super.key, required this.schoolId});

  @override
  State<RegisterCollectionView> createState() => _RegisterCollectionViewState();
}

class _RegisterCollectionViewState extends State<RegisterCollectionView> {
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;

  Future<void> _registerCollection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isRegistering = true);
    try {
      final weightToAdd = double.parse(_weightController.text.replaceAll(',', '.'));
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(widget.schoolId);
      await schoolRef.update({'totalCollectedKg': FieldValue.increment(weightToAdd)});
      await schoolRef.collection('collections').add({
        'weight': weightToAdd,
        'date': Timestamp.now(),
        'registeredBy': FirebaseAuth.instance.currentUser?.uid,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coleta registrada!"), backgroundColor: Colors.green));
      _weightController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isRegistering = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final schoolData = snapshot.data!.data() as Map<String, dynamic>;
        final totalKg = (schoolData['totalCollectedKg'] as num).toDouble();

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(schoolData['schoolName'] ?? 'Sua Escola', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4, color: const Color.fromARGB(255, 63, 27, 102),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text("Total Já Arrecadado", style: TextStyle(fontSize: 18, color: Colors.white70)),
                            const SizedBox(height: 12),
                            Text("${totalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text("Registrar Nova Coleta", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(labelText: 'Peso Arrecadado (kg)', hintText: 'Ex: 15,5'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Por favor, insira o peso.';
                        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Por favor, insira um número válido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isRegistering ? null : _registerCollection,
                      icon: const Icon(Icons.add_task),
                      label: const Text("Registrar Coleta"),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ],
                ),
              ),
            ),
            if (_isRegistering) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
          ],
        );
      },
    );
  }
}

// Widget para a aba de Solicitações Pendentes (sem alterações)
class PendingRequestsView extends StatelessWidget {
  final String schoolId;
  const PendingRequestsView({super.key, required this.schoolId});

  Future<void> _approveStudent(String studentUid) async {
    final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);
    final requestRef = FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('pendingRequests').doc(studentUid);
    
    final batch = FirebaseFirestore.instance.batch();
    batch.update(studentRef, {'schoolLinkStatus': 'approved'});
    batch.delete(requestRef);
    await batch.commit();
  }
  
  Future<void> _rejectStudent(String studentUid) async {
    final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);
    final requestRef = FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('pendingRequests').doc(studentUid);

    final batch = FirebaseFirestore.instance.batch();
    batch.update(studentRef, {'schoolLinkStatus': 'rejected'});
    batch.delete(requestRef);
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('pendingRequests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Erro ao carregar solicitações."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhuma solicitação pendente no momento."));
        }

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
                  child: requestData['studentImageUrl'] == null ? const Icon(Icons.person) : null,
                ),
                title: Text(requestData['studentName'] ?? 'Nome não informado'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveStudent(studentUid),
                      tooltip: 'Aprovar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectStudent(studentUid),
                      tooltip: 'Rejeitar',
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