// lib/widgets/rewards_carousel.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardsCarousel extends StatelessWidget {
  const RewardsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150, // Aumentamos a altura para acomodar a imagem
      child: StreamBuilder<QuerySnapshot>(
        // Escuta em tempo real a coleção 'partners'
        stream: FirebaseFirestore.instance.collection('partners').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum prêmio disponível no momento."));
          }

          final partners = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partnerData = partners[index].data() as Map<String, dynamic>;
              
              return Container(
                width: 250, // Aumentamos a largura
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    // Usa a URL da imagem do Firestore
                    image: NetworkImage(partnerData['imageUrl']),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        partnerData['name'] ?? 'Parceiro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}