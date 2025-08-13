// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
// CORREÇÃO: Alterado de 'package.' para 'package:'
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'student/student_dashboard_screen.dart';
import 'school_admin/school_admin_dashboard_screen.dart';
import 'registration/registration_selection_screen.dart';
import 'forgot_password_screen.dart';
import 'institution/instituicao_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'company/company_dashboard_screen.dart';
// CORREÇÃO: O caminho relativo está correto agora que o ficheiro existe
import 'collector/collector_dashboard_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  final String webClientId = "103402952377-d5ugb7u9ku9c7bclokhksqlhmaguvm6j.apps.googleusercontent.com";

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Por favor, preencha e-mail e senha.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;
      if (user != null) {
        await _navigateBasedOnUserRole(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Ocorreu um erro.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "E-mail ou senha inválidos.";
      }
      _showError(message);
    } catch (e) {
      _showError("Ocorreu um erro inesperado.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(clientId: webClientId).signIn();
      
      if (googleUser == null) {
        if(mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          await _navigateBasedOnUserRole(user.uid);
        } else {
          if(mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegistrationSelectionScreen()));
          }
        }
      }
    } catch (e) {
      _showError("Erro ao fazer login com Google. Verifique se o Web Client ID está correto no código.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _navigateBasedOnUserRole(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;

    if (userDoc.exists && userDoc.data() != null) {
      final role = userDoc.data()!['role'];
      Widget destination;
      switch (role) {
        case 'aluno':
          destination = const StudentDashboardScreen();
          break;
        case 'adm_escola':
          destination = const SchoolAdminDashboardScreen();
          break;
        case 'instituicao':
          destination = const InstituicaoDashboardScreen();
          break;
        case 'administrador':
        case 'super_admin':
          destination = const AdminDashboardScreen();
          break;
        case 'company_admin':
          destination = const CompanyDashboardScreen();
          break;
        case 'collector':
          destination = const CollectorDashboardScreen();
          break;
        default:
          _showError("Perfil de usuário não reconhecido.");
          return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => destination), (route) => false);
    } else {
      _showError("Não foi possível encontrar os dados do seu perfil.");
      await _auth.signOut();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 25, 5, 45),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  const Icon(Icons.lock_open_rounded, color: Colors.purpleAccent, size: 80).animate().fade(duration: 800.ms).scale(delay: 200.ms),
                  const SizedBox(height: 20),
                  const Text("Bem-vindo(a) de volta!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)).animate().fade(delay: 400.ms).slideY(begin: 0.5, duration: 600.ms),
                  const SizedBox(height: 50),
                  _buildSocialButton(onPressed: _signInWithGoogle, icon: FontAwesomeIcons.google, label: "Entrar com Google", color: Colors.white, textColor: Colors.black87)
                      .animate().fade(delay: 600.ms).slideX(begin: -0.5, duration: 600.ms),
                  const SizedBox(height: 20),
                  _buildDivider().animate().fade(delay: 800.ms),
                  const SizedBox(height: 20),
                  TextField(controller: _emailController, decoration: _buildInputDecoration("E-mail"), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.emailAddress)
                      .animate().fade(delay: 1000.ms).slideX(begin: -0.5, duration: 600.ms),
                  const SizedBox(height: 16),
                  TextField(controller: _passwordController, obscureText: true, decoration: _buildInputDecoration("Senha"), style: const TextStyle(color: Colors.white))
                      .animate().fade(delay: 1100.ms).slideX(begin: 0.5, duration: 600.ms),
                  _buildForgotPasswordButton().animate().fade(delay: 1200.ms),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.purple.shade600,
                      disabledBackgroundColor: Colors.purple.shade800,
                    ),
                    child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Entrar", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ).animate().fade(delay: 1300.ms).slideY(begin: 0.5, duration: 600.ms),
                  const SizedBox(height: 20),
                  _buildSignUpNavigation(),
                ].animate(interval: 100.ms).fade(duration: 400.ms),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color, Color? textColor}) {
    return ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label), style: ElevatedButton.styleFrom(foregroundColor: textColor ?? Colors.white, backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Widget _buildDivider() {
    return const Row(children: [Expanded(child: Divider(color: Colors.white38)), Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("OU", style: TextStyle(color: Colors.white54))), Expanded(child: Divider(color: Colors.white38))]);
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.white.withAlpha(25), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
  }

  Widget _buildForgotPasswordButton() {
    return Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())); }, child: const Text("Esqueci a senha?", style: TextStyle(color: Colors.white70))));
  }

  Widget _buildSignUpNavigation() {
    return GestureDetector(
      onTap: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationSelectionScreen())); },
      child: Padding(padding: const EdgeInsets.all(8.0), child: RichText(textAlign: TextAlign.center, text: const TextSpan(text: "Não tem uma conta? ", style: TextStyle(color: Colors.white70), children: [TextSpan(text: "Cadastre-se", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))]))),
    );
  }
}