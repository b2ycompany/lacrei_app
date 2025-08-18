// lib/screens/sales/salesperson_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../profile_selection_screen.dart';
import 'register_sponsorship_screen.dart'; // Importa a nova tela de registo

class SalespersonDashboardScreen extends StatefulWidget {
  const SalespersonDashboardScreen({super.key});

  @override
  State<SalespersonDashboardScreen> createState() => _SalespersonDashboardScreenState();
}

class _SalespersonDashboardScreenState extends State<SalespersonDashboardScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text("Utilizador não autenticado.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel do Vendedor"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterSponsorshipScreen()));
        },
        tooltip: "Registar Patrocínio",
        child: const Icon(Icons.add_business),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Bem-vindo(a), ${_user.displayName ?? 'Vendedor'}!", style: Theme.of(context).textTheme.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Os seus patrocínios registados:", style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sponsorships')
                  .where('salespersonId', isEqualTo: _user.uid)
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
                  return const Center(child: Text("Nenhum patrocínio registado."));
                }

                final sponsorships = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: sponsorships.length,
                  itemBuilder: (context, index) {
                    final sponsorship = sponsorships[index].data() as Map<String, dynamic>;
                    final date = (sponsorship['sponsorshipDate'] as Timestamp).toDate();
                    final price = (sponsorship['planPrice'] as num?)?.toDouble() ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.monetization_on)),
                        title: Text(sponsorship['partnerName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Plano: ${sponsorship['planName'] ?? ''} - ${DateFormat('dd/MM/yyyy').format(date)}"),
                        trailing: Text("R\$ ${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent)),
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
  }
}