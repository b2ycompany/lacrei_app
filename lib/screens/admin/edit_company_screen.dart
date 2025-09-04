// lib/screens/admin/edit_company_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class Institution {
  final String id;
  final String name;
  Institution({required this.id, required this.name});
}

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
  List<Institution> _institutionsList = [];
  
  Institution? _selectedInstitution;
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
    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDropdownData() async {
    try {
      final salespeopleSnapshot = await FirebaseFirestore.instance.collection('salespeople').get();
      _salespeopleList = salespeopleSnapshot.docs.map((doc) => Salesperson(id: doc.id, name: doc.data()['name'] ?? '')).toList();

      final plansSnapshot = await FirebaseFirestore.instance.collection('sponsorship_plans').get();
      _plansList = plansSnapshot.docs.map((doc) => SponsorshipPlan(id: doc.id, name: doc.data()['planName'] ?? '')).toList();

      final institutionsSnapshot = await FirebaseFirestore.instance.collection('institutions').get();
      _institutionsList = institutionsSnapshot.docs.map((doc) => Institution(id: doc.id, name: doc.data()['institutionName'] ?? '')).toList();

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados de seleção: $e')));
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

        final institutionId = data['institutionId'];
        if (institutionId != null) {
          _selectedInstitution = _institutionsList.where((i) => i.id == institutionId).firstOrNull;
        }

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
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados da empresa: $e')));
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
      'institutionId': _selectedInstitution?.id, // Salva o ID da instituição
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).update(companyData);
      } else {
        await FirebaseFirestore.instance.collection('companies').add(companyData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa salva com sucesso!'), backgroundColor: Colors.green));
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
        actions: [ IconButton(icon: const Icon(Icons.save), onPressed: _isLoading ? null : _saveCompany) ],
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
                        ..._institutionsList.map((institution) => DropdownMenuItem<Institution>(value: institution, child: Text(institution.name))),
                      ],
                      onChanged: (value) => setState(() => _selectedInstitution = value),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da Empresa'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _cnpjController, decoration: const InputDecoration(labelText: 'CNPJ'), keyboardType: TextInputType.number, inputFormatters: [_cnpjMaskFormatter], validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(value: _selectedCompanyType, decoration: const InputDecoration(labelText: 'Tipo de Empresa'), items: _companyTypeOptions.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (value) => setState(() => _selectedCompanyType = value), validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Salesperson?>(value: _selectedSalesperson, decoration: const InputDecoration(labelText: 'Vendedor Responsável'), items: [const DropdownMenuItem<Salesperson?>(value: null, child: Text("Nenhum / Deixar em branco", style: TextStyle(fontStyle: FontStyle.italic))), ..._salespeopleList.map((salesperson) => DropdownMenuItem<Salesperson>(value: salesperson, child: Text(salesperson.name)))], onChanged: (value) => setState(() => _selectedSalesperson = value)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SponsorshipPlan?>(value: _selectedPlan, decoration: const InputDecoration(labelText: 'Plano de Patrocínio'), items: [const DropdownMenuItem<SponsorshipPlan?>(value: null, child: Text("Nenhum / Deixar em branco", style: TextStyle(fontStyle: FontStyle.italic))), ..._plansList.map((plan) => DropdownMenuItem<SponsorshipPlan>(value: plan, child: Text(plan.name)))], onChanged: (value) => setState(() => _selectedPlan = value)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(value: _selectedStatus, decoration: const InputDecoration(labelText: 'Status do Patrocínio'), items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(), onChanged: (value) => setState(() => _selectedStatus = value), validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null),
                ],
              ),
            ),
    );
  }
}