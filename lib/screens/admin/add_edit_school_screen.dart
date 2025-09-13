// lib/screens/admin/add_edit_school_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Modelo para o dropdown de instituições
class Institution {
  final String id;
  final String name;
  Institution({required this.id, required this.name});
}

class AddEditSchoolScreen extends StatefulWidget {
  final DocumentSnapshot? school;

  const AddEditSchoolScreen({super.key, this.school});

  @override
  State<AddEditSchoolScreen> createState() => _AddEditSchoolScreenState();
}

class _AddEditSchoolScreenState extends State<AddEditSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _adminNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _cepController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  
  // Controllers para metas
  late TextEditingController _goalKgController;
  late TextEditingController _goalStartDateController;
  late TextEditingController _goalEndDateController;

  String _selectedSchoolType = 'particular';
  bool _isLoading = true;
  bool get _isEditing => widget.school != null;

  List<Institution> _institutionsList = [];
  Institution? _selectedInstitution;
  DateTime? _startDate;
  DateTime? _endDate;

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    // Carrega a lista de instituições primeiro
    await _fetchInstitutions();
    
    // Agora popula o formulário com os dados existentes (se houver)
    _populateFormFields();

    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchInstitutions() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('institutions').orderBy('institutionName').get();
      _institutionsList = snapshot.docs.map((doc) => Institution(id: doc.id, name: doc.data()['institutionName'] ?? 'Nome não encontrado')).toList();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar instituições: $e')));
    }
  }

  void _populateFormFields() {
    final data = widget.school?.data() as Map<String, dynamic>?;

    _nameController = TextEditingController(text: data?['schoolName'] ?? '');
    _adminNameController = TextEditingController(text: data?['adminName'] ?? '');
    _contactPhoneController = TextEditingController(text: data?['contactPhone'] ?? '');
    _cepController = TextEditingController(text: data?['cep'] ?? '');
    _addressController = TextEditingController(text: data?['address'] ?? '');
    _cityController = TextEditingController(text: data?['city'] ?? '');
    _selectedSchoolType = data?['schoolType'] ?? 'particular';

    // Popula a instituição selecionada se estiver a editar
    final institutionId = data?['institutionId'];
    if (institutionId != null) {
      _selectedInstitution = _institutionsList.where((i) => i.id == institutionId).firstOrNull;
    }
    
    // Popula os campos de meta
    _goalKgController = TextEditingController(text: (data?['goalKg'] as num?)?.toString() ?? '');
    _startDate = (data?['goalStartDate'] as Timestamp?)?.toDate();
    _endDate = (data?['goalEndDate'] as Timestamp?)?.toDate();
    _goalStartDateController = TextEditingController(text: _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : '');
    _goalEndDateController = TextEditingController(text: _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _adminNameController.dispose();
    _contactPhoneController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _goalKgController.dispose();
    _goalStartDateController.dispose();
    _goalEndDateController.dispose();
    super.dispose();
  }

  Future<void> _saveSchool() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final schoolData = {
        'schoolName': _nameController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'cep': _cepController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'schoolType': _selectedSchoolType,
        'institutionId': _selectedInstitution?.id, // Salva o ID da instituição
        'totalCollectedKg': _isEditing ? (widget.school!.data() as Map<String, dynamic>)['totalCollectedKg'] ?? 0 : 0,
        
        'goalKg': double.tryParse(_goalKgController.text.replaceAll(',', '.')) ?? 0.0,
        'goalStartDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
        'goalEndDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
      };

      if (_isEditing) {
        await FirebaseFirestore.instance.collection('schools').doc(widget.school!.id).update(schoolData);
      } else {
        schoolData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('schools').add(schoolData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escola salva com sucesso!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar escola: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _goalStartDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _endDate = picked;
          _goalEndDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Escola" : "Adicionar Escola/Faculdade"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _saveSchool),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (_institutionsList.isNotEmpty)
                  DropdownButtonFormField<Institution?>(
                    value: _selectedInstitution,
                    decoration: const InputDecoration(labelText: 'Instituição Responsável (Opcional)'),
                    items: [
                      const DropdownMenuItem<Institution?>(value: null, child: Text("Nenhuma", style: TextStyle(fontStyle: FontStyle.italic))),
                      ..._institutionsList.map((institution) => DropdownMenuItem<Institution>(value: institution, child: Text(institution.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedInstitution = v),
                  ),
                
                const SizedBox(height: 16),
                TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da Escola/Faculdade'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSchoolType,
                  decoration: const InputDecoration(labelText: 'Tipo de Escola'),
                  items: const [
                    DropdownMenuItem(value: 'municipal', child: Text('Municipal')),
                    DropdownMenuItem(value: 'estadual', child: Text('Estadual')),
                    DropdownMenuItem(value: 'particular', child: Text('Particular')),
                    DropdownMenuItem(value: 'faculdade', child: Text('Faculdade')),
                  ],
                  onChanged: (v) => setState(() => _selectedSchoolType = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _adminNameController, decoration: const InputDecoration(labelText: 'Nome do Admin da Escola'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _contactPhoneController, decoration: const InputDecoration(labelText: 'Telefone de Contato'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _cepController, decoration: const InputDecoration(labelText: 'CEP'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Endereço Completo (Rua, Número, Bairro)'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                
                const Divider(height: 32),
                const Text("Meta Trimestral", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(controller: _goalKgController, decoration: const InputDecoration(labelText: 'Meta de Arrecadação (Kg)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _goalStartDateController, decoration: const InputDecoration(labelText: 'Data de Início da Meta'), readOnly: true, onTap: () => _selectDate(context, true))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _goalEndDateController, decoration: const InputDecoration(labelText: 'Data de Fim da Meta'), readOnly: true, onTap: () => _selectDate(context, false))),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}