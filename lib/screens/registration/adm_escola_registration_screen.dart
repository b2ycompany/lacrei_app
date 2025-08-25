// lib/screens/registration/adm_escola_registration_screen.dart

// --- CORREÇÃO: Ajustado de 'dart.typed_data' para 'dart:typed_data' ---
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

class AdmEscolaRegistrationScreen extends StatefulWidget {
  const AdmEscolaRegistrationScreen({super.key});

  @override
  State<AdmEscolaRegistrationScreen> createState() => _AdmEscolaRegistrationScreenState();
}

class _AdmEscolaRegistrationScreenState extends State<AdmEscolaRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  Uint8List? _schoolImageBytes;

  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final _schoolNameController = TextEditingController();
  final _schoolPhoneController = TextEditingController();
  final _schoolCepController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _schoolAddressNumberController = TextEditingController();
  final _schoolAddressDistrictController = TextEditingController();
  final _schoolAddressCityController = TextEditingController();
  final _schoolAddressStateController = TextEditingController();
  final _responsibleNameController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();
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
      if (!_cepFocusNode.hasFocus) {
        _fetchAddressFromCep();
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Recortar Imagem', toolbarColor: Colors.deepPurple, toolbarWidgetColor: Colors.white, lockAspectRatio: true),
        IOSUiSettings(title: 'Recortar Imagem', aspectRatioLockEnabled: true, doneButtonTitle: 'Concluir', cancelButtonTitle: 'Cancelar'),
        WebUiSettings(context: context),
      ],
    );
    if (croppedFile != null) {
      final bytes = await croppedFile.readAsBytes();
      setState(() => _schoolImageBytes = bytes);
    }
  }

  Future<void> _registerAdmEscola() async {
    setState(() => _isLoading = true);
    User? user; 

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      user = userCredential.user;
      if (user == null) throw Exception("Falha ao criar usuário na autenticação.");

      final schoolDocRef = FirebaseFirestore.instance.collection('schools').doc();
      String? schoolImageUrl;

      if (_schoolImageBytes != null) {
        final storageRef = FirebaseStorage.instance.ref('school_avatars/${schoolDocRef.id}');
        await storageRef.putData(_schoolImageBytes!);
        schoolImageUrl = await storageRef.getDownloadURL();
      }

      final batch = FirebaseFirestore.instance.batch();

      batch.set(schoolDocRef, {
        'schoolName': _schoolNameController.text.trim(),
        'schoolType': 'particular', 
        'city': _schoolAddressCityController.text.trim(),
        'cep': _schoolCepController.text.trim(),
        'address': '${_schoolAddressController.text.trim()}, ${_schoolAddressNumberController.text.trim()}',
        'schoolPhone': _schoolPhoneController.text.trim(),
        'schoolDistrict': _schoolAddressDistrictController.text.trim(),
        'schoolState': _schoolAddressStateController.text.trim(),
        'schoolImageUrl': schoolImageUrl,
        'totalCollectedKg': 0,
        'adminUid': user.uid, 
        'createdAt': Timestamp.now(),
      });

      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'name': _responsibleNameController.text.trim(),
        'phone': _responsiblePhoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'adm_escola', 
        'schoolId': schoolDocRef.id,
      });
      
      await batch.commit();

      if (mounted) {
        _showSnackBar("Cadastro da escola e do administrador realizado com sucesso!", isError: false);
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
            _schoolAddressController.text = data['logradouro'];
            _schoolAddressDistrictController.text = data['bairro'];
            _schoolAddressCityController.text = data['localidade'];
            _schoolAddressStateController.text = data['uf'];
          });
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

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
      );
    }
  }

  @override
  void dispose() {
    _schoolNameController.dispose(); _schoolPhoneController.dispose(); _schoolCepController.dispose();
    _schoolAddressController.dispose(); _schoolAddressNumberController.dispose(); _schoolAddressDistrictController.dispose();
    _schoolAddressCityController.dispose(); _schoolAddressStateController.dispose(); _responsibleNameController.dispose();
    _responsiblePhoneController.dispose(); _emailController.dispose(); _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        _registerAdmEscola();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Admin da Escola")),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: () => _currentStep == 0 ? Navigator.of(context).pop() : setState(() => _currentStep -= 1),
            steps: [
              Step(
                title: const Text('Admin'),
                isActive: _currentStep >= 0,
                content: Form(
                  key: _formKeyStep0,
                  child: Column(children: [
                    TextFormField(controller: _responsibleNameController, decoration: _buildInputDecoration('Nome do Responsável'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _responsiblePhoneController, decoration: _buildInputDecoration('Telefone do Responsável'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
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
                title: const Text('Escola'),
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
                             backgroundImage: _schoolImageBytes != null ? MemoryImage(_schoolImageBytes!) : null,
                             child: _schoolImageBytes == null ? const Icon(Icons.school_outlined, size: 60, color: Colors.white70) : null,
                           ),
                           Container(
                             decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                             child: const Padding( padding: EdgeInsets.all(4.0), child: Icon(Icons.add_a_photo, color: Colors.white, size: 20) ),
                           )
                         ],
                       ),
                     ),
                     const SizedBox(height: 8),
                     const Text("Avatar da Escola (Opcional)", style: TextStyle(color: Colors.white70)),
                     const SizedBox(height: 24),
                     TextFormField(controller: _schoolNameController, decoration: _buildInputDecoration('Nome da Escola'), validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                     const SizedBox(height: 16),
                     TextFormField(controller: _schoolPhoneController, decoration: _buildInputDecoration('Telefone da Escola'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                ),
              ),
              Step(
                title: const Text('Endereço'),
                isActive: _currentStep >= 2,
                content: Form(
                  key: _formKeyStep2,
                  child: Column(children: [
                    TextFormField(controller: _schoolCepController, focusNode: _cepFocusNode, decoration: _buildInputDecoration('CEP da Escola'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _schoolAddressController, decoration: _buildInputDecoration('Rua / Logradouro')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _schoolAddressNumberController, decoration: _buildInputDecoration('Número'), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    TextFormField(controller: _schoolAddressDistrictController, decoration: _buildInputDecoration('Bairro')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _schoolAddressCityController, decoration: _buildInputDecoration('Cidade')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _schoolAddressStateController, decoration: _buildInputDecoration('Estado')),
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