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
  // --- CORREÇÃO: Adicionado GlobalKey para o formulário ---
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  // --- CORREÇÃO: Lógica de registro aprimorada com rollback ---
  Future<void> _registerAdmin() async {
    // Valida o formulário antes de continuar
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar("Por favor, corrija os erros no formulário.");
      return;
    }

    setState(() => _isLoading = true);
    User? user; // Variável para guardar o usuário da Auth

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      user = userCredential.user;
      if (user == null) throw Exception("Falha ao criar usuário na autenticação.");


      await user.updateDisplayName(_nameController.text.trim());
      
      // Se a escrita no Firestore falhar, o bloco 'catch' será acionado
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        // ATENÇÃO: A criação de administradores deveria ser feita por um super_admin já logado.
        // A regra do Firestore foi flexibilizada para permitir este fluxo, mas não é o ideal para produção.
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
    } catch (e) {
      // LÓGICA DE REVERSÃO (ROLLBACK)
      // Se 'user' não for nulo, a criação na Auth funcionou, mas algo depois falhou.
      // Então, apagamos o usuário da Auth para que o e-mail possa ser usado novamente.
      if (user != null) {
        await user.delete();
      }
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
              // --- CORREÇÃO: Adicionado o widget Form ---
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Nome Completo'),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration('E-mail de Acesso'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'E-mail inválido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: _buildInputDecoration('Senha de Acesso'),
                      obscureText: true,
                      validator: (v) => (v?.length ?? 0) < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 16),
                    // --- CORREÇÃO: Adicionado validador de confirmação de senha ---
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: _buildInputDecoration('Confirmar Senha'),
                      obscureText: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => v != _passwordController.text ? 'As senhas não coincidem' : null,
                    ),
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
          ),
          if (_isLoading) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}