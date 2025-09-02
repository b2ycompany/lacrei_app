// lib/screens/registration/adm_escola_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../login_screen.dart';

class School {
  final String id;
  final String name;
  School({required this.id, required this.name});
}

class AdmEscolaRegistrationScreen extends StatefulWidget {
  const AdmEscolaRegistrationScreen({super.key});

  @override
  State<AdmEscolaRegistrationScreen> createState() => _AdmEscolaRegistrationScreenState();
}

class _AdmEscolaRegistrationScreenState extends State<AdmEscolaRegistrationScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  List<School> _schoolsList = [];
  School? _selectedSchool;

  final _responsibleNameController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }
  
  @override
  void dispose() {
    _responsibleNameController.dispose();
    _responsiblePhoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('schools').orderBy('schoolName').get();
      final schools = snapshot.docs.map((doc) => School(id: doc.id, name: doc.data()['schoolName'] ?? 'Nome não encontrado')).toList();
      if (mounted) {
        setState(() => _schoolsList = schools);
      }
    } catch (e) {
      _showSnackBar("Erro ao carregar a lista de escolas: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerAdmEscola() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() => _isLoading = true);
    User? user; 

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      user = userCredential.user;
      if (user == null) throw Exception("Falha ao criar usuário na autenticação.");

      await user.updateDisplayName(_responsibleNameController.text.trim());

      // --- ALTERAÇÕES APLICADAS AQUI ---
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _responsibleNameController.text.trim(),
        'phone': _responsiblePhoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'adm_escola', 
        'schoolId': _selectedSchool!.id,
        'schoolName': _selectedSchool!.name,
        'createdAt': Timestamp.now(),
        'accountStatus': 'pending', // 1. Adicionado o status inicial como pendente
      });

      await FirebaseFirestore.instance.collection('schools').doc(_selectedSchool!.id).update({
        'adminUid': user.uid,
      });

      if (mounted) {
        // 2. Mensagem de sucesso alterada para informar sobre a aprovação
        _showSnackBar("Cadastro enviado! Sua conta será ativada após aprovação do administrador.", isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (user != null) {
        await user.delete();
      }
      _showSnackBar("Ocorreu um erro: ${e.toString()}");
    } finally {
      if(mounted) setState(() => _isLoading = false);
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
      fillColor: Colors.white.withAlpha(25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Admin da Escola/Faculdade")),
      body: Stack(
        children: [
          if (_schoolsList.isEmpty && !_isLoading)
            const Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Nenhuma escola disponível para cadastro. Contate o administrador.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
            )
          else
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Selecione sua instituição e preencha seus dados de acesso.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      
                      DropdownButtonFormField<School>(
                        decoration: _buildInputDecoration('Selecione sua Escola/Faculdade'),
                        value: _selectedSchool,
                        items: _schoolsList.map((school) {
                          return DropdownMenuItem<School>(
                            value: school,
                            child: Text(school.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (school) => setState(() => _selectedSchool = school),
                        validator: (value) => value == null ? 'É obrigatório selecionar uma escola.' : null,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF4B0082),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _responsibleNameController, decoration: _buildInputDecoration('Seu Nome Completo'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _responsiblePhoneController, decoration: _buildInputDecoration('Seu Telefone de Contato'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _emailController, decoration: _buildInputDecoration('Seu E-mail de Acesso'), keyboardType: TextInputType.emailAddress, validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'E-mail inválido' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordController, decoration: _buildInputDecoration('Sua Senha de Acesso'), obscureText: true, validator: (v) => (v?.length ?? 0) < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _confirmPasswordController, decoration: _buildInputDecoration('Confirmar Senha'), obscureText: true, autovalidateMode: AutovalidateMode.onUserInteraction, validator: (v) => v != _passwordController.text ? 'As senhas não coincidem' : null),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _registerAdmEscola,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text("Finalizar Cadastro"),
                      )
                    ],
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                ),
              ),
            ),
          if (_isLoading) Container(color: Colors.black.withAlpha(128), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}