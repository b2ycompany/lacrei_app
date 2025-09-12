// lib/screens/admin/register_collection_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelos simples para popular os dropdowns
class School {
  final String id;
  final String name;
  School({required this.id, required this.name});
}

class Company {
  final String id;
  final String name;
  Company({required this.id, required this.name});
}

// Enum para controlar a seleção do tipo de entidade
enum EntityType { school, company }

class RegisterCollectionScreen extends StatefulWidget {
  const RegisterCollectionScreen({super.key});

  @override
  State<RegisterCollectionScreen> createState() => _RegisterCollectionScreenState();
}

class _RegisterCollectionScreenState extends State<RegisterCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  EntityType _selectedType = EntityType.school;
  bool _isLoading = true;
  bool _isSaving = false;

  List<School> _schoolsList = [];
  List<Company> _companiesList = [];
  dynamic _selectedEntity; // Pode ser School ou Company

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Carrega ambas as listas de uma vez
      final schoolsSnapshot = await FirebaseFirestore.instance.collection('schools').orderBy('schoolName').get();
      _schoolsList = schoolsSnapshot.docs.map((doc) => School(id: doc.id, name: doc.data()['schoolName'] ?? 'Nome não encontrado')).toList();

      final companiesSnapshot = await FirebaseFirestore.instance.collection('companies').orderBy('companyName').get();
      _companiesList = companiesSnapshot.docs.map((doc) => Company(id: doc.id, name: doc.data()['companyName'] ?? 'Nome não encontrado')).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCollection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0;
    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O peso deve ser maior que zero.'), backgroundColor: Colors.orange));
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      String collectionPath;
      String docId;

      if (_selectedEntity is School) {
        collectionPath = 'schools';
        docId = (_selectedEntity as School).id;
      } else if (_selectedEntity is Company) {
        collectionPath = 'companies';
        docId = (_selectedEntity as Company).id;
      } else {
        throw Exception("Nenhuma entidade selecionada.");
      }

      // Utiliza FieldValue.increment para somar o valor de forma segura
      await FirebaseFirestore.instance.collection(collectionPath).doc(docId).update({
        'totalCollectedKg': FieldValue.increment(weight),
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coleta registrada com sucesso!'), backgroundColor: Colors.green));
        // Limpa o formulário para um novo lançamento
        setState(() {
          _selectedEntity = null;
          _weightController.clear();
          _formKey.currentState?.reset();
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar coleta: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar Coleta'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text('Selecione o tipo de local da coleta:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  SegmentedButton<EntityType>(
                    segments: const [
                      ButtonSegment<EntityType>(value: EntityType.school, label: Text('Escola'), icon: Icon(Icons.school)),
                      ButtonSegment<EntityType>(value: EntityType.company, label: Text('Empresa'), icon: Icon(Icons.business)),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                        _selectedEntity = null; // Limpa a seleção ao trocar o tipo
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  if (_selectedType == EntityType.school)
                    DropdownButtonFormField<School>(
                      value: _selectedEntity,
                      decoration: const InputDecoration(labelText: 'Selecione a Escola/Faculdade'),
                      items: _schoolsList.map((school) => DropdownMenuItem(value: school, child: Text(school.name))).toList(),
                      onChanged: (value) => setState(() => _selectedEntity = value),
                      validator: (v) => v == null ? 'Campo obrigatório' : null,
                    )
                  else
                    DropdownButtonFormField<Company>(
                      value: _selectedEntity,
                      decoration: const InputDecoration(labelText: 'Selecione a Empresa'),
                      items: _companiesList.map((company) => DropdownMenuItem(value: company, child: Text(company.name))).toList(),
                      onChanged: (value) => setState(() => _selectedEntity = value),
                      validator: (v) => v == null ? 'Campo obrigatório' : null,
                    ),
                  
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Peso Coletado (Kg)',
                      hintText: 'Ex: 15.5',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Campo obrigatório';
                      if ((double.tryParse(v.replaceAll(',', '.')) ?? 0.0) <= 0) return 'O peso deve ser maior que zero';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCollection,
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Salvando...' : 'Salvar Coleta'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16)
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}