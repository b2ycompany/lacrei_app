// lib/screens/registration/registration_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'aluno_registration_screen.dart';
import 'adm_escola_registration_screen.dart';
import 'instituicao_registration_screen.dart';
import 'company_registration_screen.dart'; 

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
            
            // --- ALTERAÇÃO: Cores atualizadas com base no logo ---
            _buildRegistrationButton(
              context: context,
              label: 'Sou Aluno / Funcionário',
              destination: const AlunoRegistrationScreen(),
              color: const Color(0xFF99CC33), // Verde Limão
              delay: 300.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou Admin de Escola',
              destination: const AdmEscolaRegistrationScreen(),
              color: const Color(0xFF9966CC), // Roxo
              delay: 500.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou uma Instituição',
              destination: const InstituicaoRegistrationScreen(),
              color: const Color(0xFFCC6699), // Rosa/Magenta
              delay: 700.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou uma Empresa',
              destination: const CompanyRegistrationScreen(),
              color: const Color(0xFFFF6600), // Laranja
              delay: 900.ms,
            ),
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
    required Color color,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ).animate().fade(delay: delay).slideY(begin: 0.5);
  }
}