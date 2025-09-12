// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';

import '../profile_selection_screen.dart';
import 'partner_management_screen.dart';
import 'campaign_management_screen.dart';
import 'bulk_upload_screen.dart';
import 'urn_management_screen.dart';
import 'collection_route_screen.dart';
import 'school_management_screen.dart';
import 'sales_management_screen.dart';
import 'sponsorship_plans_screen.dart';
import 'company_management_screen.dart';
import 'institution_management_screen.dart';
import 'sales_report_screen.dart';
import 'access_approval_screen.dart';
import 'register_collection_screen.dart';

class SchoolParticipationReport {
  final String schoolName;
  final int participantCount;
  SchoolParticipationReport({required this.schoolName, required this.participantCount});
}

class CompanyParticipationReport {
  final String companyName;
  final int participantCount;
  CompanyParticipationReport({required this.companyName, required this.participantCount});
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<SchoolParticipationReport> _schoolReports = [];
  List<CompanyParticipationReport> _companyReports = [];
  bool _isLoadingReports = true;

  @override
  void initState() {
    super.initState();
    _fetchParticipationReports();
  }

  Future<void> _fetchParticipationReports() async {
    if (!mounted) return;
    setState(() => _isLoadingReports = true);
    try {
      final schoolsSnapshot = await FirebaseFirestore.instance.collection('schools').get();
      final List<SchoolParticipationReport> tempSchoolReports = [];
      for (var schoolDoc in schoolsSnapshot.docs) {
        final schoolId = schoolDoc.id;
        final schoolName = schoolDoc.data()['schoolName'] ?? 'Nome não encontrado';
        final countQuery = await FirebaseFirestore.instance.collection('users').where('schoolId', isEqualTo: schoolId).count().get();
        tempSchoolReports.add(SchoolParticipationReport(schoolName: schoolName, participantCount: countQuery.count ?? 0));
      }
      tempSchoolReports.sort((a, b) => a.schoolName.compareTo(b.schoolName));

      final companiesSnapshot = await FirebaseFirestore.instance.collection('companies').get();
      final List<CompanyParticipationReport> tempCompanyReports = [];
      for (var companyDoc in companiesSnapshot.docs) {
        final companyId = companyDoc.id;
        final companyName = companyDoc.data()['companyName'] ?? 'Nome não encontrado';
        final countQuery = await FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: companyId).count().get();
        tempCompanyReports.add(CompanyParticipationReport(companyName: companyName, participantCount: countQuery.count ?? 0));
      }
      tempCompanyReports.sort((a, b) => a.companyName.compareTo(b.companyName));

      if (!mounted) return;
      setState(() {
        _schoolReports = tempSchoolReports;
        _companyReports = tempCompanyReports;
        _isLoadingReports = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingReports = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar relatórios: ${e.toString()}')));
    }
  }

  Future<void> _exportReportsToCsv() async {
    List<List<dynamic>> rows = [];
    rows.add(['Tipo de Entidade', 'Nome da Entidade', 'Nº de Participantes']);

    for (var report in _schoolReports) {
      rows.add(['Escola/Faculdade', report.schoolName, report.participantCount]);
    }
    for (var report in _companyReports) {
      rows.add(['Empresa', report.companyName, report.participantCount]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "relatorio_participacao_lacrei.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _logout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.providerData.any((info) => info.providerId == 'google.com')) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
      
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao sair: ${e.toString()}')));
      }
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
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bem-vindo(a), ${user?.displayName ?? 'Admin'}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            const Text("Estatísticas da Plataforma", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard('schools', 'Escolas', Colors.orangeAccent),
                const SizedBox(width: 16),
                _buildMetricCard('companies', 'Empresas Participantes', Colors.lightBlueAccent),
                const SizedBox(width: 16),
                _buildMetricCard('users', 'Usuários', Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Relatórios de Participação", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text("Exportar"),
                  onPressed: _isLoadingReports ? null : _exportReportsToCsv,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoadingReports
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSchoolReportSection(),
                      const SizedBox(height: 24),
                      _buildCompanyReportSection(),
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
                  _buildApprovalCard(context),
                  
                  // O NOVO CARD "LANÇAR COLETA" ESTÁ AQUI
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.scale_outlined,
                    label: "Lançar Coleta",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterCollectionScreen())),
                    isHighlighted: true,
                  ),
                  
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.bar_chart,
                    label: "Relatório de Vendas",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReportScreen())),
                  ),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.group_add,
                    label: "Equipe de Vendas",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.monetization_on,
                    label: "Planos de Patrocínio",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SponsorshipPlansScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.flag, label: "Gerenciar Campanhas", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CampaignManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.business,
                    label: "Gerenciar Empresas",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.school,
                    label: "Gerenciar Escolas",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SchoolManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.corporate_fare,
                    label: "Gerenciar Instituições",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InstitutionManagementScreen())),
                  ),
                  _buildDashboardCard(
                    context: context, icon: Icons.stars, label: "Gerenciar Parceiros", 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PartnerManagementScreen())),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildApprovalCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('accountStatus', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildDashboardCard(
              context: context,
              icon: Icons.how_to_reg,
              label: "Aprovações de Acesso",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccessApprovalScreen())),
              isHighlighted: pendingCount > 0,
            ),
            if (pendingCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    pendingCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSchoolReportSection() {
    return Card(
      elevation: 4,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Escola/Faculdade', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Participantes', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: _schoolReports.map((report) => DataRow(
            cells: [
              DataCell(Text(report.schoolName)),
              DataCell(Text(report.participantCount.toString())),
            ],
          )).toList(),
        ),
      ),
    );
  }
  
  Widget _buildCompanyReportSection() {
    return Card(
      elevation: 4,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Empresa', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Participantes', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: _companyReports.map((report) => DataRow(
            cells: [
              DataCell(Text(report.companyName)),
              DataCell(Text(report.participantCount.toString())),
            ],
          )).toList(),
        ),
      ),
    );
  }

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