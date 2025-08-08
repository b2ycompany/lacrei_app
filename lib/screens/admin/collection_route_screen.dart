import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CollectionRouteScreen extends StatefulWidget {
  const CollectionRouteScreen({super.key});

  @override
  State<CollectionRouteScreen> createState() => _CollectionRouteScreenState();
}

class _CollectionRouteScreenState extends State<CollectionRouteScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static const LatLng _initialPosition = LatLng(-23.55052, -46.633308); // São Paulo
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _lastPosition;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    // Exemplo de marcadores (substituir pelos dados reais)
    _markers.addAll([
      const Marker(
        markerId: MarkerId('start'),
        position: LatLng(-23.55052, -46.633308),
        infoWindow: InfoWindow(title: 'Ponto Inicial'),
      ),
      const Marker(
        markerId: MarkerId('end'),
        position: LatLng(-23.551, -46.634),
        infoWindow: InfoWindow(title: 'Destino Final'),
      ),
    ]);

    // Exemplo de rota (substituir pelo cálculo real da rota)
    _polylines.add(
      const Polyline(
        polylineId: PolylineId('route'),
        points: [
          LatLng(-23.55052, -46.633308),
          LatLng(-23.551, -46.634),
        ],
        color: Colors.blue,
        width: 5,
      ),
    );

    _lastPosition = _initialPosition;

    setState(() => _isLoading = false);
  }

  Future<void> _goToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15),
      ),
    );
  }

  void _addMarker(LatLng position) {
    final String markerId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          infoWindow: InfoWindow(title: 'Ponto ${_markers.length + 1}'),
        ),
      );
      _lastPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota de Coleta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_lastPosition != null) {
                _goToPosition(_lastPosition!);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 14,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _markers,
              polylines: _polylines,
              onTap: _addMarker,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          if (_lastPosition != null) {
            _addMarker(
              LatLng(
                _lastPosition!.latitude + 0.0005,
                _lastPosition!.longitude + 0.0005,
              ),
            );
          }
        },
      ),
    );
  }
}
