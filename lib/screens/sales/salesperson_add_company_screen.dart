// lib/screens/sales/salesperson_add_company_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import necessário para pegar o usuário logado

class SalespersonAddCompanyScreen extends StatefulWidget {
  // Não precisamos mais passar o vendedor, pois vamos pegá-lo do usuário logado
  const SalespersonAddCompanyScreen({super.key});

  @override
  State<SalespersonAddCompanyScreen> createState() => _SalespersonAddCompanyScreenState();
}

class _SalespersonAddCompanyScreenState extends State<SalespersonAddCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedCompanyType;

  final List<String> _companyTypeOptions = ['Patrocinadora', 'Ponto de Coleta', 'Apoiadora', 'Parceira Logística'];
  final _cnpjMaskFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    final salespersonId = FirebaseAuth.instance.currentUser?.uid;
    if (salespersonId == null) {
      _showSnackBar('Erro: Vendedor não autenticado. Por favor, faça login novamente.');
      return;
    }

    setState(() => _isLoading = true);

    final companyData = {
      'companyName': _nameController.text.trim(),
      'cnpj': _cnpjController.text.trim(),
      'companyType': _selectedCompanyType,
      
      // Lógica automática (Melhores Práticas)
      'contactedBySalespersonId': salespersonId, // Vincula a empresa ao vendedor logado
      'sponsorshipStatus': 'Prospect', // Status inicial padrão
      'sponsorshipPlanId': null, // Plano será definido pelo Super Admin depois
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('companies').add(companyData);
      
      if (mounted) {
        _showSnackBar('Empresa cadastrada com sucesso!', isError: false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erro ao salvar: ${e.toString()}');
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Nova Empresa'),
      ),
      body: Stack(
        children: [
          Form(
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
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCompany,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Salvar Empresa'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}