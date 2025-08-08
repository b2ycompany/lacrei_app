// lib/screens/admin/urn_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UrnManagementScreen extends StatefulWidget {
  const UrnManagementScreen({super.key});

  @override
  State<UrnManagementScreen> createState() => _UrnManagementScreenState();
}

class _UrnManagementScreenState extends State<UrnManagementScreen> {
  final _urnCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  String? _selectedAssignmentType; // 'school' ou 'company'
  String? _selectedAssignmentId;
  String? _selectedAssignmentName;

  void _showAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Atribuir Urna a..."),
          content: SizedBox(
            width: double.maxFinite,
            child: DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: "Escolas"),
                      Tab(text: "Empresas"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAssignmentList('schools', 'schoolName'),
                        _buildAssignmentList('companies', 'companyName'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentList(String collection, String nameField) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data[nameField] ?? 'Nome não encontrado'),
              onTap: () {
                setState(() {
                  _selectedAssignmentType = collection == 'schools' ? 'escola' : 'empresa';
                  _selectedAssignmentId = doc.id;
                  _selectedAssignmentName = data[nameField];
                });
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addUrn() async {
    if (!_formKey.currentState!.validate() || _selectedAssignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha o código e atribua a urna a um local."), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('urns').add({
        'urnCode': _urnCodeController.text.trim(),
        'status': 'Na Localização', // Status inicial
        'assignedToId': _selectedAssignmentId,
        'assignedToName': _selectedAssignmentName,
        'assignedToType': _selectedAssignmentType,
        'createdAt': Timestamp.now(),
        // GeoPoint pode ser adicionado depois, buscando o endereço da escola/empresa
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Urna criada e atribuída com sucesso!"), backgroundColor: Colors.green),
      );
      _urnCodeController.clear();
      setState(() {
        _selectedAssignmentId = null;
        _selectedAssignmentName = null;
        _selectedAssignmentType = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao criar urna: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestão de Urnas")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Formulário para adicionar nova urna
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Adicionar Nova Urna", style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _urnCodeController,
                    decoration: const InputDecoration(labelText: "Código da Urna (Ex: URNA-001)"),
                    validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(_selectedAssignmentName ?? "Atribuir a uma Escola ou Empresa"),
                    onPressed: _showAssignmentDialog,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addUrn,
                    child: const Text("Salvar Nova Urna"),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),
            // Lista de urnas existentes
            Text("Urnas em Campo", style: Theme.of(context).textTheme.headlineSmall),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('urns').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(data['urnCode'] ?? 'Código indisponível'),
                        subtitle: Text("Local: ${data['assignedToName'] ?? 'Não atribuído'}"),
                        trailing: Chip(
                          label: Text(data['status'] ?? 'Desconhecido'),
                          backgroundColor: data['status'] == 'Cheia' ? Colors.redAccent : Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}