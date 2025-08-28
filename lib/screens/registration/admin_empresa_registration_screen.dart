// lib/screens/registration/admin_empresa_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../login_screen.dart';

class Company {
  final String id;
  final String name;
  Company({required this.id, required this.name});
}

class AdminEmpresaRegistrationScreen extends StatefulWidget {
  const AdminEmpresaRegistrationScreen({super.key});

  @override
  State<AdminEmpresaRegistrationScreen> createState() => _AdminEmpresaRegistrationScreenState();
}

class _AdminEmpresaRegistrationScreenState extends State<AdminEmpresaRegistrationScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  List<Company> _companiesList = [];
  Company? _selectedCompany;

  final _responsibleNameController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
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

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('companies').orderBy('companyName').get();
      final companies = snapshot.docs.map((doc) => Company(id: doc.id, name: doc.data()['companyName'] ?? 'Nome não encontrado')).toList();
      if (mounted) {
        setState(() => _companiesList = companies);
      }
    } catch (e) {
      _showSnackBar("Erro ao carregar a lista de empresas: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerAdminEmpresa() async {
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

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _responsibleNameController.text.trim(),
        'phone': _responsiblePhoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'company_admin', 
        'companyId': _selectedCompany!.id,
        'companyName': _selectedCompany!.name,
        'createdAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance.collection('companies').doc(_selectedCompany!.id).update({
        'adminUid': user.uid,
      });

      if (mounted) {
        _showSnackBar("Admin de Empresa cadastrado e vinculado com sucesso!", isError: false);
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
      appBar: AppBar(title: const Text("Cadastro de Admin de Empresa")),
      body: Stack(
        children: [
          if (_companiesList.isEmpty && !_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "Nenhuma empresa disponível para cadastro. Contate o administrador do sistema.",
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
                        "Selecione a empresa que você representa e preencha seus dados de acesso.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      
                      DropdownButtonFormField<Company>(
                        decoration: _buildInputDecoration('Selecione sua Empresa'),
                        value: _selectedCompany,
                        items: _companiesList.map((company) {
                          return DropdownMenuItem<Company>(
                            value: company,
                            child: Text(company.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (company) => setState(() => _selectedCompany = company),
                        validator: (value) => value == null ? 'É obrigatório selecionar uma empresa.' : null,
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
                        onPressed: _isLoading ? null : _registerAdminEmpresa,
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