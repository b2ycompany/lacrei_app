// lib/screens/admin/collection_route_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CollectionRouteScreen extends StatefulWidget {
  const CollectionRouteScreen({super.key});

  @override
  State<CollectionRouteScreen> createState() => _CollectionRouteScreenState();
}

class _CollectionRouteScreenState extends State<CollectionRouteScreen> {
  // Guarda os IDs das urnas selecionadas para a rota
  final Set<String> _selectedUrnIds = {};
  // Guarda a rota gerada para exibição
  List<DocumentSnapshot> _generatedRoute = [];
  bool _isRouteGenerated = false;

  Future<void> _markAsCollected(String urnId) async {
    try {
      await FirebaseFirestore.instance.collection('urns').doc(urnId).update({
        'status': 'Na Localização',
        'lastFullTimestamp': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Urna marcada como 'coletada'."), backgroundColor: Colors.green),
        );
        // Remove da rota gerada para atualizar a UI
        setState(() {
          _generatedRoute.removeWhere((doc) => doc.id == urnId);
          if (_generatedRoute.isEmpty) {
            _isRouteGenerated = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao atualizar status: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _generateRoute(List<DocumentSnapshot> fullUrns) {
    setState(() {
      _generatedRoute = fullUrns.where((urn) => _selectedUrnIds.contains(urn.id)).toList();
      _isRouteGenerated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerar Rota de Coleta"),
        // Se uma rota estiver gerada, mostra um botão para voltar à seleção
        leading: _isRouteGenerated 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _isRouteGenerated = false;
                _selectedUrnIds.clear();
              }),
            )
          : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urns')
            .where('status', isEqualTo: 'Cheia')
            .orderBy('lastFullTimestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar as urnas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma urna cheia para coletar."));
          }

          final fullUrns = snapshot.data!.docs;

          // Se a rota ainda não foi gerada, mostra a tela de seleção
          if (!_isRouteGenerated) {
            return _buildUrnSelectionView(fullUrns);
          } else {
            // Se a rota foi gerada, mostra a lista da rota
            return _buildGeneratedRouteView();
          }
        },
      ),
    );
  }

  Widget _buildUrnSelectionView(List<DocumentSnapshot> fullUrns) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Selecione as urnas para a rota de hoje", style: Theme.of(context).textTheme.headlineSmall),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: fullUrns.length,
            itemBuilder: (context, index) {
              final urnDoc = fullUrns[index];
              final data = urnDoc.data() as Map<String, dynamic>;
              return CheckboxListTile(
                title: Text(data['urnCode'] ?? 'Código da Urna'),
                subtitle: Text(data['assignedToName'] ?? 'Local não informado'),
                value: _selectedUrnIds.contains(urnDoc.id),
                onChanged: (isSelected) {
                  setState(() {
                    if (isSelected == true) {
                      _selectedUrnIds.add(urnDoc.id);
                    } else {
                      _selectedUrnIds.remove(urnDoc.id);
                    }
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.route),
            label: Text("Gerar Rota (${_selectedUrnIds.length})"),
            onPressed: _selectedUrnIds.isEmpty ? null : () => _generateRoute(fullUrns),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedRouteView() {
    if (_generatedRoute.isEmpty) {
      return const Center(child: Text("Nenhuma urna selecionada para esta rota."));
    }
    return ListView.builder(
      itemCount: _generatedRoute.length,
      itemBuilder: (context, index) {
        final urnDoc = _generatedRoute[index];
        final data = urnDoc.data() as Map<String, dynamic>;
        final timestamp = data['lastFullTimestamp'] as Timestamp?;
        final order = index + 1;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$order. ${data['urnCode'] ?? ''}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Local: ${data['assignedToName'] ?? 'Não informado'}"),
                Text("Sinalizada em: ${timestamp != null ? DateFormat('dd/MM HH:mm').format(timestamp.toDate()) : 'N/A'}"),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text("Marcar como Coletada"),
                    onPressed: () => _markAsCollected(urnDoc.id),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}