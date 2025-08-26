// lib/screens/admin/edit_institution_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class EditInstitutionScreen extends StatefulWidget {
  final String? institutionId;

  const EditInstitutionScreen({super.key, this.institutionId});

  @override
  State<EditInstitutionScreen> createState() => _EditInstitutionScreenState();
}

class _EditInstitutionScreenState extends State<EditInstitutionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressNumberController = TextEditingController();

  bool _isLoading = true;
  bool get _isEditing => widget.institutionId != null;

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadInstitutionData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInstitutionData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['institutionName'] ?? '';
        _phoneController.text = data['institutionPhone'] ?? '';
        _cepController.text = data['cep'] ?? '';
        _addressController.text = data['address'] ?? '';
        // Note: O número não está salvo separadamente, então este campo pode ficar vazio
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInstitution() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final institutionData = {
      'institutionName': _nameController.text.trim(),
      'institutionPhone': _phoneController.text.trim(),
      'cep': _cepController.text.trim(),
      'address': '${_addressController.text.trim()}, ${_addressNumberController.text.trim()}',
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('institutions').doc(widget.institutionId).update(institutionData);
      } else {
        await FirebaseFirestore.instance.collection('institutions').add(institutionData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instituição salva com sucesso!'), backgroundColor: Colors.green)
        );
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
        title: Text(_isEditing ? 'Editar Instituição' : 'Adicionar Instituição'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveInstitution,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome da Instituição'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneMaskFormatter],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cepController,
                    decoration: const InputDecoration(labelText: 'CEP'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cepMaskFormatter],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Endereço (Rua)'),
                  ),
                   const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressNumberController,
                    decoration: const InputDecoration(labelText: 'Número'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
    );
  }
}