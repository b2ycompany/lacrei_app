// lib/screens/institution/instituicao_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

// Modelo para armazenar os dados agregados do dashboard
class InstitutionDashboardData {
  final int schoolCount;
  final double totalKgCollected;

  InstitutionDashboardData({
    required this.schoolCount,
    required this.totalKgCollected,
  });
}

class InstituicaoDashboardScreen extends StatefulWidget {
  const InstituicaoDashboardScreen({super.key});

  @override
  State<InstituicaoDashboardScreen> createState() => _InstituicaoDashboardScreenState();
}

class _InstituicaoDashboardScreenState extends State<InstituicaoDashboardScreen> {

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
      // Tratar erro de logoff, se necessário
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
          actions: <Widget>[
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
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard da Instituição"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escuta em tempo real a coleção de escolas para manter os dados sempre atualizados
        stream: FirebaseFirestore.instance.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar dados das escolas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma escola participante cadastrada."));
          }

          final schools = snapshot.data!.docs;
          
          // Calcula os dados agregados
          double totalKg = 0;
          for (var doc in schools) {
            totalKg += (doc.data() as Map<String, dynamic>)['totalCollectedKg'] ?? 0;
          }
          final dashboardData = InstitutionDashboardData(
            schoolCount: schools.length,
            totalKgCollected: totalKg,
          );

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  expandedHeight: 220.0,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bem-vindo(a), ${user?.displayName ?? 'Responsável'}!",
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Acompanhe aqui o impacto da campanha em tempo real.",
                            style: TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoCard("Total Arrecadado", "${dashboardData.totalKgCollected.toStringAsFixed(1)} kg", Colors.greenAccent),
                              _buildInfoCard("Escolas Participantes", dashboardData.schoolCount.toString(), Colors.purpleAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: schools.length,
              itemBuilder: (context, index) {
                final schoolData = schools[index].data() as Map<String, dynamic>;
                final schoolImageUrl = schoolData['schoolImageUrl'];
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: schoolImageUrl != null ? NetworkImage(schoolImageUrl) : null,
                      child: schoolImageUrl == null ? const Icon(Icons.school) : null,
                    ),
                    title: Text(schoolData['schoolName'] ?? 'Nome da Escola'),
                    trailing: Text(
                      "${(schoolData['totalCollectedKg'] as num).toDouble().toStringAsFixed(1)} kg",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: valueColor),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }
}