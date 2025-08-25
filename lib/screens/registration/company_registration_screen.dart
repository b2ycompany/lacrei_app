// lib/screens/registration/company_registration_screen.dart

// --- CORREÇÃO: Ajustado de 'dart.typed_data' para 'dart:typed_data' ---
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lacrei_app/screens/login_screen.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../widgets/terms_dialog.dart';

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
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  Uint8List? _companyImageBytes;
  bool _termsAccepted = false;

  final _cnpjMaskFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});

  @override
  void dispose() {
    _companyNameController.dispose();
    _cnpjController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); 
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [ WebUiSettings(context: context) ],
    );
    if (croppedFile != null) {
      final bytes = await croppedFile.readAsBytes();
      setState(() => _companyImageBytes = bytes);
    }
  }

  Future<void> _registerCompany() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      _showSnackBar("Você precisa de aceitar os Termos de Serviço.");
      return;
    }

    setState(() => _isLoading = true);
    User? user; 

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      user = userCredential.user;
      if (user == null) throw Exception("Erro ao criar o utilizador de autenticação.");

      final companyName = _companyNameController.text.trim();
      await user.updateDisplayName(companyName);

      final companyDocRef = FirebaseFirestore.instance.collection('companies').doc(user.uid);
      String? companyImageUrl;

      if (_companyImageBytes != null) {
        final storageRef = FirebaseStorage.instance.ref('company_logos/${companyDocRef.id}');
        await storageRef.putData(_companyImageBytes!);
        companyImageUrl = await storageRef.getDownloadURL();
      }
      
      final batch = FirebaseFirestore.instance.batch();

      batch.set(companyDocRef, {
        'companyName': companyName,
        'cnpj': _cnpjController.text.trim(),
        'adminUid': user.uid,
        'companyImageUrl': companyImageUrl,
        'totalCollectedKg': 0,
        'createdAt': Timestamp.now(),
      });

      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'name': companyName,
        'email': _emailController.text.trim(),
        'role': 'company_admin',
        'companyId': companyDocRef.id,
      });
      
      await batch.commit();

      if (mounted) {
        _showSnackBar("Empresa cadastrada com sucesso!", isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (user != null) {
        await user.delete();
      }
      _showSnackBar("Ocorreu um erro durante o cadastro. Por favor, tente novamente. Detalhe: ${e.toString()}", isError: true);
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
  
  void _showTermsDialog() {
    showDialog(context: context, builder: (context) => const TermsDialog());
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
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: _companyImageBytes != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(_companyImageBytes!, fit: BoxFit.contain))
                          : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 40), SizedBox(height: 8), Text("Selecionar Logo")])),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(controller: _companyNameController, decoration: const InputDecoration(labelText: "Nome da Empresa"), validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _cnpjController, decoration: const InputDecoration(labelText: "CNPJ"), keyboardType: TextInputType.number, inputFormatters: [_cnpjMaskFormatter], validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: "E-mail de Contato (será o seu login)"), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: "Senha"), obscureText: true, validator: (v) => v!.length < 6 ? "A senha deve ter no mínimo 6 caracteres" : null),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController, 
                      decoration: const InputDecoration(labelText: "Confirmar Senha"), 
                      obscureText: true, 
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => v != _passwordController.text ? "As senhas não coincidem" : null
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      title: const Text("Li e aceito os Termos de Serviço e a Política de Privacidade."),
                      subtitle: GestureDetector(onTap: _showTermsDialog, child: const Text("Clique para ler os termos.", style: TextStyle(color: Colors.purpleAccent, decoration: TextDecoration.underline))),
                      value: _termsAccepted,
                      onChanged: (val) => setState(() => _termsAccepted = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 24),
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
          // --- CORREÇÃO: Trocado 'withOpacity(0.5)' por 'withAlpha(128)' ---
          if (_isLoading) Container(color: Colors.black.withAlpha(128), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}