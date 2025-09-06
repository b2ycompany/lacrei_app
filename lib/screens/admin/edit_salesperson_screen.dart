// lib/screens/admin/edit_salesperson_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // NOVO IMPORT

class EditSalespersonScreen extends StatefulWidget {
  final DocumentSnapshot? salesperson;

  const EditSalespersonScreen({super.key, this.salesperson});

  @override
  State<EditSalespersonScreen> createState() => _EditSalespersonScreenState();
}

class _EditSalespersonScreenState extends State<EditSalespersonScreen> {
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  // --- LÓGICA DE SALVAR TOTALMENTE REFEITA ---
  Future<void> _saveSalesperson() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // A lógica de edição pode continuar no cliente, pois o Super Admin tem permissão de update.
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
        // Para CRIAR, chamamos a Cloud Function
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createSalesperson');
        
        await callable.call(<String, dynamic>{
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vendedor salvo com sucesso!"), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro da Cloud Function: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
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
              enabled: !_isEditing, // Não permite editar e-mail para não dessincronizar com a Auth
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