import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'salesperson_dashboard_screen.dart'; 

class SalespersonLoginScreen extends StatefulWidget {
  const SalespersonLoginScreen({super.key});

  @override
  State<SalespersonLoginScreen> createState() => _SalespersonLoginScreenState();
}

class _SalespersonLoginScreenState extends State<SalespersonLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loginSalesperson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SalespersonDashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro ao tentar fazer o login.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'E-mail ou senha inválidos. Por favor, tente novamente.';
      } else if (e.code == 'invalid-email') {
        message = 'O formato do e-mail é inválido.';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('Um erro inesperado aconteceu.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login de Vendedor"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- MUDANÇA: LOGO ADICIONADO AQUI ---
                Image.asset(
                  'assets/assets/Marca_Lacrei.png',
                  height: 60, // Ajuste a altura conforme necessário
                ),
                const SizedBox(height: 48), // Espaçamento maior após o logo

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "E-mail"),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains('@')) ? "E-mail inválido" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Senha"),
                  obscureText: true,
                  validator: (value) => (value == null || value.isEmpty) ? "Campo obrigatório" : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginSalesperson,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Text("Entrar"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}