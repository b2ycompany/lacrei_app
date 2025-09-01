// lib/screens/profile_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'login_screen.dart';
import 'registration/registration_selection_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2C154B), Color(0xFF4B0082)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('Bem-vindo ao Lacrei', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))
                        .animate().fade(duration: 800.ms).slideY(begin: -0.5, curve: Curves.easeOutCubic),
                    const SizedBox(height: 16),
                    const Text('Selecione seu perfil para começar', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70))
                        .animate().fade(delay: 400.ms, duration: 800.ms),
                    const SizedBox(height: 60),

                    // --- ORDEM DOS BOTÕES ATUALIZADA ---
                    _ProfileButton(label: 'Aluno / Funcionário', color: const Color(0xFF99CC33), onPressed: () => _navigateToLogin(context))
                        .animate().fade(delay: 600.ms),
                    const SizedBox(height: 20),
                    _ProfileButton(label: 'Admin. Escola', color: const Color(0xFF99CC33), onPressed: () => _navigateToLogin(context))
                        .animate().fade(delay: 700.ms),
                    const SizedBox(height: 20),
                    _ProfileButton(label: 'Colaborador Empresa', color: const Color(0xFFFF6600), onPressed: () => _navigateToLogin(context))
                        .animate().fade(delay: 800.ms),
                    const SizedBox(height: 20),
                    _ProfileButton(label: 'Admin Empresa', color: const Color(0xFFFF6600), onPressed: () => _navigateToLogin(context))
                        .animate().fade(delay: 900.ms),
                    const SizedBox(height: 20),
                    _ProfileButton(label: 'Instituição', color: const Color(0xFFCC6699), onPressed: () => _navigateToLogin(context))
                        .animate().fade(delay: 1000.ms),
                    
                    const SizedBox(height: 40),
                    
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegistrationSelectionScreen()),
                        );
                      },
                      child: const Text(
                        'Ainda não se cadastrou? Clique aqui',
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ProfileButton({
    required this.label, 
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tilt(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(80)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4)
              )
            ]
          ),
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }
}