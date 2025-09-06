// lib/screens/company/company_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _companyId;
  String? _companyName;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
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
          _companyId = companyId;
          _companyName = companyDoc.data()?['companyName'];
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao sair: ${e.toString()}"), backgroundColor: Colors.redAccent)
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
    return DefaultTabController(
      length: 4, // Removida a aba de registro de coleta
      child: Scaffold(
        appBar: AppBar(
          title: Text(_companyName ?? "Painel da Empresa"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: _showLogoutConfirmationDialog,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Painel"),
              Tab(icon: Icon(Icons.people), text: "Colaboradores"),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: "Urnas"),
              Tab(icon: Icon(Icons.campaign), text: "Prêmios"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text("Erro: $_errorMessage", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)))
                : _companyId == null
                    ? const Center(child: Text("ID da empresa não encontrado."))
                    : TabBarView(
                        children: [
                          CompanyDashboardView(companyId: _companyId!),
                          CompanyCollaboratorsView(companyId: _companyId!),
                          UrnStatusView(assignedToId: _companyId!),
                          CompanyCampaignsView(companyId: _companyId!),
                        ],
                      ),
      ),
    );
  }
}

// WIDGETS AUXILIARES PARA CADA ABA

class CompanyDashboardView extends StatelessWidget {
  final String companyId;
  const CompanyDashboardView({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('companies').doc(companyId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final totalKg = (data['totalCollectedKg'] as num? ?? 0).toDouble();
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: companyId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final count = snapshot.data?.docs.length ?? 0;
              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text("Colaboradores Vinculados", style: TextStyle(fontSize: 18, color: Colors.white70)),
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

class CompanyCollaboratorsView extends StatelessWidget {
  final String companyId;
  const CompanyCollaboratorsView({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: companyId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum colaborador encontrado."));
        
        final collaborators = snapshot.data!.docs;
        return ListView.builder(
          itemCount: collaborators.length,
          itemBuilder: (context, index) {
            final data = collaborators[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(data['name'] ?? 'Nome não informado'),
                subtitle: Text(data['email'] ?? 'E-mail não informado'),
              ),
            );
          },
        );
      },
    );
  }
}

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
      stream: FirebaseFirestore.instance.collection('urns').where('assignedToId', isEqualTo: assignedToId).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhuma urna atribuída a esta empresa."));
        
        final urnDoc = snapshot.data!.docs.first;
        final data = urnDoc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'Desconhecido';
        final isFull = status == 'Cheia';
        
        return Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(data['urnCode'] ?? 'URNA', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   Chip(label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: isFull ? Colors.redAccent : Colors.green),
                   const SizedBox(height: 24),
                   ElevatedButton.icon(
                     icon: const Icon(Icons.notification_add),
                     label: const Text("Sinalizar Urna Cheia"),
                     style: ElevatedButton.styleFrom(backgroundColor: isFull ? Colors.grey : Colors.red),
                     onPressed: isFull ? null : () => _signalUrnFull(context, urnDoc.id),
                   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CompanyCampaignsView extends StatelessWidget {
  final String companyId;
  const CompanyCampaignsView({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    // A lógica será atualizada para buscar apenas prêmios associados a esta empresa
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('campaigns')
          .where('associatedCompanyIds', arrayContains: companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum prêmio disponível para esta empresa."));

        final campaigns = snapshot.data!.docs;
        return ListView.builder(
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            final data = campaigns[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(data['prizeName'] ?? 'Prêmio sem nome'),
                subtitle: Text(data['prizeDescription'] ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            );
          },
        );
      },
    );
  }
}