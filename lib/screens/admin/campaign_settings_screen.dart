// lib/screens/admin/campaign_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CampaignManagementScreen extends StatefulWidget {
  const CampaignManagementScreen({super.key});

  @override
  State<CampaignManagementScreen> createState() => _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  
  String _getCampaignStatus(Timestamp start, Timestamp end) {
    final now = Timestamp.now();
    if (now.compareTo(start) >= 0 && now.compareTo(end) <= 0) {
      return 'Ativa';
    } else if (now.compareTo(end) > 0) {
      return 'Finalizada';
    } else {
      return 'Agendada';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ativa': return Colors.green;
      case 'Finalizada': return Colors.grey;
      case 'Agendada': return Colors.blue;
      default: return Colors.black;
    }
  }

  void _showCampaignForm({DocumentSnapshot? campaign}) {
    final isEditing = campaign != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: isEditing ? campaign!['name'] : '');
    final goalController = TextEditingController(text: isEditing ? campaign!['goalKg'].toString() : '');
    DateTime startDate = isEditing ? (campaign!['startDate'] as Timestamp).toDate() : DateTime.now();
    DateTime endDate = isEditing ? (campaign!['endDate'] as Timestamp).toDate() : DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(isEditing ? "Editar Campanha" : "Nova Campanha", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Nome da Campanha"),
                        validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: goalController,
                        decoration: const InputDecoration(labelText: "Meta (kg)"),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Campo obrigatório';
                          if (double.tryParse(value) == null) return 'Número inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text("Data de Início"),
                              TextButton(
                                child: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                                onPressed: () async {
                                  final pickedDate = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                  if (pickedDate != null) {
                                    setModalState(() => startDate = pickedDate);
                                  }
                                },
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text("Data de Fim"),
                              TextButton(
                                child: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                                onPressed: () async {
                                  final pickedDate = await showDatePicker(context: context, initialDate: endDate, firstDate: startDate, lastDate: DateTime(2030));
                                  if (pickedDate != null) {
                                    setModalState(() => endDate = pickedDate);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final data = {
                              'name': nameController.text,
                              'goalKg': double.tryParse(goalController.text) ?? 0,
                              'startDate': Timestamp.fromDate(startDate),
                              'endDate': Timestamp.fromDate(endDate),
                            };
                            if (isEditing) {
                              await FirebaseFirestore.instance.collection('campaigns').doc(campaign.id).update(data);
                            } else {
                              await FirebaseFirestore.instance.collection('campaigns').add(data);
                            }
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        child: Text(isEditing ? "Salvar Alterações" : "Criar Campanha", style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Campanhas")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCampaignForm(),
        tooltip: 'Nova Campanha',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('campaigns').orderBy('startDate', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar campanhas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma campanha criada.\nClique no botão '+' para adicionar uma."));
          }
          
          final campaigns = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Espaço para o Floating Action Button
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              final data = campaign.data() as Map<String, dynamic>;
              final status = _getCampaignStatus(data['startDate'], data['endDate']);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Meta: ${data['goalKg']} kg | Prazo: ${DateFormat('dd/MM/yy').format((data['startDate'] as Timestamp).toDate())} a ${DateFormat('dd/MM/yy').format((data['endDate'] as Timestamp).toDate())}"),
                  trailing: Chip(
                    label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: _getStatusColor(status),
                  ),
                  onTap: () => _showCampaignForm(campaign: campaign),
                ),
              );
            },
          );
        },
      ),
    );
  }
}