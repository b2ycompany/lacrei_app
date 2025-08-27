// lib/screens/sales/salesperson_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// --- CORREÇÃO: Import do Firestore corrigido ---
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Adicionado para logout completo
import '../profile_selection_screen.dart';
import 'register_sponsorship_screen.dart'; 
import 'salesperson_add_company_screen.dart'; 

class SalespersonDashboardScreen extends StatefulWidget {
  const SalespersonDashboardScreen({super.key});

  @override
  State<SalespersonDashboardScreen> createState() => _SalespersonDashboardScreenState();
}

class _SalespersonDashboardScreenState extends State<SalespersonDashboardScreen> with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      if (_user?.providerData.any((info) => info.providerId == 'google.com') ?? false) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
          (route) => false
        );
      }
    } catch (e) {
      // Tratar erro se necessário
    }
  }
  
  void _onFabPressed() {
    if (_tabController.index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SalespersonAddCompanyScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterSponsorshipScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text("Usuário não autenticado.")));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Painel do Vendedor"),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.business), text: "Empresas"),
              Tab(icon: Icon(Icons.monetization_on), text: "Patrocínios"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _onFabPressed,
          tooltip: "Adicionar",
          child: const Icon(Icons.add),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              // --- CORREÇÃO: Removido '!' desnecessário ---
              child: Text("Bem-vindo(a), ${_user.displayName ?? 'Vendedor'}!", style: Theme.of(context).textTheme.headlineSmall),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCompaniesList(),
                  _buildSponsorshipsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompaniesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .where('contactedBySalespersonId', isEqualTo: _user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Erro ao carregar empresas."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhuma empresa cadastrada."));
        }
        final companies = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final data = companies[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.business)),
                title: Text(data['companyName'] ?? 'Nome não informado'),
                subtitle: Text("Status: ${data['sponsorshipStatus'] ?? 'N/A'}"),
                trailing: Chip(
                  label: Text(data['companyType'] ?? 'Sem tipo'),
                  // --- CORREÇÃO: 'withOpacity' depreciado substituído por 'withAlpha' ---
                  backgroundColor: Colors.purpleAccent.withAlpha(50), 
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSponsorshipsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsorships')
          .where('salespersonId', isEqualTo: _user!.uid)
          .orderBy('sponsorshipDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Erro ao carregar patrocínios."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhum patrocínio registrado."));
        }
        final sponsorships = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: sponsorships.length,
          itemBuilder: (context, index) {
            final sponsorship = sponsorships[index].data() as Map<String, dynamic>;
            // --- CORREÇÃO: Adicionada verificação de nulo para Timestamp ---
            final date = (sponsorship['sponsorshipDate'] as Timestamp?)?.toDate(); 
            final price = (sponsorship['planPrice'] as num?)?.toDouble() ?? 0.0;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.monetization_on)),
                title: Text(sponsorship['partnerName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Plano: ${sponsorship['planName'] ?? ''} - ${date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Data indisponível'}"),
                trailing: Text("R\$ ${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}