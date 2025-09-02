// lib/screens/admin/edit_company_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class Salesperson {
  final String id;
  final String name;
  Salesperson({required this.id, required this.name});
}

class SponsorshipPlan {
  final String id;
  final String name;
  SponsorshipPlan({required this.id, required this.name});
}

class EditCompanyScreen extends StatefulWidget {
  final String? companyId;

  const EditCompanyScreen({super.key, this.companyId});

  @override
  State<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends State<EditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();
  
  bool _isLoading = true;
  bool get _isEditing => widget.companyId != null;

  List<Salesperson> _salespeopleList = [];
  List<SponsorshipPlan> _plansList = [];
  Salesperson? _selectedSalesperson;
  SponsorshipPlan? _selectedPlan;
  String? _selectedStatus;
  
  String? _selectedCompanyType;
  final List<String> _companyTypeOptions = ['Patrocinadora', 'Ponto de Coleta', 'Apoiadora', 'Parceira Logística'];

  final List<String> _statusOptions = ['Prospect', 'Urna Instalada', 'Patrocinador Ativo', 'Inativo'];
  final _cnpjMaskFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadDropdownData();
    if (_isEditing) {
      await _loadCompanyData();
    }
    if(mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      final salespeopleSnapshot = await FirebaseFirestore.instance.collection('salespeople').get();
      _salespeopleList = salespeopleSnapshot.docs.map((doc) {
        return Salesperson(id: doc.id, name: doc.data()['name'] ?? 'Nome não encontrado');
      }).toList();

      final plansSnapshot = await FirebaseFirestore.instance.collection('sponsorship_plans').get();
      _plansList = plansSnapshot.docs.map((doc) {
        return SponsorshipPlan(id: doc.id, name: doc.data()['planName'] ?? 'Nome não encontrado');
      }).toList();
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar vendedores/planos: $e')));
      }
    }
  }

  Future<void> _loadCompanyData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['companyName'] ?? '';
        _cnpjController.text = data['cnpj'] ?? '';
        _selectedStatus = data['sponsorshipStatus'];
        _selectedCompanyType = data['companyType'];

        final salespersonId = data['contactedBySalespersonId'];
        if (salespersonId != null) {
          _selectedSalesperson = _salespeopleList.where((s) => s.id == salespersonId).firstOrNull;
        }

        final planId = data['sponsorshipPlanId'];
        if (planId != null) {
          _selectedPlan = _plansList.where((p) => p.id == planId).firstOrNull;
        }
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados da empresa: $e')));
      }
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final companyData = {
      'companyName': _nameController.text.trim(),
      'cnpj': _cnpjController.text.trim(),
      'contactedBySalespersonId': _selectedSalesperson?.id,
      'sponsorshipPlanId': _selectedPlan?.id,
      'sponsorshipStatus': _selectedStatus,
      'companyType': _selectedCompanyType,
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).update(companyData);
      } else {
        await FirebaseFirestore.instance.collection('companies').add(companyData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa salva com sucesso!'), backgroundColor: Colors.green)
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
        title: Text(_isEditing ? 'Editar Empresa' : 'Adicionar Empresa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveCompany,
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
                    decoration: const InputDecoration(labelText: 'Nome da Empresa'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cnpjController,
                    decoration: const InputDecoration(labelText: 'CNPJ'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cnpjMaskFormatter],
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCompanyType,
                    decoration: const InputDecoration(labelText: 'Tipo de Empresa'),
                    items: _companyTypeOptions.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCompanyType = value),
                    validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // --- CORREÇÃO APLICADA AQUI (VENDEDOR) ---
                  DropdownButtonFormField<Salesperson?>(
                    value: _selectedSalesperson,
                    decoration: const InputDecoration(labelText: 'Vendedor Responsável'),
                    items: [
                      const DropdownMenuItem<Salesperson?>(
                        value: null,
                        child: Text("Nenhum / Deixar em branco", style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                      ..._salespeopleList.map((salesperson) {
                        return DropdownMenuItem<Salesperson>(
                          value: salesperson,
                          child: Text(salesperson.name),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _selectedSalesperson = value),
                  ),
                  const SizedBox(height: 16),

                  // --- CORREÇÃO APLICADA AQUI (PLANO DE PATROCÍNIO) ---
                  DropdownButtonFormField<SponsorshipPlan?>(
                    value: _selectedPlan,
                    decoration: const InputDecoration(labelText: 'Plano de Patrocínio'),
                    items: [
                      const DropdownMenuItem<SponsorshipPlan?>(
                        value: null,
                        child: Text("Nenhum / Deixar em branco", style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                      ..._plansList.map((plan) {
                        return DropdownMenuItem<SponsorshipPlan>(
                          value: plan,
                          child: Text(plan.name),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _selectedPlan = value),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status do Patrocínio'),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedStatus = value),
                    validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null,
                  ),
                ],
              ),
            ),
    );
  }
}