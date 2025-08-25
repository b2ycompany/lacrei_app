// lib/screens/registration/instituicao_registration_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../login_screen.dart';

class InstituicaoRegistrationScreen extends StatefulWidget {
  const InstituicaoRegistrationScreen({super.key});

  @override
  State<InstituicaoRegistrationScreen> createState() => _InstituicaoRegistrationScreenState();
}

class _InstituicaoRegistrationScreenState extends State<InstituicaoRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  Uint8List? _institutionImageBytes;

  // --- CORREÇÃO: Adicionadas chaves para cada etapa do formulário ---
  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final _institutionNameController = TextEditingController();
  final _institutionPhoneController = TextEditingController();
  final _institutionCepController = TextEditingController();
  final _institutionAddressController = TextEditingController();
  final _institutionAddressNumberController = TextEditingController();
  final _responsibleNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _cepFocusNode = FocusNode();
  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _cepFocusNode.addListener(() {
      if (!_cepFocusNode.hasFocus) _fetchAddressFromCep();
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Recortar', lockAspectRatio: true),
        IOSUiSettings(title: 'Recortar', aspectRatioLockEnabled: true),
        WebUiSettings(context: context),
      ],
    );
    if (croppedFile != null) {
      final bytes = await croppedFile.readAsBytes();
      setState(() => _institutionImageBytes = bytes);
    }
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
          setState(() => _institutionAddressController.text = data['logradouro']);
        } else {
          _showSnackBar("CEP não encontrado.");
        }
      }
    } catch (e) {
      _showSnackBar("Erro ao buscar o CEP.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- CORREÇÃO: Lógica de registro aprimorada com rollback ---
  Future<void> _registerInstituicao() async {
    setState(() => _isLoading = true);
    User? user; // Variável para guardar o usuário da Auth

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      user = userCredential.user;
      if (user == null) throw Exception("Falha ao criar usuário na autenticação.");

      final institutionDocRef = FirebaseFirestore.instance.collection('institutions').doc();
      String? institutionImageUrl;

      if (_institutionImageBytes != null) {
        final storageRef = FirebaseStorage.instance.ref('institution_avatars/${institutionDocRef.id}');
        await storageRef.putData(_institutionImageBytes!);
        institutionImageUrl = await storageRef.getDownloadURL();
      }

      // Usar um "batch write" para garantir atomicidade
      final batch = FirebaseFirestore.instance.batch();

      // Grava os dados da instituição
      batch.set(institutionDocRef, {
        'institutionName': _institutionNameController.text.trim(),
        'institutionPhone': _institutionPhoneController.text.trim(),
        'address': '${_institutionAddressController.text}, ${_institutionAddressNumberController.text}',
        'cep': _institutionCepController.text.trim(),
        'institutionImageUrl': institutionImageUrl,
        'adminUid': user.uid, // Essencial para a regra de segurança
        'createdAt': Timestamp.now(),
      });

      // Grava os dados do usuário administrador da instituição
      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'name': _responsibleNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'instituicao', // Permitido pela nova regra do Firestore
        'institutionId': institutionDocRef.id,
      });

      await batch.commit(); // Executa as duas operações

      if (mounted) {
        _showSnackBar("Instituição cadastrada com sucesso!", isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // LÓGICA DE REVERSÃO (ROLLBACK)
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

  @override
  void dispose() {
    _institutionNameController.dispose(); _institutionPhoneController.dispose();
    _institutionCepController.dispose(); _institutionAddressController.dispose();
    _institutionAddressNumberController.dispose(); _responsibleNameController.dispose();
    _emailController.dispose(); _passwordController.dispose(); _confirmPasswordController.dispose();
    _cepFocusNode.dispose();
    super.dispose();
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

  // --- CORREÇÃO: Lógica para validar e avançar etapas ---
  void _onStepContinue() {
    bool isStepValid = false;
    if (_currentStep == 0) {
      isStepValid = _formKeyStep0.currentState?.validate() ?? false;
    } else if (_currentStep == 1) {
      isStepValid = _formKeyStep1.currentState?.validate() ?? false;
    } else if (_currentStep == 2) {
      isStepValid = _formKeyStep2.currentState?.validate() ?? false;
    }

    if (isStepValid) {
      if (_currentStep < 2) {
        setState(() => _currentStep += 1);
      } else {
        _registerInstituicao();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Instituição")),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: () => _currentStep == 0 ? Navigator.of(context).pop() : setState(() => _currentStep -= 1),
            steps: [
              Step(
                title: const Text('Acesso'),
                isActive: _currentStep >= 0,
                content: Form(
                  key: _formKeyStep0,
                  child: Column(children: [
                    TextFormField(controller: _responsibleNameController, decoration: _buildInputDecoration('Nome do Responsável'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _emailController, decoration: _buildInputDecoration('E-mail de Acesso'), keyboardType: TextInputType.emailAddress, validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'E-mail inválido' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, decoration: _buildInputDecoration('Senha de Acesso'), obscureText: true, validator: (v) => (v?.length ?? 0) < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _confirmPasswordController, decoration: _buildInputDecoration('Confirmar Senha'), obscureText: true, autovalidateMode: AutovalidateMode.onUserInteraction, validator: (v) => v != _passwordController.text ? 'As senhas não coincidem' : null),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                ),
              ),
              Step(
                title: const Text('Instituição'),
                isActive: _currentStep >= 1,
                content: Form(
                  key: _formKeyStep1,
                  child: Column(children: [
                     GestureDetector(
                       onTap: _pickImage,
                       child: Stack(
                         alignment: Alignment.bottomRight,
                         children: [
                           CircleAvatar(
                             radius: 60,
                             backgroundColor: Colors.white.withAlpha(25),
                             backgroundImage: _institutionImageBytes != null ? MemoryImage(_institutionImageBytes!) : null,
                             child: _institutionImageBytes == null ? const Icon(Icons.corporate_fare, size: 60, color: Colors.white70) : null,
                           ),
                           Container(
                             decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                             child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.add_a_photo, color: Colors.white, size: 20)),
                           )
                         ],
                       ),
                     ),
                     const SizedBox(height: 8),
                     const Text("Avatar da Instituição", style: TextStyle(color: Colors.white70)),
                     const SizedBox(height: 24),
                     TextFormField(controller: _institutionNameController, decoration: _buildInputDecoration('Nome da Instituição'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                     const SizedBox(height: 16),
                     TextFormField(controller: _institutionPhoneController, decoration: _buildInputDecoration('Telefone da Instituição'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                ),
              ),
              Step(
                title: const Text('Endereço'),
                isActive: _currentStep >= 2,
                content: Form(
                  key: _formKeyStep2,
                  child: Column(children: [
                    TextFormField(controller: _institutionCepController, focusNode: _cepFocusNode, decoration: _buildInputDecoration('CEP'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _institutionAddressController, decoration: _buildInputDecoration('Rua / Logradouro'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _institutionAddressNumberController, decoration: _buildInputDecoration('Número'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                ),
              ),
            ],
          ),
          if (_isLoading) Container(color: Colors.black.withAlpha(128), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}