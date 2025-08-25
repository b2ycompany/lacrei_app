// lib/screens/admin/edit_company_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditCompanyScreen extends StatefulWidget {
  final String? companyId; // Pode ser nulo se estivermos criando uma nova empresa

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

  @override
  void initState() {
    super.initState();
    // Se for modo de edição, busca os dados da empresa no Firebase
    if (_isEditing) {
      _fetchCompanyData();
    } else {
      // Se for modo de criação, já pode exibir o formulário
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCompanyData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['companyName'] ?? '';
        _cnpjController.text = data['cnpj'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados da empresa: $e'), backgroundColor: Colors.red)
      );
    } finally {
      if(mounted){
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCompany() async {
    // Valida o formulário
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final companyData = {
        'companyName': _nameController.text.trim(),
        'cnpj': _cnpjController.text.trim(),
      };

      try {
        if (_isEditing) {
          // ATUALIZA um documento existente
          await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).update(companyData);
        } else {
          // CRIA um novo documento
          await FirebaseFirestore.instance.collection('companies').add(companyData);
        }

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Empresa salva com sucesso!'), backgroundColor: Colors.green)
          );
          Navigator.of(context).pop(); // Volta para a tela de listagem
        }

      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar empresa: $e'), backgroundColor: Colors.red)
          );
        }
      } finally {
        if(mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    super.dispose();
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
            tooltip: 'Salvar',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nome da Empresa'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira o nome da empresa.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cnpjController,
                      decoration: const InputDecoration(labelText: 'CNPJ'),
                      // Validação simples, pode ser melhorada com um validador de CNPJ
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira o CNPJ.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveCompany,
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}