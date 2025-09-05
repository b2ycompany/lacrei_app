// lib/screens/admin/urn_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

class UrnManagementScreen extends StatefulWidget {
  const UrnManagementScreen({super.key});

  @override
  State<UrnManagementScreen> createState() => _UrnManagementScreenState();
}

class _UrnManagementScreenState extends State<UrnManagementScreen> {
  final _urnCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  String? _selectedAssignmentType;
  String? _selectedAssignmentId;
  String? _selectedAssignmentName;

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Serviços de localização desativados.", isError: true);
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Permissões de localização negadas.", isError: true);
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Permissões de localização negadas permanentemente. Por favor, habilite nas configurações.", isError: true);
        return null;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return position;
    } on PlatformException catch (e) {
      _showSnackBar("Erro de plataforma ao obter localização: ${e.message}", isError: true);
      return null;
    } catch (e) {
      _showSnackBar("Ocorreu um erro ao obter a localização: $e", isError: true);
      return null;
    }
  }
  
  void _showAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Atribuir Urna a..."),
          content: SizedBox(
            width: double.maxFinite,
            child: DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: "Escolas"),
                      Tab(text: "Empresas"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAssignmentList('schools'),
                        _buildAssignmentList('companies'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text("Erro ao carregar os dados."));

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final name = data[collection == 'schools' ? 'schoolName' : 'companyName'];
            return ListTile(
              title: Text(name ?? 'Nome não disponível'),
              onTap: () {
                setState(() {
                  _selectedAssignmentType = collection;
                  _selectedAssignmentId = docs[index].id;
                  _selectedAssignmentName = name;
                });
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addUrn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final urnCode = _urnCodeController.text.trim();
        final position = await _getCurrentLocation();
        if (position == null) {
          setState(() => _isLoading = false);
          return;
        }

        await FirebaseFirestore.instance.collection('urns').add({
          'urnCode': urnCode,
          'assignedToId': _selectedAssignmentId,
          'assignedToName': _selectedAssignmentName,
          'assignmentType': _selectedAssignmentType,
          'status': 'Vazia',
          'createdAt': FieldValue.serverTimestamp(),
          'latitude': position.latitude,
          'longitude': position.longitude,
        });

        _showSnackBar("Urna '$urnCode' adicionada com sucesso!", isError: false);
        _urnCodeController.clear();
        setState(() {
          _selectedAssignmentId = null;
          _selectedAssignmentName = null;
          _selectedAssignmentType = null;
        });

      } catch (e) {
        _showSnackBar("Erro ao adicionar urna: $e", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markUrnAsFull(DocumentSnapshot urnDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Sinalização"),
        content: Text("Deseja mesmo marcar a urna '${urnDoc['urnCode']}' como cheia?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirmar")),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('urns').doc(urnDoc.id).update({
          'status': 'Cheia',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        _showSnackBar("Urna marcada como cheia!", isError: false);
      } catch (e) {
        _showSnackBar("Erro ao marcar urna como cheia: $e", isError: true);
      }
    }
  }

  @override
  void dispose() {
    _urnCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão de Urnas"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text("Cadastrar Nova Urna", style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urnCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Código da Urna',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'O código da urna é obrigatório.' : null,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(_selectedAssignmentName ?? "Selecionar Local de Atribuição"),
                        onTap: _showAssignmentDialog,
                        trailing: _selectedAssignmentName != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedAssignmentId = null;
                                  _selectedAssignmentName = null;
                                  _selectedAssignmentType = null;
                                });
                              },
                            )
                          : null,
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: _addUrn,
                              icon: const Icon(Icons.add_box),
                              label: const Text("Adicionar Urna"),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 40),
            Text("Urnas em Campo", style: Theme.of(context).textTheme.headlineSmall),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('urns').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text("Erro ao carregar as urnas."));
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final currentStatus = data['status'] ?? 'Desconhecido';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.qr_code, color: Colors.blueGrey),
                        title: Text(data['urnCode'] ?? 'Código indisponível', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Local: ${data['assignedToName'] ?? 'Não atribuído'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(currentStatus),
                              backgroundColor: currentStatus == 'Cheia' ? Colors.redAccent : Colors.grey,
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                            if (currentStatus != 'Cheia')
                              IconButton(
                                icon: const Icon(Icons.report, color: Colors.orange),
                                onPressed: () => _markUrnAsFull(snapshot.data!.docs[index]),
                                tooltip: 'Marcar como Cheia',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}