// lib/screens/admin/edit_school_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Modelo para o dropdown de instituições
class Institution {
  final String id;
  final String name;
  Institution({required this.id, required this.name});
}

class EditSchoolScreen extends StatefulWidget {
  final String? schoolId;

  const EditSchoolScreen({super.key, this.schoolId});

  @override
  State<EditSchoolScreen> createState() => _EditSchoolScreenState();
}

class _EditSchoolScreenState extends State<EditSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressNumberController = TextEditingController();
  final _addressDistrictController = TextEditingController();
  final _addressCityController = TextEditingController();
  final _addressStateController = TextEditingController();

  bool _isLoading = true;
  bool get _isEditing => widget.schoolId != null;

  // Variáveis para o dropdown de instituições
  List<Institution> _institutionsList = [];
  Institution? _selectedInstitution;

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchInstitutions();
    if (_isEditing) {
      await _loadSchoolData();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchInstitutions() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('institutions').orderBy('institutionName').get();
      _institutionsList = snapshot.docs.map((doc) => Institution(id: doc.id, name: doc.data()['institutionName'] ?? 'Nome não encontrado')).toList();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar instituições: $e')));
    }
  }

  Future<void> _loadSchoolData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['schoolName'] ?? '';
        _phoneController.text = data['schoolPhone'] ?? '';
        _cepController.text = data['cep'] ?? '';
        _addressController.text = data['address']?.split(',').first ?? '';
        _addressNumberController.text = data['address']?.split(',').length > 1 ? data['address'].split(',')[1].trim() : '';
        _addressDistrictController.text = data['schoolDistrict'] ?? '';
        _addressCityController.text = data['city'] ?? '';
        _addressStateController.text = data['schoolState'] ?? '';

        final institutionId = data['institutionId'];
        if (institutionId != null) {
          _selectedInstitution = _institutionsList.where((i) => i.id == institutionId).firstOrNull;
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
    }
  }

  Future<void> _saveSchool() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final schoolData = {
      'schoolName': _nameController.text.trim(),
      'schoolPhone': _phoneController.text.trim(),
      'cep': _cepController.text.trim(),
      'address': '${_addressController.text.trim()}, ${_addressNumberController.text.trim()}',
      'schoolDistrict': _addressDistrictController.text.trim(),
      'city': _addressCityController.text.trim(),
      'schoolState': _addressStateController.text.trim(),
      'institutionId': _selectedInstitution?.id, // Salva o ID da instituição
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update(schoolData);
      } else {
        await FirebaseFirestore.instance.collection('schools').add(schoolData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Escola/Faculdade' : 'Adicionar Escola/Faculdade'),
        actions: [ IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _saveSchool) ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- CAMPO DE SELEÇÃO DE INSTITUIÇÃO ADICIONADO AQUI ---
                  if (_institutionsList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text("Nenhuma instituição cadastrada para vincular.", style: TextStyle(color: Colors.amber)),
                    )
                  else
                    DropdownButtonFormField<Institution?>(
                      value: _selectedInstitution,
                      decoration: const InputDecoration(labelText: 'Instituição Responsável (Opcional)'),
                      items: [
                        const DropdownMenuItem<Institution?>(value: null, child: Text("Nenhuma", style: TextStyle(fontStyle: FontStyle.italic))),
                        ..._institutionsList.map((institution) {
                          return DropdownMenuItem<Institution>(value: institution, child: Text(institution.name));
                        }),
                      ],
                      onChanged: (value) => setState(() => _selectedInstitution = value),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da Escola/Faculdade'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Telefone'), keyboardType: TextInputType.phone, inputFormatters: [_phoneMaskFormatter]),
                  const SizedBox(height: 16),
                  TextFormField(controller: _cepController, decoration: const InputDecoration(labelText: 'CEP'), keyboardType: TextInputType.number, inputFormatters: [_cepMaskFormatter]),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Endereço (Rua)')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressNumberController, decoration: const InputDecoration(labelText: 'Número'), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressDistrictController, decoration: const InputDecoration(labelText: 'Bairro')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressCityController, decoration: const InputDecoration(labelText: 'Cidade')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressStateController, decoration: const InputDecoration(labelText: 'Estado')),
                ],
              ),
            ),
    );
  }
}