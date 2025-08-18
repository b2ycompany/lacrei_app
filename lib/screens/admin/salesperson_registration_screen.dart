// lib/screens/admin/salesperson_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalespersonRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot? salesperson;
  const SalespersonRegistrationScreen({super.key, this.salesperson});

  @override
  State<SalespersonRegistrationScreen> createState() => _SalespersonRegistrationScreenState();
}

class _SalespersonRegistrationScreenState extends State<SalespersonRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  late bool _isEditing;

  // CORREÇÃO: A lógica de inicialização foi reescrita para corrigir os erros de compilação.
  @override
  void initState() {
    super.initState();
    _isEditing = widget.salesperson != null;

    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    if (_isEditing) {
      final data = widget.salesperson!.data() as Map<String, dynamic>?;
      _nameController.text = data?['name'] ?? '';
      _emailController.text = data?['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveSalesperson() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final salespersonName = _nameController.text.trim();
      final salespersonEmail = _emailController.text.trim();

      if (_isEditing) {
        final salespersonId = widget.salesperson!.id;
        final batch = FirebaseFirestore.instance.batch();
        final userRef = FirebaseFirestore.instance.collection('users').doc(salespersonId);
        batch.update(userRef, {'name': salespersonName, 'email': salespersonEmail});
        final salespersonRef = FirebaseFirestore.instance.collection('salespeople').doc(salespersonId);
        batch.update(salespersonRef, {'name': salespersonName, 'email': salespersonEmail});
        await batch.commit();
        _showSnackBar("Vendedor atualizado com sucesso!", isError: false);
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: salespersonEmail,
          password: _passwordController.text.trim(),
        );
        final user = userCredential.user;
        if (user == null) throw Exception("Erro ao criar o utilizador.");

        await user.updateDisplayName(salespersonName);
        
        final batch = FirebaseFirestore.instance.batch();
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        batch.set(userRef, {
          'name': salespersonName, 'email': salespersonEmail,
          'role': 'salesperson', 'createdAt': Timestamp.now(),
        });
        final salespersonRef = FirebaseFirestore.instance.collection('salespeople').doc(user.uid);
        batch.set(salespersonRef, {
          'name': salespersonName, 'email': salespersonEmail,
          'totalSalesValue': 0, 'salesCount': 0,
        });
        await batch.commit();
        _showSnackBar("Vendedor cadastrado com sucesso!", isError: false);
      }
      
      if (mounted) Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Ocorreu um erro.");
    } catch (e) {
      _showSnackBar("Um erro inesperado aconteceu: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? "Editar Vendedor" : "Cadastrar Novo Vendedor")),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nome Completo do Vendedor"), validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "E-mail (será o login)"),
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _isEditing,
                    validator: (v) => v!.isEmpty || !v.contains('@') ? "E-mail inválido" : null,
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing)
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Senha Provisória"),
                      obscureText: true,
                      validator: (v) => !_isEditing && v!.length < 6 ? "A senha deve ter no mínimo 6 caracteres" : null,
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSalesperson,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(_isEditing ? "Salvar Alterações" : "Cadastrar Vendedor"),
                  ),
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