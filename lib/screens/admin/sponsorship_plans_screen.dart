// lib/screens/admin/sponsorship_plans_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SponsorshipPlansScreen extends StatefulWidget {
  const SponsorshipPlansScreen({super.key});

  @override
  State<SponsorshipPlansScreen> createState() => _SponsorshipPlansScreenState();
}

class _SponsorshipPlansScreenState extends State<SponsorshipPlansScreen> {

  void _showPlanForm({DocumentSnapshot? plan}) {
    final isEditing = plan != null;
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController(text: isEditing ? plan['name'] : '');
    final priceController = TextEditingController(text: isEditing ? (plan['price'] as num?)?.toString() : '');
    final descriptionController = TextEditingController(text: isEditing ? plan['description'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? "Editar Plano" : "Novo Plano de Patrocínio"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nome do Plano (Ex: Ouro)"),
                    validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: "Preço (R\$)"),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return "Número inválido";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: "Benefícios / Descrição"),
                    maxLines: 4,
                    validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final planData = {
                    'name': nameController.text.trim(),
                    'price': double.parse(priceController.text.replaceAll(',', '.')),
                    'description': descriptionController.text.trim(),
                    'isActive': true,
                  };

                  try {
                    if (isEditing) {
                      await FirebaseFirestore.instance.collection('sponsorship_plans').doc(plan.id).update(planData);
                    } else {
                      planData['createdAt'] = Timestamp.now();
                      await FirebaseFirestore.instance.collection('sponsorship_plans').add(planData);
                    }
                    Navigator.pop(context);
                  } catch (e) {
                    // Tratar erro
                  }
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePlan(DocumentSnapshot plan) async {
     final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text("Tem certeza que deseja excluir o plano '${plan['name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('sponsorship_plans').doc(plan.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Planos de Patrocínio"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlanForm(),
        tooltip: "Adicionar Plano",
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sponsorship_plans').orderBy('price', descending: true).snapshots(),
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
                  title: Text(data['name'] ?? 'Plano sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text("R\$ ${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent)),
                  onTap: () => _showPlanForm(plan: plan),
                  onLongPress: () => _deletePlan(plan), // Segurar para apagar
                ),
              );
            },
          );
        },
      ),
    );
  }
}