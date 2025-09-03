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
      if (user == null) throw Exception("Usuário não autenticado.");
      
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
      length: 5, 
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
              const Tab(icon: Icon(Icons.campaign), text: "Campanhas"),
              const Tab(icon: Icon(Icons.add_task), text: "Registrar Coleta"),
              const Tab(icon: Icon(Icons.inventory_2_outlined), text: "Urnas"),
              // ABA DE SOLICITAÇÕES COM BADGE DE NOTIFICAÇÃO
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
                      RegisterCollectionView(schoolId: _schoolId!),
                      UrnStatusView(assignedToId: _schoolId!),
                      PendingRequestsView(schoolId: _schoolId!),
                    ],
                  ),
      ),
    );
  }
}

// WIDGET PARA O PAINEL PRINCIPAL DO ADMIN DA ESCOLA
class SchoolDashboardView extends StatelessWidget {
  final String schoolId;
  const SchoolDashboardView({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card para mostrar o total arrecadado
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Card(child: Padding(padding: EdgeInsets.all(20.0), child: Text("N/A kg")));
              }
              final schoolData = snapshot.data!.data() as Map<String, dynamic>;
              final totalKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();
              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text("Total Geral Arrecadado", style: TextStyle(fontSize: 18, color: Colors.white70)),
                      const SizedBox(height: 12),
                      Text("${totalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Card para mostrar o número de alunos e funcionários
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('schoolId', isEqualTo: schoolId)
                .where('schoolLinkStatus', isEqualTo: 'approved')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
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


// WIDGET PARA EXIBIR E GERIR O STATUS DA URNA
class UrnStatusView extends StatelessWidget {
  final String assignedToId;
  const UrnStatusView({super.key, required this.assignedToId});

  Future<void> _signalUrnFull(BuildContext context, String urnId) async {
    try {
      await FirebaseFirestore.instance.collection('urns').doc(urnId).update({
        'status': 'Cheia',
        'lastFullTimestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alerta de urna cheia enviado à equipe de coleta!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao sinalizar: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('urns')
          .where('assignedToId', isEqualTo: assignedToId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
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
                        label: Text(
                          status,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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

// WIDGET PARA VISUALIZAR CAMPANHAS
class CampaignApprovalView extends StatelessWidget {
  final String schoolId;
  const CampaignApprovalView({super.key, required this.schoolId});
  Future<void> _activateCampaign(BuildContext context, String campaignId) async {
    try {
      await FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('activeCampaigns').doc(campaignId).update({'status': 'active'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Campanha ativada com sucesso!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao ativar campanha: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('activeCampaigns').orderBy('startDate', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
        if (snapshot.hasError) { return const Center(child: Text("Erro ao carregar campanhas.")); }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Center(child: Text("Nenhuma campanha associada a esta escola.")); }
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
                        Chip(label: Text(status == 'active' ? 'Ativa' : 'Pendente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: status == 'active' ? Colors.green : Colors.orange),
                        if (status == 'pending_approval')
                          ElevatedButton(onPressed: () => _activateCampaign(context, campaignDoc.id), child: const Text("Ativar Campanha")),
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

// WIDGET PARA REGISTRAR COLETA
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
  DocumentSnapshot? _selectedCampaign;
  Future<void> _registerCollection() async {
    if (!_formKey.currentState!.validate() || _selectedCampaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, preencha o peso e selecione uma campanha."), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isRegistering = true);
    try {
      final weightToAdd = double.parse(_weightController.text.replaceAll(',', '.'));
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(widget.schoolId);
      final campaignRef = schoolRef.collection('activeCampaigns').doc(_selectedCampaign!.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(schoolRef, {'totalCollectedKg': FieldValue.increment(weightToAdd)});
        transaction.update(campaignRef, {'collectedKg': FieldValue.increment(weightToAdd)});
      });
      await schoolRef.collection('collections').add({'weight': weightToAdd, 'date': Timestamp.now(), 'registeredBy': FirebaseAuth.instance.currentUser?.uid, 'campaignId': _selectedCampaign!.id, });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coleta registrada com sucesso!"), backgroundColor: Colors.green));
      _weightController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isRegistering = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Registrar Nova Coleta", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).collection('activeCampaigns').where('status', isEqualTo: 'active').snapshots(),
                  builder: (context, campaignSnapshot) {
                    if (!campaignSnapshot.hasData) { return const Text("A carregar campanhas..."); }
                    final activeCampaigns = campaignSnapshot.data!.docs;
                    return DropdownButtonFormField<DocumentSnapshot>(
                      value: _selectedCampaign, hint: const Text("Selecione a Campanha"),
                      items: activeCampaigns.map((doc) { return DropdownMenuItem<DocumentSnapshot>(value: doc, child: Text(doc['campaignName'] ?? 'Campanha sem nome')); }).toList(),
                      onChanged: (value) { setState(() { _selectedCampaign = value; }); },
                      validator: (value) => value == null ? 'Selecione uma campanha' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController, decoration: const InputDecoration(labelText: 'Peso Arrecadado (kg)', hintText: 'Ex: 15,5'), keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Insira o peso.';
                    if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Insira um número válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _isRegistering ? null : _registerCollection, icon: const Icon(Icons.add_task), label: const Text("Registrar Coleta"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16))),
              ],
            ),
          ),
        ),
        if (_isRegistering) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

// WIDGET PARA APROVAR/REJEITAR ALUNOS PENDENTES
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
        if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
        if (snapshot.hasError) { return const Center(child: Text("Erro ao carregar solicitações.")); }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Center(child: Text("Nenhuma solicitação pendente no momento.")); }
        
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