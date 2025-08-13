// lib/widgets/guardian_terms_dialog.dart

import 'package:flutter/material.dart';

class GuardianTermsDialog extends StatelessWidget {
  const GuardianTermsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Termo de Consentimento do Responsável"),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Termo de Consentimento do Responsável Legal",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "Eu, na qualidade de responsável legal pelo menor, declaro que li e estou de acordo com o Termo de Responsabilidade de Uso do Aplicativo Lacrei.",
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 12),
            Text(
              "Autorizo a participação do menor nas campanhas de arrecadação, competições e eventuais sorteios promovidos pela plataforma. Assumo total responsabilidade pela sua supervisão durante as atividades de coleta e pelo uso geral do aplicativo, em conformidade com os termos apresentados.",
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Fechar"),
        ),
      ],
    );
  }
}