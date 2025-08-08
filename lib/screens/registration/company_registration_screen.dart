// lib/screens/registration/company_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lacrei_app/screens/login_screen.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() => _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // NOVOS CONTROLLERS PARA O ENDEREÇO
  final _cepController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressNumberController = TextEditingController();
  final _addressDistrictController = TextEditingController();
  
  bool _isLoading = false;
  final _cnpjMaskFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
  final _cepFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cepFocusNode.addListener(() {
      if (!_cepFocusNode.hasFocus) _fetchAddressFromCep();
    });
  }

  @override
  void dispose() {
    // ... dispose de todos os controllers ...
    _companyNameController.dispose();
    _cnpjController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _addressNumberController.dispose();
    _addressDistrictController.dispose();
    _cepFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAddressFromCep() async {
    final cep = _cepMaskFormatter.getUnmaskedText();
    if (cep.length != 8) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cep/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] != true) {
          setState(() {
            _addressController.text = data['logradouro'];
            _addressDistrictController.text = data['bairro'];
          });
        }
      }
    } catch (e) {
      // Tratar erro
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;
      if (user == null) throw Exception("Erro ao criar o utilizador.");

      final companyName = _companyNameController.text.trim();
      await user.updateDisplayName(companyName);

      final companyDocRef = FirebaseFirestore.instance.collection('companies').doc(user.uid);
      await companyDocRef.set({
        'companyName': companyName,
        'cnpj': _cnpjController.text.trim(),
        'adminUid': user.uid,
        'totalCollectedKg': 0,
        'createdAt': Timestamp.now(),
        // NOVOS CAMPOS DE ENDEREÇO
        'cep': _cepController.text.trim(),
        'address': _addressController.text.trim(),
        'addressNumber': _addressNumberController.text.trim(),
        'addressDistrict': _addressDistrictController.text.trim(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': companyName,
        'email': _emailController.text.trim(),
        'role': 'company_admin',
        'companyId': companyDocRef.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Empresa cadastrada com sucesso!"), backgroundColor: Colors.green));
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ocorreu um erro: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Empresa Parceira")),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(controller: _companyNameController, decoration: const InputDecoration(labelText: "Nome da Empresa"), validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _cnpjController, decoration: const InputDecoration(labelText: "CNPJ"), keyboardType: TextInputType.number, inputFormatters: [_cnpjMaskFormatter], validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: "E-mail de Contato (será o seu login)"), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: "Senha"), obscureText: true, validator: (v) => v!.length < 6 ? "A senha deve ter no mínimo 6 caracteres" : null),
                    const SizedBox(height: 24),
                    const Text("Endereço", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(controller: _cepController, focusNode: _cepFocusNode, decoration: const InputDecoration(labelText: "CEP"), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: "Rua / Logradouro"), validator: (v) => v!.isEmpty ? "Obrigatório" : null),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _addressNumberController, decoration: const InputDecoration(labelText: "Número"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Obrigatório" : null)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: _addressDistrictController, decoration: const InputDecoration(labelText: "Bairro"), validator: (v) => v!.isEmpty ? "Obrigatório" : null)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _registerCompany,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text("Cadastrar Empresa"),
                    ),
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