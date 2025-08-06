// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importamos nosso arquivo 'main.dart' para acessar o widget principal do app.
import 'package:lacrei_app/main.dart';
// Importamos a tela de seleção de perfil para o teste.


void main() {
  // Um grupo de testes para garantir que a tela de seleção de perfil funciona.
  testWidgets('Tela de Seleção de Perfil é renderizada corretamente', (WidgetTester tester) async {
    // 1. Constrói o nosso aplicativo.
    // A correção está aqui: fornecemos o parâmetro obrigatório 'seenOnboarding'.
    // Definimos como 'true' para testar o cenário em que o onboarding já foi visto.
    await tester.pumpWidget(const LacreiApp(seenOnboarding: true));

    // Como o 'home' do LacreiApp é a SplashScreen, o teste precisa esperar a
    // navegação da splash para a próxima tela.
    // pumpAndSettle irá avançar os frames até que todas as animações e transições de tela terminem.
    await tester.pumpAndSettle();

    // 2. Verifica os widgets na tela de seleção de perfil.

    // Verifica se o texto de saudação "Olá!" está visível.
    expect(find.text('Olá!'), findsOneWidget);

    // Verifica se todos os botões de perfil estão presentes.
    expect(find.widgetWithText(ElevatedButton, 'Aluno'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Adm. Escola'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Instituição'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Administrador'), findsOneWidget);

    // Verifica se o link para cadastro também está na tela.
    expect(find.text('Ainda não se cadastrou? Clique aqui'), findsOneWidget);
  });
}