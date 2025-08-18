// lib/screens/company/company_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// REUTILIZANDO O WIDGET DE GESTÃO DE URNAS
import '../school_admin/school_admin_dashboard_screen.dart'; 

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _registerCollection() async {
    if (!_formKey.currentState!.validate() || _user == null) return;
    setState(() => _isRegistering = true);

    try {
      final weightToAdd = double.parse(_weightController.text.replaceAll(',', '.'));
      final companyRef = FirebaseFirestore.instance.collection('companies').doc(_user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(companyRef, {'totalCollectedKg': FieldValue.increment(weightToAdd)});
      });

      await companyRef.collection('collections').add({
        'weight': weightToAdd, 'date': Timestamp.now(), 'registeredBy': _user.displayName ?? _user.email,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coleta registrada com sucesso!"), backgroundColor: Colors.green));
      _weightController.clear();
      FocusScope.of(context).unfocus();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao registrar coleta: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isRegistering = false);
    }
  }
  
  Future<void> _logout() async {
    // ... (lógica de logout, sem alterações)
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text("Erro: Nenhum usuário logado.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel da Empresa"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sair', onPressed: _logout),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('companies').doc(_user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Erro ao carregar dados da empresa."));
          }
          
          final companyData = snapshot.data!.data() as Map<String, dynamic>;
          final totalKg = (companyData['totalCollectedKg'] as num? ?? 0).toDouble();

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(companyData['companyName'] ?? 'Sua Empresa', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text("Total de Lacres Contribuídos", style: TextStyle(fontSize: 18, color: Colors.white70)),
                            const SizedBox(height: 12),
                            Text("${totalKg.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Formulário de Registro de Coleta (sem alterações)
                    Text("Registrar Nova Coleta", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(labelText: 'Peso dos Lacres (kg)', hintText: 'Ex: 25,5'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Por favor, insira o peso.';
                          if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Por favor, insira um número válido.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isRegistering ? null : _registerCollection,
                      icon: const Icon(Icons.add_task),
                      label: const Text("Registrar Coleta"),
                    ),
                    const Divider(height: 48),
                    // NOVO: Adicionada a visão de status da urna
                    UrnStatusView(assignedToId: _user.uid),
                  ],
                ),
              ),
              if (_isRegistering) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
            ],
          );
        },
      ),
    );
  }
}