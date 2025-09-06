import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollectionRouteScreen extends StatefulWidget {
  const CollectionRouteScreen({super.key});

  @override
  State<CollectionRouteScreen> createState() => _CollectionRouteScreenState();
}

class _CollectionRouteScreenState extends State<CollectionRouteScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  final Completer<GoogleMapController> _mapController = Completer();
  final _urnCodeController = TextEditingController();

  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(-23.55052, -46.633308),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      await _getCurrentLocation(animate: false);
      await _loadUrnsAndRoute();
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnackBar("Erro de plataforma ao obter localização: ${e.message}", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Erro ao inicializar a tela: $e", isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  Future<Position?> _getCurrentLocation({bool animate = true}) async {
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
          _showSnackBar("Permissão de localização negada.", isError: true);
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Permissão de localização negada permanentemente.", isError: true);
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      
      if (animate && _mapController.isCompleted) {
        final controller = await _mapController.future;
        await controller.animateCamera(CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ));
      }
      return position;
    } catch (e) {
      _showSnackBar("Erro ao obter a localização atual: $e", isError: true);
      return null;
    }
  }

  Future<void> _loadUrnsAndRoute() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não autenticado.");
      }

      // **Correção principal:** Verifique o tipo de perfil do usuário para decidir a consulta.
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final profileType = userDoc.data()?['profileType'];

      QuerySnapshot urnsSnapshot;
      if (profileType == 'admin') {
        // Se for admin, mostre todas as urnas.
        urnsSnapshot = await FirebaseFirestore.instance.collection('urns').get();
      } else {
        // Se for colaborador ou outro, mostre apenas as urnas atribuídas a ele.
        urnsSnapshot = await FirebaseFirestore.instance
            .collection('urns')
            .where('assignedToId', isEqualTo: user.uid)
            .get();
      }

      final newMarkers = <Marker>{};
      final urnLocations = <LatLng>[];

      for (var doc in urnsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['location'] != null && data['location']['lat'] != null && data['location']['lng'] != null) {
          final latLng = LatLng(
            data['location']['lat'],
            data['location']['lng'],
          );
          urnLocations.add(latLng);

          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: latLng,
            infoWindow: InfoWindow(
              title: 'Urna: ${data['urnCode'] ?? 'N/A'}',
              snippet: 'Status: ${data['status'] ?? 'N/A'}',
            ),
            icon: data['status'] == 'Cheia'
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          );
          newMarkers.add(marker);
        }
      }
      
      if (_currentPosition != null) {
        final currentPositionLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        newMarkers.add(
          Marker(
            markerId: const MarkerId('my_location'),
            position: currentPositionLatLng,
            infoWindow: const InfoWindow(title: 'Sua Localização'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      }

      setState(() {
        _markers = newMarkers;
      });

    } catch (e) {
      _showSnackBar("Erro ao carregar as urnas: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddUrnDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Adicionar Nova Urna"),
          content: TextField(
            controller: _urnCodeController,
            decoration: const InputDecoration(labelText: 'Código da Urna'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: _addUrn,
              child: const Text("Adicionar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addUrn() async {
    final code = _urnCodeController.text.trim();
    if (code.isEmpty) {
      Navigator.of(context).pop();
      _showSnackBar("O código da urna não pode ser vazio.", isError: true);
      return;
    }

    Navigator.of(context).pop();
    _showSnackBar("Adicionando urna...", isError: false);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não autenticado.");
      }

      final position = await _getCurrentLocation(animate: false);
      if (position == null) {
        _showSnackBar("Não foi possível obter a localização para adicionar a urna.", isError: true);
        return;
      }

      // **Lógica para adicionar a nova urna ao Firestore**
      await FirebaseFirestore.instance.collection('urns').add({
        'urnCode': code,
        'location': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'status': 'Vazia', // Status inicial
        'assignedToId': user.uid, // Atribui a urna ao usuário atual
        'assignedToName': user.displayName ?? 'N/A', // Nome do usuário
        'createdAt': FieldValue.serverTimestamp(),
      });
      _urnCodeController.clear();
      _showSnackBar("Urna '$code' adicionada com sucesso!", isError: false);
      await _loadUrnsAndRoute(); // Recarrega o mapa para mostrar a nova urna.
    } catch (e) {
      _showSnackBar("Erro ao adicionar a urna: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastreamento de Urnas'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kDefaultPosition,
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black87,
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _isLoading ? null : _showAddUrnDialog,
            tooltip: 'Adicionar Urna',
            heroTag: 'addUrn',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _isLoading ? null : _getCurrentLocation,
            tooltip: 'Minha Localização',
            heroTag: 'myLocation',
            child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) 
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}