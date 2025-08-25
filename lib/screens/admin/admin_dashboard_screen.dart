// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';
import 'partner_management_screen.dart';
import 'campaign_management_screen.dart';
import 'bulk_upload_screen.dart';
import 'urn_management_screen.dart';
import 'collection_route_screen.dart';
import 'school_management_screen.dart';
import 'sales_management_screen.dart';
import 'sponsorship_plans_screen.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bem-vindo(a), ${user?.displayName ?? 'Admin'}!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // NOVO: DASHBOARD DE ESTATÍSTICAS
            const Text("Estatísticas da Plataforma", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard('schools', 'Escolas', Colors.orangeAccent),
                const SizedBox(width: 16),
                _buildMetricCard('companies', 'Empresas', Colors.lightBlueAccent),
                const SizedBox(width: 16),
                _buildMetricCard('users', 'Usuários', Colors.purpleAccent),
              ],
            ),
            const Divider(height: 48, thickness: 1),

            const Text("Ferramentas de Gestão", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                  _buildDashboardCard(
                    context: context, icon: Icons.flag, label: "Gerenciar Campanhas", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CampaignManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.stars, label: "Gerenciar Parceiros", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PartnerManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.school, label: "Gerenciar Escolas", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SchoolManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.inventory_2_outlined, label: "Gestão de Urnas", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UrnManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.route_outlined, label: "Rota de Coleta", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionRouteScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.upload, label: "Carga de Escolas", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BulkUploadScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.group_add, label: "Equipe de Vendas", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesManagementScreen())),
                    isHighlighted: true,
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.monetization_on, label: "Planos de Patrocínio", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SponsorshipPlansScreen())),
                    isHighlighted: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NOVO: Widget para os cards de métricas
  Widget _buildMetricCard(String collection, String label, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection(collection).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text("...", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
                  }
                  if (!snapshot.hasData) return const Text("0", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
                  
                  return Text(
                    snapshot.data!.docs.length.toString(),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({required BuildContext context, required IconData icon, required String label, required VoidCallback onTap, bool isHighlighted = false}) {
    return Card(
      elevation: isHighlighted ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isHighlighted ? Colors.purpleAccent : Colors.transparent, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.purpleAccent),
            const SizedBox(height: 16),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}