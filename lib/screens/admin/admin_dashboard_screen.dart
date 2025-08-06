// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';
import 'partner_management_screen.dart';
import 'campaign_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.providerData.any((info) => info.providerId == 'google.com')) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Em um app de produção, seria bom mostrar um SnackBar de erro aqui.
      // print("Erro ao fazer logoff: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel do Administrador"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bem-vindo(a), ${user?.displayName ?? 'Admin'}!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.stars,
                    label: "Gerenciar Parceiros",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PartnerManagementScreen()));
                    },
                  ),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.flag,
                    label: "Gerenciar Campanhas",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CampaignManagementScreen()));
                    },
                  ),
                  // Você pode adicionar novos cards de funcionalidades aqui no futuro
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.purpleAccent),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}