// lib/widgets/terms_dialog.dart

import 'package:flutter/material.dart';

class TermsDialog extends StatelessWidget {
  const TermsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Termo de Responsabilidade"),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TERMO DE RESPONSABILIDADE DE USO DO APLICATIVO LACREI", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Este Termo de Responsabilidade (“Termo”) regula o uso do aplicativo Lacrei (“Aplicativo”), desenvolvido para promover campanhas de arrecadação de lacres de latinhas, com foco em metas escolares, competições e integração entre escolas, empresas e funcionários.\n\nAo utilizar o Aplicativo, o usuário declara estar ciente e de acordo com as condições abaixo:"),
            SizedBox(height: 16),
            Text("1. Público-Alvo e Responsabilidade por Menores de Idade", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("1.1. O Aplicativo poderá ser utilizado por crianças e adolescentes menores de 16 anos, desde que haja consentimento e acompanhamento de seus responsáveis legais.\n\n1.2. Os responsáveis legais assumem total responsabilidade pelo uso do Aplicativo pelo menor, incluindo participação em sorteios, competições, coleta e entrega de lacres.\n\n1.3. O Aplicativo não coleta dados sensíveis de menores sem autorização expressa do responsável legal."),
            SizedBox(height: 16),
            Text("2. Uso por Escolas, Empresas e Funcionários", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("2.1. Escolas, empresas e organizações que participarem das competições assumem a responsabilidade pela gestão interna de suas equipes, funcionários e alunos inscritos no Aplicativo.\n\n2.2. Cabe à instituição:\nGarantir que todos os participantes conheçam este Termo.\nSupervisionar as metas e o andamento das competições.\nOrganizar a entrega física dos lacres arrecadados.\n\n2.3. Funcionários participantes autorizam a divulgação de seu desempenho em rankings e resultados públicos da competição."),
            SizedBox(height: 16),
            // Adicione as outras seções do seu termo aqui da mesma forma...
            Text("6. Disposições Gerais", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("6.1. Ao acessar e utilizar o Aplicativo, o usuário (ou seu responsável legal) declara ter lido, compreendido e aceito este Termo.\n\n6.2. Este Termo poderá ser alterado a qualquer momento, sendo responsabilidade do usuário manter-se informado sobre as atualizações."),
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