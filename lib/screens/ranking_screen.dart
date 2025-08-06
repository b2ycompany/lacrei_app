// lib/screens/ranking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  // MELHORIA: Widget para exibir a medalha de acordo com a posição
  Widget _buildMedal(int rank) {
    switch (rank) {
      case 1:
        return const Text('🥇', style: TextStyle(fontSize: 24));
      case 2:
        return const Text('🥈', style: TextStyle(fontSize: 24));
      case 3:
        return const Text('🥉', style: TextStyle(fontSize: 24));
      default:
        return Text('$rank.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ranking das Escolas"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // A consulta busca todas as escolas e as ordena pela maior quantidade coletada
        stream: FirebaseFirestore.instance
            .collection('schools')
            .orderBy('totalCollectedKg', descending: true)
            .limit(50) // Limita o ranking às 50 melhores escolas
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar o ranking: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma escola no ranking ainda."));
          }

          final schools = snapshot.data!.docs;

          return ListView.builder(
            itemCount: schools.length,
            itemBuilder: (context, index) {
              final school = schools[index];
              final data = school.data() as Map<String, dynamic>;
              final rank = index + 1;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: rank == 1 ? Colors.amber : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  leading: _buildMedal(rank),
                  title: Text(
                    data['schoolName'] ?? 'Escola sem nome',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(data['totalCollectedKg'] as num? ?? 0).toStringAsFixed(1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent),
                      ),
                      const Text('arrecadados', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
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