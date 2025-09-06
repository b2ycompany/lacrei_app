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
        _showSnackBar("Erro ao carregar o dashboard: ${e.toString()}", isError: true);
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
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Erro ao fazer logoff: ${e.toString()}", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
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
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(icon: Icon(Icons.dashboard), text: "Painel"),
              const Tab(icon: Icon(Icons.campaign), text: "Prêmios"),
              const Tab(icon: Icon(Icons.inventory_2_outlined), text: "Urnas"),
              Tab(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _schoolId == null ? null : FirebaseFirestore.instance.collection('schools').doc(_schoolId!).collection('pendingRequests').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return Badge(
                        label: Text(snapshot.data!.docs.length.toString()),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add),
                            SizedBox(width: 8),
                            Text("Aprovações"),
                          ],
                        ),
                      );
                    }
                    return const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add),
                        SizedBox(width: 8),
                        Text("Aprovações"),
                      ],
                    );
                  },
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

// WIDGETS AUXILIARES

// WIDGET PARA EXIBIR O DASHBOARD DA ESCOLA
class SchoolDashboardView extends StatelessWidget {
  final String schoolId;
  const SchoolDashboardView({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).snapshots(),
      builder: (context, schoolSnapshot) {
        if (schoolSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (schoolSnapshot.hasError) {
          return const Center(child: Text("Erro ao carregar dados da escola."));
        }
        if (!schoolSnapshot.hasData || !schoolSnapshot.data!.exists) {
          return const Center(child: Text("Dados da escola não encontrados."));
        }

        final schoolData = schoolSnapshot.data!.data() as Map<String, dynamic>;
        final totalKg = (schoolData['totalCollectedKg'] as num? ?? 0).toDouble();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text("Total de Coleta", style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text("${totalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Alunos Vinculados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').where('schoolId', isEqualTo: schoolId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Text("Nenhum aluno vinculado.");
                          }
                          return Text("${snapshot.data!.docs.length} alunos");
                        },
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

// WIDGET PARA EXIBIR E GERIR O STATUS DA URNA
class UrnStatusView extends StatelessWidget {
  final String assignedToId;
  const UrnStatusView({super.key, required this.assignedToId});

  Future<void> _signalUrnFull(BuildContext context, String urnId) async {
    try {
      await FirebaseFirestore.instance.collection('urns').doc(urnId).update({
        'status': 'Cheia',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status da urna atualizado para "Cheia".')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao sinalizar a urna: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('urns').where('assignedToId', isEqualTo: assignedToId).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        // Tratamento de erro explícito
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Ocorreu um erro ao carregar os dados da urna. Verifique as permissões do banco de dados.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)
              ),
            ),
          );
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(isFull ? Icons.delete_sweep_outlined : Icons.inventory_2, size: 80, color: isFull ? Colors.redAccent : Colors.lightGreen),
                      const SizedBox(height: 16),
                      const Text("Status da Urna", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(status, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isFull ? Colors.redAccent : Colors.lightGreen)),
                      const SizedBox(height: 16),
                      if (!isFull)
                        ElevatedButton.icon(
                          onPressed: () => _signalUrnFull(context, urnDoc.id),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text("Sinalizar Urna Cheia"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
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

// WIDGET PARA APROVAR CAMPANHAS
class CampaignApprovalView extends StatefulWidget {
  final String schoolId;
  const CampaignApprovalView({super.key, required this.schoolId});

  @override
  State<CampaignApprovalView> createState() => _CampaignApprovalViewState();
}

class _CampaignApprovalViewState extends State<CampaignApprovalView> {
  final _formKey = GlobalKey<FormState>();
  final _campaignNameController = TextEditingController();
  final _prizeDescriptionController = TextEditingController();
  final _goalKgController = TextEditingController();
  bool _isCreating = false;

  Future<void> _createCampaign() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      await FirebaseFirestore.instance.collection('campaigns').add({
        'campaignName': _campaignNameController.text,
        'prizeDescription': _prizeDescriptionController.text,
        'goalKg': double.parse(_goalKgController.text),
        'associatedSchoolIds': [widget.schoolId],
        'createdAt': FieldValue.serverTimestamp(),
      });
      _clearForm();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campanha criada com sucesso!')));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao criar campanha: ${e.toString()}')));
      }
    } finally {
      if(mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _clearForm() {
    _campaignNameController.clear();
    _prizeDescriptionController.clear();
    _goalKgController.clear();
  }

  Future<void> _deleteCampaign(String campaignId) async {
    try {
      await FirebaseFirestore.instance.collection('campaigns').doc(campaignId).delete();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campanha excluída com sucesso!')));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir campanha: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Criar Nova Campanha de Prêmios", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _campaignNameController,
                  decoration: const InputDecoration(labelText: "Nome da Campanha"),
                  validator: (value) => value!.isEmpty ? "Por favor, insira o nome da campanha" : null,
                ),
                TextFormField(
                  controller: _prizeDescriptionController,
                  decoration: const InputDecoration(labelText: "Descrição do Prêmio"),
                  validator: (value) => value!.isEmpty ? "Por favor, insira a descrição do prêmio" : null,
                  maxLines: 3,
                ),
                TextFormField(
                  controller: _goalKgController,
                  decoration: const InputDecoration(labelText: "Meta (kg de material)"),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value!.isEmpty) return "Por favor, insira a meta em kg";
                    if (double.tryParse(value) == null) return "Insira um número válido";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _isCreating
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _createCampaign,
                        child: const Text("Criar Campanha"),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text("Campanhas Ativas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('campaigns')
                .where('associatedSchoolIds', arrayContains: widget.schoolId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Nenhuma campanha ativa no momento."));
              }
              final campaigns = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: campaigns.length,
                itemBuilder: (context, index) {
                  final campaign = campaigns[index];
                  final campaignData = campaign.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text(campaignData['campaignName'] ?? 'Campanha'),
                      subtitle: Text("Meta: ${campaignData['goalKg'] ?? 0} kg"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCampaign(campaign.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// WIDGET PARA EXIBIR E APROVAR/REJEITAR SOLICITAÇÕES PENDENTES
class PendingRequestsView extends StatelessWidget {
  final String schoolId;
  const PendingRequestsView({super.key, required this.schoolId});

  Future<void> _updateStudentStatus(BuildContext context, String studentUid, String status) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final userDocRef = firestore.collection('users').doc(studentUid);
    final pendingRequestDocRef = firestore.collection('schools').doc(schoolId).collection('pendingRequests').doc(studentUid);

    batch.update(userDocRef, {'schoolLinkStatus': status, if (status == 'rejected') 'schoolId': null});
    batch.delete(pendingRequestDocRef);

    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitação do aluno atualizada para $status!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao atualizar status: ${e.toString()}")));
    }
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