// lib/screens/admin/sponsorship_plans_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SponsorshipPlansScreen extends StatefulWidget {
  const SponsorshipPlansScreen({super.key});

  @override
  State<SponsorshipPlansScreen> createState() => _SponsorshipPlansScreenState();
}

class _SponsorshipPlansScreenState extends State<SponsorshipPlansScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  void _showPlanForm({DocumentSnapshot? plan}) {
    final isEditing = plan != null;
    
    if (isEditing) {
      final data = plan.data() as Map<String, dynamic>;
      // CORREÇÃO: Lendo do campo 'planName'
      _nameController.text = data['planName'] ?? '';
      _priceController.text = (data['price'] as num?)?.toString() ?? '';
      _descriptionController.text = data['description'] ?? '';
    } else {
      _nameController.clear();
      _priceController.clear();
      _descriptionController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: Text(isEditing ? "Editar Plano" : "Novo Plano de Patrocínio"),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Nome do Plano (Ex: Ouro)"),
                        validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
                      ),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: "Preço (R\$)"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v!.isEmpty) return "Campo obrigatório";
                          if (double.tryParse(v.replaceAll(',', '.')) == null) return "Insira um número válido";
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: "Descrição"),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setStateInDialog(() => _isSaving = true);
                            await _savePlan(isEditing: isEditing, plan: plan);
                            setStateInDialog(() => _isSaving = false);
                            if (mounted) Navigator.of(context).pop();
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3))
                      : Text(isEditing ? "Salvar" : "Adicionar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _savePlan({required bool isEditing, DocumentSnapshot? plan}) async {
    try {
      final data = {
        // CORREÇÃO: Salvando no campo 'planName'
        'planName': _nameController.text.trim(),
        'price': double.parse(_priceController.text.replaceAll(',', '.')),
        'description': _descriptionController.text.trim(),
      };

      if (isEditing) {
        // ATENÇÃO: Verifique se o nome da coleção no seu Firestore é 'sponsorship_plans'
        await FirebaseFirestore.instance.collection('sponsorship_plans').doc(plan!.id).update(data);
        _showSnackBar("Plano atualizado com sucesso!", isError: false);
      } else {
        await FirebaseFirestore.instance.collection('sponsorship_plans').add(data);
        _showSnackBar("Novo plano adicionado!", isError: false);
      }
    } catch (e) {
      _showSnackBar("Erro ao salvar plano: $e", isError: true);
    }
  }

  Future<void> _deletePlan(DocumentSnapshot plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        // CORREÇÃO: Lendo do campo 'planName'
        content: Text("Tem certeza que deseja excluir o plano de patrocínio '${plan['planName']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('sponsorship_plans').doc(plan.id).delete();
        _showSnackBar("Plano excluído com sucesso!", isError: false);
      } catch (e) {
        _showSnackBar("Erro ao excluir plano: $e", isError: true);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Planos de Patrocínio"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPlanForm(),
            tooltip: 'Adicionar novo plano',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ATENÇÃO: Verifique se o nome da coleção no seu Firestore é 'sponsorship_plans'
        stream: FirebaseFirestore.instance.collection('sponsorship_plans').orderBy('price').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar os planos."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum plano de patrocínio cadastrado."));
          }

          final plans = snapshot.data!.docs;

          return ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final data = plan.data() as Map<String, dynamic>;
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  // CORREÇÃO: Lendo do campo 'planName'
                  title: Text(data['planName'] ?? 'Plano sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("R\$ ${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deletePlan(plan),
                      ),
                    ],
                  ),
                  onTap: () => _showPlanForm(plan: plan),
                ),
              );
            },
          );
        },
      ),
    );
  }
}