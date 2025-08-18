// lib/screens/registration/registration_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'aluno_registration_screen.dart';
import 'adm_escola_registration_screen.dart';
import 'instituicao_registration_screen.dart';
import 'company_registration_screen.dart'; // Import da tela de empresa

class RegistrationSelectionScreen extends StatelessWidget {
  const RegistrationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selecione o Tipo de Cadastro"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "O que você representa?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fade(duration: 500.ms),
            const SizedBox(height: 40),
            
            // ALTERADO: Texto do botão atualizado
            _buildRegistrationButton(
              context: context,
              label: 'Sou Aluno / Funcionário',
              destination: const AlunoRegistrationScreen(),
              delay: 300.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou Admin de Escola',
              destination: const AdmEscolaRegistrationScreen(),
              delay: 500.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou uma Instituição',
              destination: const InstituicaoRegistrationScreen(),
              delay: 700.ms,
            ),
            const SizedBox(height: 20),
            // NOVO: Botão para cadastro de empresa
            _buildRegistrationButton(
              context: context,
              label: 'Sou uma Empresa',
              destination: const CompanyRegistrationScreen(),
              delay: 900.ms,
            ),
            // O botão para 'Administrador' foi removido desta tela pública por questões de segurança,
            // como discutimos. Novos super administradores devem ser criados por quem já é admin.
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationButton({
    required BuildContext context,
    required String label,
    required Widget destination,
    required Duration delay,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Text(label, style: const TextStyle(fontSize: 18)),
    ).animate().fade(delay: delay).slideY(begin: 0.5);
  }
}