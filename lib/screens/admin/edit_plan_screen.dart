// lib/screens/admin/edit_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class EditPlanScreen extends StatefulWidget {
  final String? planId;

  const EditPlanScreen({super.key, this.planId});

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  
  bool _isLoading = true;
  bool get _isEditing => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadPlanData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlanData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('sponsorship_plans').doc(widget.planId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['planName'] ?? '';
        _priceController.text = data['price']?.toString() ?? '0';
        _commissionController.text = data['commissionRate']?.toString() ?? '0';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final planData = {
      'planName': _nameController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'commissionRate': double.tryParse(_commissionController.text.trim()) ?? 0.0,
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('sponsorship_plans').doc(widget.planId).update(planData);
      } else {
        await FirebaseFirestore.instance.collection('sponsorship_plans').add(planData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plano salvo com sucesso!'), backgroundColor: Colors.green)
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
        title: Text(_isEditing ? 'Editar Plano' : 'Adicionar Plano'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePlan,
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
                    decoration: const InputDecoration(labelText: 'Nome do Plano'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Preço (ex: 250.00)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _commissionController,
                    decoration: const InputDecoration(labelText: 'Taxa de Comissão (ex: 0.1 para 10%)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                ],
              ),
            ),
    );
  }
}