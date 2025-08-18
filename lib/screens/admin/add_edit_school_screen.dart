// lib/screens/admin/add_edit_school_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddEditSchoolScreen extends StatefulWidget {
  final DocumentSnapshot? school;

  const AddEditSchoolScreen({super.key, this.school});

  @override
  State<AddEditSchoolScreen> createState() => _AddEditSchoolScreenState();
}

class _AddEditSchoolScreenState extends State<AddEditSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _cepController;
  late TextEditingController _addressController;
  // NOVOS CONTROLLERS
  late TextEditingController _adminNameController;
  late TextEditingController _contactPhoneController;

  String _selectedSchoolType = 'particular';
  bool _isLoading = false;

  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final data = widget.school?.data() as Map<String, dynamic>?;
    _nameController = TextEditingController(text: data?['schoolName']);
    _cityController = TextEditingController(text: data?['city']);
    _cepController = TextEditingController(text: data?['cep']);
    _addressController = TextEditingController(text: data?['address']);
    _adminNameController = TextEditingController(text: data?['adminName']);
    _contactPhoneController = TextEditingController(text: data?['contactPhone']);
    _selectedSchoolType = data?['schoolType'] ?? 'particular';
    _cepFocusNode.addListener(() {
      if (!_cepFocusNode.hasFocus) _fetchAddressFromCep();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _adminNameController.dispose();
    _contactPhoneController.dispose();
    _cepFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAddressFromCep() async {
    final cep = _cepMaskFormatter.getUnmaskedText();
    if (cep.length != 8) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cep/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] != true) {
          setState(() {
            _addressController.text = data['logradouro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
          });
        }
      }
    } catch (e) {
      // Tratar erro
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchool() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final schoolData = {
        'schoolName': _nameController.text.trim(),
        'schoolType': _selectedSchoolType,
        'city': _cityController.text.trim(),
        'cep': _cepController.text.trim(),
        'address': _addressController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'totalCollectedKg': widget.school != null ? (widget.school!.data() as Map<String, dynamic>)['totalCollectedKg'] : 0,
      };

      if (widget.school != null) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar escola: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.school != null ? "Editar Escola" : "Adicionar Escola"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _saveSchool),
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
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da Escola'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  // CAMPO ATUALIZADO PARA DROPDOWN
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
                  // NOVOS CAMPOS
                  TextFormField(controller: _adminNameController, decoration: const InputDecoration(labelText: 'Nome do Admin da Escola'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _contactPhoneController, decoration: const InputDecoration(labelText: 'Telefone de Contato'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _cepController, focusNode: _cepFocusNode, decoration: const InputDecoration(labelText: 'CEP'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Endereço Completo (Rua, Número, Bairro)'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSchool,
                    child: Text(widget.school != null ? 'Salvar Alterações' : 'Adicionar Escola'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}