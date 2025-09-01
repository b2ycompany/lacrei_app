// lib/screens/registration/registration_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'aluno_registration_screen.dart';
import 'adm_escola_registration_screen.dart';
import 'instituicao_registration_screen.dart';
import 'admin_empresa_registration_screen.dart';
import 'colaborador_empresa_registration_screen.dart';

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
            
            // --- ORDEM E CORES ATUALIZADAS PARA AGRUPAMENTO ---
            _buildRegistrationButton(
              context: context,
              label: 'Sou Aluno / Funcionário de Escola',
              destination: const AlunoRegistrationScreen(),
              color: const Color(0xFF99CC33), // Verde
              delay: 300.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou Admin de Escola',
              destination: const AdmEscolaRegistrationScreen(),
              color: const Color(0xFF99CC33), // Verde
              delay: 400.ms,
            ),
            const SizedBox(height: 20),
             _buildRegistrationButton(
              context: context,
              label: 'Sou Colaborador de Empresa',
              destination: const ColaboradorEmpresaRegistrationScreen(),
              color: const Color(0xFFFF6600), // Laranja
              delay: 500.ms,
            ),
            const SizedBox(height: 20),
             _buildRegistrationButton(
              context: context,
              label: 'Sou Admin de Empresa',
              destination: const AdminEmpresaRegistrationScreen(),
              color: const Color(0xFFFF6600), // Laranja
              delay: 600.ms,
            ),
            const SizedBox(height: 20),
            _buildRegistrationButton(
              context: context,
              label: 'Sou uma Instituição',
              destination: const InstituicaoRegistrationScreen(),
              color: const Color(0xFFCC6699), // Rosa/Magenta
              delay: 700.ms,
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