// lib/screens/admin/bulk_upload_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;
  String _feedbackMessage = '';

  Future<void> _processAndUploadData() async {
    if (_textController.text.trim().isEmpty) {
      setState(() => _feedbackMessage = 'Erro: A área de texto está vazia.');
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = '';
    });

    try {
      final lines = _textController.text.trim().split('\n');
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      int schoolsAdded = 0;
      int batchCounter = 0;

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        // LÓGICA ATUALIZADA: Agora espera 5 ou mais partes, pois o endereço pode conter vírgulas
        if (parts.length >= 5) {
          final schoolName = parts[0].trim();
          final schoolType = parts[1].trim().toLowerCase();
          final city = parts[2].trim();
          final cep = parts[3].trim();
          // Junta o resto das partes para formar o endereço completo
          final address = parts.sublist(4).join(',').trim();

          final schoolRef = firestore.collection('schools').doc();
          batch.set(schoolRef, {
            'schoolName': schoolName,
            'schoolType': schoolType,
            'city': city,
            'cep': cep,         // NOVO CAMPO
            'address': address,   // NOVO CAMPO
            'totalCollectedKg': 0,
            'createdAt': Timestamp.now(),
          });
          schoolsAdded++;
          batchCounter++;

          // O WriteBatch tem um limite de 500 operações. Se a lista for muito grande,
          // fazemos múltiplos commits para garantir a performance.
          if (batchCounter == 499) {
            await batch.commit();
            batch = firestore.batch();
            batchCounter = 0;
          }
        }
      }

      if (schoolsAdded > 0) {
        await batch.commit(); // Commit do batch final
        setState(() => _feedbackMessage = '$schoolsAdded escolas adicionadas com sucesso!');
        _textController.clear();
      } else {
        setState(() => _feedbackMessage = 'Nenhuma escola válida encontrada para adicionar. Verifique o formato.');
      }

    } catch (e) {
      setState(() => _feedbackMessage = 'Ocorreu um erro: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Carga Inicial de Escolas"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Instruções", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // INSTRUÇÕES ATUALIZADAS
            const Text(
              "Cole a lista de escolas na área de texto abaixo. Cada escola deve estar em uma nova linha e seguir o formato:\n\nNome da Escola,Tipo,Cidade,CEP,Endereço Completo\n\nExemplo:\nColégio Exemplo,particular,Cotia,01234-567,Rua das Flores, 123",
              style: TextStyle(height: 1.5),
            ),
            const Divider(height: 40),
            TextField(
              controller: _textController,
              maxLines: 15,
              decoration: const InputDecoration(
                hintText: "Cole os dados aqui...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _processAndUploadData,
              icon: const Icon(Icons.upload_file),
              label: const Text("Processar e Adicionar"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_feedbackMessage.isNotEmpty)
              Center(
                child: Text(
                  _feedbackMessage,
                  style: TextStyle(
                    color: _feedbackMessage.startsWith('Erro') ? Colors.redAccent : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}