// lib/screens/admin/campaign_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelos de dados para os dropdowns
class School {
  final String id;
  final String name;
  School({required this.id, required this.name});
}

class Company {
  final String id;
  final String name;
  Company({required this.id, required this.name});
}


class CampaignManagementScreen extends StatefulWidget {
  const CampaignManagementScreen({super.key});

  @override
  State<CampaignManagementScreen> createState() => _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  
  void _deleteCampaign(String docId) async {
    // Adicionar aqui a lógica para desassociar das escolas/empresas se necessário
    await FirebaseFirestore.instance.collection('campaigns').doc(docId).delete();
  }

  void _navigateToPrizeForm({DocumentSnapshot? prize}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPrizeScreen(prize: prize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Prêmios")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToPrizeForm(),
        tooltip: 'Novo Prêmio',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('campaigns').orderBy('prizeName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text("Erro ao carregar prêmios."));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum prêmio criado."));
          
          final prizes = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: prizes.length,
            itemBuilder: (context, index) {
              final prize = prizes[index];
              final data = prize.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['prizeName'] ?? 'Prêmio sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Associado a: ${(data['associationType'] ?? 'N/A').toString().toUpperCase()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteCampaign(prize.id),
                  ),
                  onTap: () => _navigateToPrizeForm(prize: prize),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Tela de Formulário para Adicionar/Editar Prêmios
class AddEditPrizeScreen extends StatefulWidget {
  final DocumentSnapshot? prize;
  const AddEditPrizeScreen({super.key, this.prize});

  @override
  State<AddEditPrizeScreen> createState() => _AddEditPrizeScreenState();
}

class _AddEditPrizeScreenState extends State<AddEditPrizeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _prizeNameController = TextEditingController();
  
  bool _isLoading = true;
  bool get _isEditing => widget.prize != null;

  String _associationType = 'schools'; // 'schools' ou 'companies'
  
  List<School> _allSchools = [];
  List<Company> _allCompanies = [];
  
  final Map<String, bool> _selectedSchools = {};
  final Map<String, bool> _selectedCompanies = {};
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchEntities();
    if (_isEditing) {
      _populateFormForEditing();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchEntities() async {
    final schoolsSnapshot = await FirebaseFirestore.instance.collection('schools').orderBy('schoolName').get();
    _allSchools = schoolsSnapshot.docs.map((doc) => School(id: doc.id, name: doc.data()['schoolName'])).toList();
    for (var school in _allSchools) {
      _selectedSchools[school.id] = false;
    }

    final companiesSnapshot = await FirebaseFirestore.instance.collection('companies').orderBy('companyName').get();
    _allCompanies = companiesSnapshot.docs.map((doc) => Company(id: doc.id, name: doc.data()['companyName'])).toList();
    for (var company in _allCompanies) {
      _selectedCompanies[company.id] = false;
    }
  }

  void _populateFormForEditing() {
    final data = widget.prize!.data() as Map<String, dynamic>;
    _prizeNameController.text = data['prizeName'] ?? '';
    _associationType = data['associationType'] ?? 'schools';

    if (_associationType == 'schools' && data['associatedSchoolIds'] != null) {
      for (var id in List<String>.from(data['associatedSchoolIds'])) {
        _selectedSchools[id] = true;
      }
    }
    if (_associationType == 'companies' && data['associatedCompanyIds'] != null) {
      for (var id in List<String>.from(data['associatedCompanyIds'])) {
        _selectedCompanies[id] = true;
      }
    }
  }

  Future<void> _savePrize() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final List<String> associatedSchoolIds = _associationType == 'schools'
          ? _selectedSchools.entries.where((e) => e.value).map((e) => e.key).toList()
          : [];
      final List<String> associatedCompanyIds = _associationType == 'companies'
          ? _selectedCompanies.entries.where((e) => e.value).map((e) => e.key).toList()
          : [];
      
      final prizeData = {
        'prizeName': _prizeNameController.text.trim(),
        'associationType': _associationType,
        'associatedSchoolIds': associatedSchoolIds,
        'associatedCompanyIds': associatedCompanyIds,
        // O campo 'meta' não é mais salvo
      };

      if (_isEditing) {
        await FirebaseFirestore.instance.collection('campaigns').doc(widget.prize!.id).update(prizeData);
      } else {
        await FirebaseFirestore.instance.collection('campaigns').add(prizeData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prêmio salvo com sucesso!"), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Prêmio' : 'Novo Prêmio'),
        actions: [ IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _savePrize) ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _prizeNameController,
                  decoration: const InputDecoration(labelText: 'Nome do Prêmio'),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 24),
                const Text("Associar prêmio a:", style: TextStyle(fontSize: 16)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'schools', label: Text('Escolas')),
                    ButtonSegment(value: 'companies', label: Text('Empresas')),
                  ],
                  selected: {_associationType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _associationType = newSelection.first);
                  },
                ),
                const SizedBox(height: 16),
                if (_associationType == 'schools')
                  _buildEntitySelector<School>(
                    title: 'Selecione as Escolas',
                    allItems: _allSchools,
                    selectedItems: _selectedSchools,
                    onChanged: (id, value) => setState(() => _selectedSchools[id] = value),
                  ),
                if (_associationType == 'companies')
                  _buildEntitySelector<Company>(
                    title: 'Selecione as Empresas',
                    allItems: _allCompanies,
                    selectedItems: _selectedCompanies,
                    onChanged: (id, value) => setState(() => _selectedCompanies[id] = value),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildEntitySelector<T>({
    required String title,
    required List<T> allItems,
    required Map<String, bool> selectedItems,
    required Function(String, bool) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          height: 300,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: ListView.builder(
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              final String id = (item as dynamic).id;
              final String name = (item as dynamic).name;
              return CheckboxListTile(
                title: Text(name),
                value: selectedItems[id] ?? false,
                onChanged: (bool? value) => onChanged(id, value ?? false),
              );
            },
          ),
        ),
      ],
    );
  }
}