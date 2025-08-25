// lib/screens/collector/collector_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() => _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {

  // --- NOVO: Lógica para criar os marcadores do mapa ---
  Set<Marker> _createMarkers(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Assumindo que você tem latitude e longitude no seu documento
      final double lat = data['latitude'] ?? 0.0;
      final double lng = data['longitude'] ?? 0.0;
      final String urnCode = data['urnCode'] ?? 'Código da Urna';
      final String locationName = data['assignedToName'] ?? 'Não informado';

      return Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: urnCode,
          snippet: locationName,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }).toSet();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Tratar erro de logout se necessário
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rota de Coleta"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
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
            return const Center(child: Text("Erro ao carregar as coletas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text("Nenhuma urna cheia no momento!", style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final fullUrnsDocs = snapshot.data!.docs;
          final markers = _createMarkers(fullUrnsDocs);

          // --- ALTERAÇÃO: Substituímos a ListView pelo GoogleMap ---
          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              // Posição inicial do mapa (ex: centro de São Paulo)
              // O ideal é centralizar com base na localização do coletor ou na primeira urna
              target: LatLng(-23.550520, -46.633308), 
              zoom: 12,
            ),
            markers: markers,
            mapType: MapType.normal,
            myLocationButtonEnabled: true, // Habilita o botão para ir para a localização do usuário
            myLocationEnabled: true, // Mostra a localização do usuário no mapa (requer permissões de localização)
          );
        },
      ),
    );
  }
}