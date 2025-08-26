// lib/screens/admin/salesperson_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalespersonRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot? salesperson;

  const SalespersonRegistrationScreen({super.key, this.salesperson});

  @override
  State<SalespersonRegistrationScreen> createState() => _SalespersonRegistrationScreenState();
}

class _SalespersonRegistrationScreenState extends State<SalespersonRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool get _isEditing => widget.salesperson != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.salesperson!.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
    }
  }
  
  Future<void> _saveSalesperson() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    User? tempAuthUser;

    try {
      if (_isEditing) {
        final docId = widget.salesperson!.id;
        final batch = FirebaseFirestore.instance.batch();
        
        batch.update(FirebaseFirestore.instance.collection('salespeople').doc(docId), {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });
        
        batch.update(FirebaseFirestore.instance.collection('users').doc(docId), {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });
        
        await batch.commit();

      } else {
        final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        tempAuthUser = userCredential.user;
        if (tempAuthUser == null) {
          throw Exception("Falha ao criar usuário de autenticação.");
        }

        await tempAuthUser.updateDisplayName(_nameController.text.trim());
        
        final batch = FirebaseFirestore.instance.batch();

        batch.set(FirebaseFirestore.instance.collection('salespeople').doc(tempAuthUser.uid), {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'salesCount': 0,
          'totalSalesValue': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.set(FirebaseFirestore.instance.collection('users').doc(tempAuthUser.uid), {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'salesperson',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Vendedor salvo com sucesso!"), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (tempAuthUser != null) {
        await tempAuthUser.delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ocorreu um erro: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Vendedor" : "Adicionar Vendedor"),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveSalesperson,
            icon: const Icon(Icons.save),
            tooltip: "Salvar",
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nome Completo"),
              validator: (value) => value!.isEmpty ? "O nome é obrigatório" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "E-mail de Login"),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isEditing,
              validator: (value) {
                if (value!.isEmpty) return "O e-mail é obrigatório";
                if (!value.contains('@')) return "Formato de e-mail inválido";
                return null;
              },
            ),
            if (!_isEditing) const SizedBox(height: 16),
            if (!_isEditing)
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Senha de Acesso"),
                obscureText: true,
                validator: (value) {
                  if (!_isEditing && (value == null || value.length < 6)) {
                    return "A senha deve ter no mínimo 6 caracteres";
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
    );
  }
}