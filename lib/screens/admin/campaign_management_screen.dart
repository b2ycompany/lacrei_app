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

  List<DocumentSnapshot> _allSchools = [];
  final Map<String, bool> _selectedSchools = {};
  List<String> _initialAssociatedSchoolIds = []; 

  String _prizeEligibilityRule = 'all'; 
  final Map<String, bool> _prizeEligibleSchools = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _goalController = TextEditingController();
    _prizeNameController = TextEditingController();
    _prizeDescriptionController = TextEditingController();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchSchools();
    if (widget.campaign != null) {
      _populateFormForEditing();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchSchools() async {
    final schoolsSnapshot = await FirebaseFirestore.instance.collection('schools').orderBy('schoolName').get();
    _allSchools = schoolsSnapshot.docs;
    for (var school in _allSchools) {
      _selectedSchools[school.id] = false;
    }
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

    _initialAssociatedSchoolIds = List<String>.from(data?['associatedSchoolIds'] ?? []);
    for (var schoolId in _initialAssociatedSchoolIds) {
      _selectedSchools[schoolId] = true;
    }

    _prizeEligibilityRule = data?['prizeEligibilityRule'] as String? ?? 'all';
    final List<String> eligibleIds = List<String>.from(data?['prizeEligibleSchoolIds'] ?? []);
    for (var schoolId in eligibleIds) {
      _prizeEligibleSchools[schoolId] = true;
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

  void _applySchoolFilter(String filter) {
    setState(() {
      _selectedSchools.forEach((schoolId, isSelected) {
        if (filter == 'all') {
          _selectedSchools[schoolId] = true;
        } else if (filter == 'none') {
          _selectedSchools[schoolId] = false;
        } else {
          final schoolDoc = _allSchools.firstWhere((doc) => doc.id == schoolId);
          final schoolType = (schoolDoc.data() as Map<String, dynamic>)['schoolType'];
          if (schoolType == filter) {
            _selectedSchools[schoolId] = true;
          } else {
            _selectedSchools[schoolId] = false;
          }
        }
      });
    });
  }
  
  Future<void> _saveCampaign() async {
    if (!_formKey.currentState!.validate() || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos e selecione as datas.")));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final List<String> imageUrls = List.from(_existingImageUrls);
      final campaignId = widget.campaign?.id ?? FirebaseFirestore.instance.collection('campaigns').doc().id;

      for (final imageFile in _newImageFiles) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
        final ref = FirebaseStorage.instance.ref('campaign_images/$campaignId/$fileName');
        if (kIsWeb) {
          await ref.putData(await imageFile.readAsBytes());
        } else {
          await ref.putFile(File(imageFile.path));
        }
        imageUrls.add(await ref.getDownloadURL());
      }
      
      // AQUI ESTAVA O ERRO: _selectedschools -> _selectedSchools
      final List<String> selectedSchoolIds = _selectedSchools.entries.where((e) => e.value).map((e) => e.key).toList();
      final List<String> prizeEligibleSchoolIds = _prizeEligibilityRule == 'specific' 
          ? _prizeEligibleSchools.entries.where((e) => e.value).map((e) => e.key).toList()
          : [];

      final campaignData = {
        'name': _nameController.text.trim(), 'goalKg': double.tryParse(_goalController.text) ?? 0,
        'prizeName': _prizeNameController.text.trim(), 'prizeDescription': _prizeDescriptionController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!), 'endDate': Timestamp.fromDate(_endDate!),
        'imageUrls': imageUrls, 'associatedSchoolIds': selectedSchoolIds,
        'prizeEligibilityRule': _prizeEligibilityRule, 'prizeEligibleSchoolIds': prizeEligibleSchoolIds,
      };

      await FirebaseFirestore.instance.collection('campaigns').doc(campaignId).set(campaignData, SetOptions(merge: true));

      final schoolCampaignData = Map<String, dynamic>.from(campaignData)..remove('associatedSchoolIds');
      schoolCampaignData['status'] = 'pending_approval';
      schoolCampaignData['collectedKg'] = 0;

      final schoolsToAdd = selectedSchoolIds.where((id) => !_initialAssociatedSchoolIds.contains(id)).toList();
      final schoolsToRemove = _initialAssociatedSchoolIds.where((id) => !selectedSchoolIds.contains(id)).toList();

      final batch = FirebaseFirestore.instance.batch();

      for (final schoolId in schoolsToAdd) {
        final ref = FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('activeCampaigns').doc(campaignId);
        batch.set(ref, schoolCampaignData);
      }
      for (final schoolId in schoolsToRemove) {
        final ref = FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('activeCampaigns').doc(campaignId);
        batch.delete(ref);
      }
      await batch.commit();

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
    final currentlySelectedSchools = _allSchools.where((s) => _selectedSchools[s.id] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign != null ? 'Editar Campanha' : 'Nova Campanha'),
        actions: [
          // O botão de salvar fica desabilitado durante o carregamento
          IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _saveCampaign),
        ],
      ),
      // Usa-se um Stack para colocar o indicador de progresso SOBRE o formulário
      body: Stack(
        children: [
          // Widget 1: O formulário, que fica por baixo
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da Campanha'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _goalController, decoration: const InputDecoration(labelText: 'Meta (kg)'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _prizeNameController, decoration: const InputDecoration(labelText: 'Nome do Prêmio'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _prizeDescriptionController, decoration: const InputDecoration(labelText: 'Descrição do Prêmio'), maxLines: 3, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: InkWell(onTap: () async { final date = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (date != null) setState(() => _startDate = date); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Data de Início'), child: Text(_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Selecionar')))),
                      const SizedBox(width: 16),
                      Expanded(child: InkWell(onTap: () async { final date = await showDatePicker(context: context, initialDate: _endDate ?? _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime.now(), lastDate: DateTime(2030)); if (date != null) setState(() => _endDate = date); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Data de Fim'), child: Text(_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Selecionar')))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Imagens da Campanha", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._existingImageUrls.map((url) => Stack(children: [ Image.network(url, width: 100, height: 100, fit: BoxFit.cover), Positioned(right: 0, top: 0, child: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _existingImageUrls.remove(url))))])),
                      ..._newImageFiles.map((file) => Stack(children: [ if (kIsWeb) Image.network(file.path, width: 100, height: 100, fit: BoxFit.cover) else Image.file(File(file.path), width: 100, height: 100, fit: BoxFit.cover), Positioned(right: 0, top: 0, child: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _newImageFiles.remove(file))))])),
                      GestureDetector(onTap: _pickImages, child: Container(width: 100, height: 100, color: Colors.grey[800], child: const Icon(Icons.add_a_photo, size: 40)))
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text("Associar Campanha a Escolas", style: Theme.of(context).textTheme.titleMedium),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Wrap(
                      spacing: 8.0,
                      children: [
                        ActionChip(label: const Text("Todas"), onPressed: () => _applySchoolFilter('all')),
                        ActionChip(label: const Text("Nenhuma"), onPressed: () => _applySchoolFilter('none')),
                        ActionChip(label: const Text("Públicas"), onPressed: () => _applySchoolFilter('publica')),
                        ActionChip(label: const Text("Particulares"), onPressed: () => _applySchoolFilter('particular')),
                      ],
                    ),
                  ),
                  _allSchools.isEmpty
                      ? const Center(child: Text("A carregar escolas..."))
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                          child: ListView(
                            children: _allSchools.map((schoolDoc) {
                              final schoolId = schoolDoc.id;
                              final schoolName = (schoolDoc.data() as Map<String, dynamic>)['schoolName'] ?? 'Escola sem nome';
                              return CheckboxListTile(
                                title: Text(schoolName),
                                value: _selectedSchools[schoolId] ?? false,
                                onChanged: (bool? value) { setState(() { _selectedSchools[schoolId] = value ?? false; }); },
                              );
                            }).toList(),
                          ),
                        ),
                  const Divider(height: 40),
                  Text("Elegibilidade do Prêmio", style: Theme.of(context).textTheme.titleMedium),
                  const Text("Defina quais das escolas selecionadas acima poderão ganhar o prêmio.", style: TextStyle(color: Colors.grey)),
                  RadioListTile<String>(title: const Text("Todas as escolas associadas"), value: 'all', groupValue: _prizeEligibilityRule, onChanged: (v) => setState(() => _prizeEligibilityRule = v!)),
                  RadioListTile<String>(title: const Text("Apenas escolas públicas associadas"), value: 'public', groupValue: _prizeEligibilityRule, onChanged: (v) => setState(() => _prizeEligibilityRule = v!)),
                  RadioListTile<String>(title: const Text("Apenas escolas particulares associadas"), value: 'private', groupValue: _prizeEligibilityRule, onChanged: (v) => setState(() => _prizeEligibilityRule = v!)),
                  RadioListTile<String>(title: const Text("Selecionar escolas específicas"), value: 'specific', groupValue: _prizeEligibilityRule, onChanged: (v) => setState(() => _prizeEligibilityRule = v!)),
                  if (_prizeEligibilityRule == 'specific')
                    Container(
                      height: 150,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                      child: ListView(
                        children: currentlySelectedSchools.map((schoolDoc) {
                          final schoolId = schoolDoc.id;
                          final schoolName = (schoolDoc.data() as Map<String, dynamic>)['schoolName'];
                          return CheckboxListTile(
                            title: Text(schoolName),
                            value: _prizeEligibleSchools[schoolId] ?? false,
                            onChanged: (v) => setState(() => _prizeEligibleSchools[schoolId] = v!),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Widget 2: A camada de carregamento, que fica por cima e só aparece se _isLoading for true
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(150), // Fundo semitransparente
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}