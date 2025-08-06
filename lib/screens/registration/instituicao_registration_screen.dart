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
    if (pickedFile == null) return;
    if (!mounted) return;

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

  Future<void> _registerInstituicao() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("As senhas não coincidem."); return;
    }
    setState(() => _isLoading = true);
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;

      if (user != null) {
        String? institutionImageUrl;
        final institutionDocRef = FirebaseFirestore.instance.collection('institutions').doc();

        if (_institutionImageBytes != null) {
          final storageRef = FirebaseStorage.instance.ref('institution_avatars/${institutionDocRef.id}');
          await storageRef.putData(_institutionImageBytes!);
          institutionImageUrl = await storageRef.getDownloadURL();
        }

        await institutionDocRef.set({
          'institutionName': _institutionNameController.text.trim(),
          'institutionPhone': _institutionPhoneController.text.trim(),
          'address': '${_institutionAddressController.text}, ${_institutionAddressNumberController.text}',
          'cep': _institutionCepController.text.trim(),
          'institutionImageUrl': institutionImageUrl,
          'adminUid': user.uid,
          'createdAt': Timestamp.now(),
        });

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _responsibleNameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'instituicao',
          'institutionId': institutionDocRef.id,
        });

        if (mounted) {
          _showSnackBar("Instituição cadastrada com sucesso!", isError: false);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Instituição")),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() => _currentStep += 1);
              } else {
                _registerInstituicao();
              }
            },
            onStepCancel: () => _currentStep == 0 ? Navigator.of(context).pop() : setState(() => _currentStep -= 1),
            steps: [
              Step(
                title: const Text('Acesso'),
                isActive: _currentStep >= 0,
                content: Column(children: [
                  TextFormField(controller: _responsibleNameController, decoration: _buildInputDecoration('Nome do Responsável')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _emailController, decoration: _buildInputDecoration('E-mail de Acesso'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextFormField(controller: _passwordController, decoration: _buildInputDecoration('Senha de Acesso'), obscureText: true),
                  const SizedBox(height: 16),
                  TextFormField(controller: _confirmPasswordController, decoration: _buildInputDecoration('Confirmar Senha'), obscureText: true),
                ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
              ),
              Step(
                title: const Text('Instituição'),
                isActive: _currentStep >= 1,
                content: Column(children: [
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
                   TextFormField(controller: _institutionNameController, decoration: _buildInputDecoration('Nome da Instituição')),
                   const SizedBox(height: 16),
                   TextFormField(controller: _institutionPhoneController, decoration: _buildInputDecoration('Telefone da Instituição'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
                ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
              ),
              Step(
                title: const Text('Endereço'),
                isActive: _currentStep >= 2,
                content: Column(children: [
                  TextFormField(controller: _institutionCepController, focusNode: _cepFocusNode, decoration: _buildInputDecoration('CEP'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _institutionAddressController, decoration: _buildInputDecoration('Rua / Logradouro')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _institutionAddressNumberController, decoration: _buildInputDecoration('Número'), keyboardType: TextInputType.number),
                ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
              ),
            ],
          ),
          if (_isLoading) Container(color: Colors.black.withAlpha(128), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}