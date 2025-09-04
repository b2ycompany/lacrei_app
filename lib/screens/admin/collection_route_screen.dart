import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final Completer<GoogleMapController> _mapController = Completer();

  // Posição Padrão (São Paulo) caso a localização não seja obtida
  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(-23.55052, -46.633308),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// Inicializa a tela buscando a localização e as urnas.
  Future<void> _initializeScreen() async {
    try {
      await _getCurrentLocation(animate: false);
      await _loadUrns();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Busca a localização atual do usuário e move a câmera.
  Future<void> _getCurrentLocation({bool animate = true}) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) throw Exception("Permissão de localização negada.");
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      if (mounted) setState(() => _currentPosition = position);

      if (animate) {
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        )));
      }
    } catch (e) {
      if (mounted) _showSnackBar("Erro ao obter localização: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carrega as urnas do Firestore e as converte em marcadores no mapa.
  Future<void> _loadUrns() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('urns').get();
      final Set<Marker> markers = {};

      for (var urnDoc in snapshot.docs) {
        final data = urnDoc.data();
        // O campo 'location' no Firestore deve ser do tipo GeoPoint
        if (data['location'] is GeoPoint) {
          final GeoPoint location = data['location'];
          markers.add(Marker(
            markerId: MarkerId(urnDoc.id),
            position: LatLng(location.latitude, location.longitude),
            infoWindow: InfoWindow(
              title: data['urnCode'] ?? 'Urna sem código',
              snippet: 'Status: ${data['status'] ?? 'N/A'}',
            ),
          ));
        }
      }
      if (mounted) setState(() => _markers = markers);
    } catch (e) {
      if (mounted) _showSnackBar("Erro ao carregar as urnas: ${e.toString()}", isError: true);
    }
  }
  
  /// Lida com a checagem e solicitação de permissões de localização.
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Serviços de localização estão desativados.', isError: true);
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permissão de localização negada.', isError: true);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permissão negada permanentemente. Abra as configurações do app.', isError: true);
      return false;
    }
    return true;
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota de Coleta'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 14)
                : _kDefaultPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Usaremos nosso próprio botão
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
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
            onPressed: _isLoading ? null : () { /* Lógica para adicionar urna */ },
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