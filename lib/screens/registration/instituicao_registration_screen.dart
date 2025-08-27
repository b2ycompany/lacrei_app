// lib/screens/registration/instituicao_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../login_screen.dart';

// Modelo para simplificar a manipulação dos dados da instituição
class Institution {
  final String id;
  final String name;
  Institution({required this.id, required this.name});
}

class InstituicaoRegistrationScreen extends StatefulWidget {
  const InstituicaoRegistrationScreen({super.key});

  @override
  State<InstituicaoRegistrationScreen> createState() => _InstituicaoRegistrationScreenState();
}

class _InstituicaoRegistrationScreenState extends State<InstituicaoRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Lista de instituições que virão do Firestore
  List<Institution> _institutionsList = [];
  // Instituição que o usuário selecionou no dropdown
  Institution? _selectedInstitution;

  final _responsibleNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _fetchInstitutions();
  }

  @override
  void dispose() {
    _responsibleNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _responsiblePhoneController.dispose();
    super.dispose();
  }

  // Função para buscar as instituições cadastradas pelo Super Admin
  Future<void> _fetchInstitutions() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('institutions').orderBy('institutionName').get();
      // Mapeia os documentos para a nossa classe 'Institution'
      final institutions = snapshot.docs.map((doc) => Institution(id: doc.id, name: doc.data()['institutionName'] ?? 'Nome não encontrado')).toList();
      if (mounted) {
        setState(() => _institutionsList = institutions);
      }
    } catch (e) {
      _showSnackBar("Erro ao carregar a lista de instituições: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Lógica de registro corrigida e alinhada à nova regra de negócio
  Future<void> _registerInstituicao() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    User? user;

    try {
      // 1. Cria o usuário na autenticação do Firebase
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      user = userCredential.user;
      if (user == null) throw Exception("Falha ao criar usuário na autenticação.");

      // 2. Atualiza o nome de exibição do usuário
      await user.updateDisplayName(_responsibleNameController.text.trim());
      
      // 3. Cria o documento do usuário na coleção 'users', vinculando-o à instituição selecionada
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _responsibleNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _responsiblePhoneController.text.trim(),
        'role': 'instituicao',
        'institutionId': _selectedInstitution!.id, // ID da instituição selecionada
        'institutionName': _selectedInstitution!.name, // Nome da instituição selecionada
        'createdAt': Timestamp.now(),
      });

      // BÔNUS: Atualiza o documento da instituição para incluir o ID do admin
      await FirebaseFirestore.instance.collection('institutions').doc(_selectedInstitution!.id).update({
        'adminUid': user.uid,
      });

      if (mounted) {
        _showSnackBar("Usuário cadastrado e vinculado à instituição com sucesso!", isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Lógica de reversão (rollback) mantida do seu código original
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
      appBar: AppBar(title: const Text("Cadastro de Instituição")),
      body: Stack(
        children: [
          if (_institutionsList.isEmpty && !_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "Nenhuma instituição disponível para cadastro no momento. Por favor, entre em contato com o administrador do sistema.",
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
                        "Selecione a instituição que você representa e preencha seus dados de acesso.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      
                      DropdownButtonFormField<Institution>(
                        decoration: _buildInputDecoration('Selecione sua Instituição'),
                        value: _selectedInstitution,
                        items: _institutionsList.map((institution) {
                          return DropdownMenuItem<Institution>(
                            value: institution,
                            child: Text(institution.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (institution) => setState(() => _selectedInstitution = institution),
                        validator: (value) => value == null ? 'É obrigatório selecionar uma instituição.' : null,
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
                        onPressed: _isLoading ? null : _registerInstituicao,
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