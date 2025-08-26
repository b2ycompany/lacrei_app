// lib/screens/admin/edit_salesperson_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _loadSalespersonData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('salespeople').doc(widget.salespersonId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSalesperson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final salespersonData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('salespeople').doc(widget.salespersonId).update(salespersonData);
      } else {
        await FirebaseFirestore.instance.collection('salespeople').add(salespersonData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendedor salvo com sucesso!'), backgroundColor: Colors.green)
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
                  ),
                ],
              ),
            ),
    );
  }
}