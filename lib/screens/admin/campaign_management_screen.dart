// lib/screens/admin/campaign_management_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class CampaignManagementScreen extends StatefulWidget {
  const CampaignManagementScreen({super.key});

  @override
  State<CampaignManagementScreen> createState() => _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  
  String _getCampaignStatus(Timestamp start, Timestamp end) {
    final now = Timestamp.now();
    if (now.compareTo(start) >= 0 && now.compareTo(end) <= 0) {
      return 'Ativa';
    } else if (now.compareTo(end) > 0) {
      return 'Finalizada';
    } else {
      return 'Agendada';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ativa': return Colors.green;
      case 'Finalizada': return Colors.grey;
      case 'Agendada': return Colors.blue;
      default: return Colors.black;
    }
  }

  void _navigateToCampaignForm({DocumentSnapshot? campaign}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCampaignScreen(campaign: campaign),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Campanhas")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCampaignForm(),
        tooltip: 'Nova Campanha',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('campaigns').orderBy('startDate', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar campanhas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma campanha criada.\nClique no botão '+' para adicionar uma."));
          }
          
          final campaigns = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), 
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              final data = campaign.data() as Map<String, dynamic>;
              
              final startDate = data['startDate'] as Timestamp? ?? Timestamp.now();
              final endDate = data['endDate'] as Timestamp? ?? Timestamp.now();
              final status = _getCampaignStatus(startDate, endDate);
              
              final campaignName = data['name'] ?? 'Campanha sem nome';
              final goalKg = data['goalKg']?.toString() ?? 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(campaignName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Meta: $goalKg kg | Prazo: ${DateFormat('dd/MM/yy').format(startDate.toDate())} a ${DateFormat('dd/MM/yy').format(endDate.toDate())}"),
                  trailing: Chip(
                    label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: _getStatusColor(status),
                  ),
                  onTap: () => _navigateToCampaignForm(campaign: campaign),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


// ### TELA DE CRIAR/EDITAR CAMPANHA ATUALIZADA ###

class AddEditCampaignScreen extends StatefulWidget {
  final DocumentSnapshot? campaign;

  const AddEditCampaignScreen({super.key, this.campaign});

  @override
  State<AddEditCampaignScreen> createState() => _AddEditCampaignScreenState();
}

class _AddEditCampaignScreenState extends State<AddEditCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _goalController;
  late TextEditingController _prizeNameController;
  late TextEditingController _prizeDescriptionController;
  
  DateTime? _startDate;
  DateTime? _endDate;

  final List<XFile> _newImageFiles = [];
  final List<String> _existingImageUrls = [];
  bool _isLoading = false;

  // NOVO: Variáveis para gerenciar a seleção de escolas
  List<DocumentSnapshot> _allSchools = [];
  Map<String, bool> _selectedSchools = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _goalController = TextEditingController();
    _prizeNameController = TextEditingController();
    _prizeDescriptionController = TextEditingController();

    _loadInitialData();
  }

  // NOVO: Função para carregar todos os dados necessários
  Future<void> _loadInitialData() async {
    await _fetchSchools();
    if (widget.campaign != null) {
      _populateFormForEditing();
    }
    setState(() {}); // Atualiza a UI após carregar os dados
  }

  Future<void> _fetchSchools() async {
    final schoolsSnapshot = await FirebaseFirestore.instance.collection('schools').get();
    _allSchools = schoolsSnapshot.docs;
  }
  
  void _populateFormForEditing() {
    final data = widget.campaign!.data() as Map<String, dynamic>?;
    _nameController.text = data?['name'] as String? ?? '';
    _goalController.text = (data?['goalKg'] as num?)?.toString() ?? '';
    _prizeNameController.text = data?['prizeName'] as String? ?? '';
    _prizeDescriptionController.text = data?['prizeDescription'] as String? ?? '';
    _startDate = (data?['startDate'] as Timestamp?)?.toDate();
    _endDate = (data?['endDate'] as Timestamp?)?.toDate();

    if (data?['imageUrls'] != null) {
      _existingImageUrls.addAll(List<String>.from(data!['imageUrls']));
    }

    // NOVO: Pré-seleciona as escolas que já estão associadas
    final List<String> associatedIds = List<String>.from(data?['associatedSchoolIds'] ?? []);
    for (var school in _allSchools) {
      _selectedSchools[school.id] = associatedIds.contains(school.id);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _prizeNameController.dispose();
    _prizeDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (pickedFiles.isNotEmpty) {
      setState(() { _newImageFiles.addAll(pickedFiles); });
    }
  }

  // LÓGICA DE SALVAR ATUALIZADA
  Future<void> _saveCampaign() async {
    if (!_formKey.currentState!.validate() || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos e selecione as datas.")));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final List<String> imageUrls = List.from(_existingImageUrls);
      final campaignId = widget.campaign?.id ?? FirebaseFirestore.instance.collection('campaigns').doc().id;

      // ... (lógica de upload de imagem, sem alterações)

      final List<String> selectedSchoolIds = _selectedSchools.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      final campaignData = {
        'name': _nameController.text.trim(),
        'goalKg': double.tryParse(_goalController.text) ?? 0,
        'prizeName': _prizeNameController.text.trim(),
        'prizeDescription': _prizeDescriptionController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'imageUrls': imageUrls,
        'associatedSchoolIds': selectedSchoolIds, // Salva os IDs das escolas associadas
      };

      // 1. Salva ou atualiza a campanha "mestre"
      await FirebaseFirestore.instance.collection('campaigns').doc(campaignId).set(campaignData, SetOptions(merge: true));

      // 2. Distribui a campanha para as subcoleções das escolas selecionadas
      final schoolCampaignData = {
        'campaignName': campaignData['name'],
        'goalKg': campaignData['goalKg'],
        'prizeName': campaignData['prizeName'],
        'prizeDescription': campaignData['prizeDescription'],
        'imageUrls': campaignData['imageUrls'],
        'startDate': campaignData['startDate'],
        'endDate': campaignData['endDate'],
        'status': 'pending_approval', // Status inicial para aprovação do admin da escola
      };

      for (final schoolId in selectedSchoolIds) {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('activeCampaigns')
            .doc(campaignId)
            .set(schoolCampaignData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Campanha salva e associada com sucesso!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar campanha: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign != null ? 'Editar Campanha' : 'Nova Campanha'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _saveCampaign),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ... (campos de texto para nome, meta, prêmio, etc., sem alterações)

                  // NOVO: Secção para associar escolas
                  const SizedBox(height: 24),
                  Text("Associar Campanha a Escolas", style: Theme.of(context).textTheme.titleMedium),
                  const Divider(height: 24),
                  _allSchools.isEmpty
                      ? const Center(child: Text("Nenhuma escola encontrada."))
                      : Column(
                          children: _allSchools.map((schoolDoc) {
                            final schoolId = schoolDoc.id;
                            final schoolName = (schoolDoc.data() as Map<String, dynamic>)['schoolName'] ?? 'Escola sem nome';
                            return CheckboxListTile(
                              title: Text(schoolName),
                              value: _selectedSchools[schoolId] ?? false,
                              onChanged: (bool? value) {
                                setState(() {
                                  _selectedSchools[schoolId] = value ?? false;
                                });
                              },
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black.withAlpha(150), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}