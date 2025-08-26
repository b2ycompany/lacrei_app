// lib/screens/admin/sales_report_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaleReportItem {
  final String companyName;
  final String salespersonName;
  final String planName;
  final double planPrice;
  final double commissionValue;

  SaleReportItem({
    required this.companyName,
    required this.salespersonName,
    required this.planName,
    required this.planPrice,
    required this.commissionValue,
  });
}

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  bool _isLoading = true;
  List<SaleReportItem> _reportItems = [];
  double _totalRevenue = 0.0;
  double _totalCommission = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final salespeopleSnapshot = await FirebaseFirestore.instance.collection('salespeople').get();
      final plansSnapshot = await FirebaseFirestore.instance.collection('sponsorship_plans').get();

      final salespeopleMap = {for (var doc in salespeopleSnapshot.docs) doc.id: doc.data()};
      final plansMap = {for (var doc in plansSnapshot.docs) doc.id: doc.data()};

      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('sponsorshipStatus', isEqualTo: 'Patrocinador Ativo')
          .get();

      final List<SaleReportItem> tempReport = [];
      for (var companyDoc in companiesSnapshot.docs) {
        final companyData = companyDoc.data();
        final salespersonId = companyData['contactedBySalespersonId'];
        final planId = companyData['sponsorshipPlanId'];

        if (salespersonId != null && planId != null) {
          final salespersonData = salespeopleMap[salespersonId];
          final planData = plansMap[planId];

          if (salespersonData != null && planData != null) {
            final price = (planData['price'] as num?)?.toDouble() ?? 0.0;
            final commissionRate = (planData['commissionRate'] as num?)?.toDouble() ?? 0.0;
            final commission = price * commissionRate;

            tempReport.add(SaleReportItem(
              companyName: companyData['companyName'] ?? 'N/A',
              salespersonName: salespersonData['name'] ?? 'N/A',
              planName: planData['planName'] ?? 'N/A',
              planPrice: price,
              commissionValue: commission,
            ));
          }
        }
      }

      double totalRev = tempReport.fold(0.0, (sum, item) => sum + item.planPrice);
      double totalComm = tempReport.fold(0.0, (sum, item) => sum + item.commissionValue);
      
      if(mounted) {
        setState(() {
          _reportItems = tempReport;
          _totalRevenue = totalRev;
          _totalCommission = totalComm;
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao gerar relatório: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Relatório de Vendas"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildSummaryCard("Receita Total", _totalRevenue, Icons.trending_up, Colors.green),
                      const SizedBox(width: 16),
                      _buildSummaryCard("Comissões Totais", _totalCommission, Icons.percent, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Empresa')),
                          DataColumn(label: Text('Vendedor')),
                          DataColumn(label: Text('Plano')),
                          DataColumn(label: Text('Valor'), numeric: true),
                          DataColumn(label: Text('Comissão'), numeric: true),
                        ],
                        rows: _reportItems.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item.companyName)),
                            DataCell(Text(item.salespersonName)),
                            DataCell(Text(item.planName)),
                            DataCell(Text('R\$ ${item.planPrice.toStringAsFixed(2)}')),
                            DataCell(Text('R\$ ${item.commissionValue.toStringAsFixed(2)}')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, double value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70)),
                  Icon(icon, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'R\$ ${value.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}