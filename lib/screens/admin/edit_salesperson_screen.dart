// lib/screens/admin/edit_salesperson_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EditSalespersonScreen extends StatefulWidget {
  final String? salespersonId;

  const EditSalespersonScreen({super.key, this.salespersonId});

  @override
  State<EditSalespersonScreen> createState() => _EditSalespersonScreenState();
}

class _EditSalespersonScreenState extends State<EditSalespersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _commissionController = TextEditingController();

  bool _isLoading = true;
  bool get _isEditing => widget.salespersonId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadSalespersonData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _loadSalespersonData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('salespeople').doc(widget.salespersonId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _commissionController.text = (data['commission'] ?? 0).toString();
      }
    } catch (e) {
      if (mounted) _showSnackBar("Erro ao carregar dados do vendedor: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSalesperson() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (mounted) setState(() => _isLoading = true);

    try {
      final commission = double.tryParse(_commissionController.text) ?? 0.0;
      if (commission < 0 || commission > 100) {
        _showSnackBar("A comissão deve ser um valor entre 0 e 100.");
        return;
      }
      
      final data = {
        'name': _nameController.text,
        'email': _emailController.text,
        'commission': commission,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance.collection('salespeople').doc(widget.salespersonId).update(data);
        _showSnackBar("Vendedor atualizado com sucesso!");
      } else {
        // Chamada da Cloud Function para criar o usuário e o documento
        final result = await FirebaseFunctions.instance.httpsCallable('createSalesperson').call({
          'name': _nameController.text,
          'email': _emailController.text,
          'commission': commission,
        });
        if (result.data['success'] == true) {
          _showSnackBar("Vendedor criado com sucesso!");
        } else {
          _showSnackBar("Erro ao criar vendedor: ${result.data['message']}");
        }
      }
      
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      _showSnackBar("Erro ao salvar vendedor: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Vendedor' : 'Adicionar Vendedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSalesperson,
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
                    decoration: const InputDecoration(labelText: 'Nome do Vendedor'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Campo obrigatório';
                      if (!v.contains('@')) return 'E-mail inválido';
                      return null;
                    },
                    enabled: !_isEditing, // E-mail não pode ser editado
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _commissionController,
                    decoration: const InputDecoration(
                      labelText: 'Comissão (%)',
                      hintText: 'Ex: 10',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return 'Campo obrigatório';
                      final commission = double.tryParse(v);
                      if (commission == null || commission < 0 || commission > 100) {
                        return 'A comissão deve ser um número entre 0 e 100';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
    );
  }
}