import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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
      if (e.code == 'MissingPluginException') {
        _errorMessage = "Erro: Recurso de localização não disponível. Verifique as dependências e a plataforma.";
      } else {
        _errorMessage = e.message;
      }
      if (mounted) setState(() {});
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation({bool animate = true}) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Serviços de localização estão desativados.");
      }

      final permission = await _handleLocationPermission();
      if (!permission) {
        throw Exception("Permissão de localização negada.");
      }
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      if (mounted) setState(() => _currentPosition = position);

      if (animate) {
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15.0,
        )));
      }
    } on MissingPluginException {
       if (mounted) _showSnackBar("Erro: Recurso de localização não disponível na web.", isError: true);
       _errorMessage = "Erro de implementação: Recurso de localização não disponível. Verifique as dependências.";
       if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _showSnackBar("Erro ao obter localização: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carrega todas as urnas, colore os marcadores e cria a rota.
  Future<void> _loadUrnsAndRoute() async {
    try {
      final urnsSnapshot = await FirebaseFirestore.instance.collection('urns').get();
      final Set<Marker> markers = {};
      final List<LatLng> fullUrnLocations = [];

      print('>>> Coletando dados do Firestore: ${urnsSnapshot.docs.length} urnas encontradas.');

      for (var urnDoc in urnsSnapshot.docs) {
        final urnData = urnDoc.data();
        final String? assignedToType = urnData['assignedToType'];
        final String? assignedToId = urnData['assignedToId'];
        
        // Verifica se a urna tem um local atribuído
        if (assignedToType != null && assignedToId != null) {
          
          // Busca o documento de forma individual e robusta
          final assignedDoc = await FirebaseFirestore.instance
              .collection('${assignedToType}s')
              .doc(assignedToId)
              .get();
          
          if (assignedDoc.exists) {
            final assignedData = assignedDoc.data() as Map<String, dynamic>;

            if (assignedData.containsKey('location') && assignedData['location'] is GeoPoint) {
              final GeoPoint location = assignedData['location'];
              final LatLng urnLatLng = LatLng(location.latitude, location.longitude);
              
              print('>>> Urna ID: ${urnDoc.id} | Localização encontrada para ${assignedData['name']} (GeoPoint): ${urnLatLng.latitude}, ${urnLatLng.longitude}');

              final String status = urnData['status'] ?? 'Desconhecido';
              BitmapDescriptor markerColor;

              if (status == 'Cheia') {
                markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
                fullUrnLocations.add(urnLatLng);
              } else {
                markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
              }

              markers.add(Marker(
                markerId: MarkerId(urnDoc.id),
                position: urnLatLng,
                icon: markerColor,
                infoWindow: InfoWindow(
                  title: urnData['urnCode'] ?? 'Código indisponível',
                  snippet: 'Status: $status | Local: ${urnData['assignedToName']}',
                ),
              ));
            } else {
              print('>>> Urna ID: ${urnDoc.id} | Aviso: O documento atribuído não contém o campo de localização. Verifique o Firestore.');
            }
          } else {
            print('>>> Urna ID: ${urnDoc.id} | Aviso: Documento atribuído não encontrado. ID: $assignedToId');
          }
        } else {
          print('>>> Urna ID: ${urnDoc.id} | Aviso: Urna não tem um local atribuído.');
        }
      }

      if (fullUrnLocations.isNotEmpty) {
        final Polyline routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: fullUrnLocations,
        );
        _polylines.add(routePolyline);
      }

      if (mounted) setState(() {
        _markers = markers;
        _polylines = _polylines;
      });
    } catch (e) {
      if (mounted) _showSnackBar("Erro ao carregar as urnas: ${e.toString()}", isError: true);
    }
  }
  
  Future<bool> _handleLocationPermission() async {
    LocationPermission permission;
    
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