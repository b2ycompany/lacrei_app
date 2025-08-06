// lib/screens/registration/admin_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class AdminRegistrationScreen extends StatefulWidget {
  const AdminRegistrationScreen({super.key});

  @override
  State<AdminRegistrationScreen> createState() => _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registerAdmin() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("As senhas não coincidem.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'administrador',
          'createdAt': Timestamp.now(),
        });

        if (mounted) {
          _showSnackBar("Administrador cadastrado com sucesso!", isError: false);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      _showSnackBar("Ocorreu um erro: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Administrador")),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: _nameController, decoration: _buildInputDecoration('Nome Completo')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _emailController, decoration: _buildInputDecoration('E-mail de Acesso'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextFormField(controller: _passwordController, decoration: _buildInputDecoration('Senha de Acesso'), obscureText: true),
                  const SizedBox(height: 16),
                  TextFormField(controller: _confirmPasswordController, decoration: _buildInputDecoration('Confirmar Senha'), obscureText: true),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerAdmin,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Cadastrar Administrador", style: TextStyle(fontSize: 18)),
                  )
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}