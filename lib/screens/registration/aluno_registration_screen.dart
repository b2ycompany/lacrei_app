// lib/screens/registration/aluno_registration_screen.dart

import 'dart:io';
// CORREÇÃO: Adicionada a importação que faltava para Uint8List
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../student/student_dashboard_screen.dart';

class School {
  final String id;
  final String name;
  School({required this.id, required this.name});
}

class AlunoRegistrationScreen extends StatefulWidget {
  const AlunoRegistrationScreen({super.key});

  @override
  State<AlunoRegistrationScreen> createState() => _AlunoRegistrationScreenState();
}

class _AlunoRegistrationScreenState extends State<AlunoRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  Uint8List? _studentImageBytes;
  
  List<School> _schoolsList = [];
  School? _selectedSchool;

  final _gradeController = TextEditingController();
  final _guardianController = TextEditingController();
  bool _showGuardianField = false;
  int _calculatedAge = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressNumberController = TextEditingController();
  final _addressDistrictController = TextEditingController();
  final _addressCityController = TextEditingController();
  final _addressStateController = TextEditingController();
  final _instagramController = TextEditingController();
  final _cepFocusNode = FocusNode();

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMaskFormatter = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
  final _birthDateMaskFormatter = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _cepFocusNode.addListener(() {
      if (!_cepFocusNode.hasFocus) _fetchAddressFromCep();
    });
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('schools').orderBy('schoolName').get();
      final schools = snapshot.docs.map((doc) {
        return School(id: doc.id, name: doc.data()['schoolName'] ?? 'Nome não encontrado');
      }).toList();
      setState(() => _schoolsList = schools);
    } catch (e) {
      _showSnackBar("Erro ao carregar a lista de escolas.");
    }
  }
  
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
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
      setState(() => _studentImageBytes = bytes);
    }
  }

  Future<void> _registerUser() async {
    if (_selectedSchool == null || _nameController.text.isEmpty || _birthDateController.text.isEmpty || _gradeController.text.isEmpty) {
      _showSnackBar("Por favor, preencha todos os campos pessoais."); return;
    }
    if (_showGuardianField && _guardianController.text.isEmpty) {
      _showSnackBar("Por favor, preencha o nome do responsável."); return;
    }

    setState(() => _isLoading = true);
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;

      if (user != null) {
        String? studentImageUrl;
        if (_studentImageBytes != null) {
          final storageRef = FirebaseStorage.instance.ref('student_avatars/${user.uid}');
          await storageRef.putData(_studentImageBytes!);
          studentImageUrl = await storageRef.getDownloadURL();
        }

        final studentName = _nameController.text.trim();
        await user.updateDisplayName(studentName);
        if(studentImageUrl != null) await user.updatePhotoURL(studentImageUrl);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': studentName,
          'email': _emailController.text.trim(),
          'userImageUrl': studentImageUrl,
          'role': 'aluno',
          'schoolId': _selectedSchool!.id,
          'schoolName': _selectedSchool!.name,
          'schoolLinkStatus': 'pending',
          'phone': _phoneController.text.trim(),
          'birthDate': _birthDateController.text.trim(),
          'cep': _cepController.text.trim(),
          'address': _addressController.text.trim(),
          'createdAt': Timestamp.now(),
          'age': _calculatedAge,
          'grade': _gradeController.text.trim(),
          if (_showGuardianField) 'guardianName': _guardianController.text.trim(),
        });

        await FirebaseFirestore.instance
            .collection('schools')
            .doc(_selectedSchool!.id)
            .collection('pendingRequests')
            .doc(user.uid)
            .set({
          'studentName': studentName,
          'studentUid': user.uid,
          'studentImageUrl': studentImageUrl,
          'requestDate': Timestamp.now(),
        });

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const StudentDashboardScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Ocorreu um erro.");
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
            _addressController.text = data['logradouro'];
            _addressDistrictController.text = data['bairro'];
            _addressCityController.text = data['localidade'];
            _addressStateController.text = data['uf'];
          });
        } else {
          _showSnackBar("CEP não encontrado.");
        }
      }
    } catch (e) {
      _showSnackBar("Erro ao buscar o CEP. Verifique sua conexão.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).requestFocus(FocusNode());
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: DateTime.now(), firstDate: DateTime(1920), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        _calculatedAge = _calculateAge(picked);
        if (_calculatedAge < 13) {
          _showGuardianField = true;
        } else {
          _showGuardianField = false;
        }
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }
  
  @override
  void dispose() {
    _gradeController.dispose();
    _guardianController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _addressNumberController.dispose();
    _addressDistrictController.dispose();
    _addressCityController.dispose();
    _addressStateController.dispose();
    _instagramController.dispose();
    _cepFocusNode.dispose();
    super.dispose();
  }
  
  InputDecoration _buildInputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label, suffixIcon: suffixIcon, labelStyle: const TextStyle(color: Colors.white70), filled: true,
      fillColor: Colors.white.withAlpha(25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Aluno")),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: () {
              bool isStepValid = false;
              if (_currentStep == 0) {
                 if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty) {
                    if (_passwordController.text != _confirmPasswordController.text) {
                      _showSnackBar("As senhas não coincidem.");
                    } else {
                      isStepValid = true;
                    }
                 } else {
                   _showSnackBar("Preencha todos os campos de conta.");
                 }
              } else if (_currentStep == 1) {
                 if (_nameController.text.isNotEmpty && _selectedSchool != null && _birthDateController.text.isNotEmpty && _gradeController.text.isNotEmpty) {
                    isStepValid = true;
                 } else {
                    _showSnackBar("Preencha todos os campos pessoais.");
                 }
              }

              final isLastStep = _currentStep == 2;
              if (isLastStep) {
                 _registerUser();
              } else if (isStepValid) {
                setState(() => _currentStep += 1);
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              } else {
                Navigator.of(context).pop();
              }
            },
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              return Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Row(
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 2 ? 'Finalizar Cadastro' : 'Continuar'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(_currentStep == 0 ? 'Cancelar' : 'Voltar'),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Conta'),
                isActive: _currentStep >= 0,
                content: Column(children: [
                  TextFormField(controller: _emailController, decoration: _buildInputDecoration('E-mail'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextFormField(controller: _passwordController, decoration: _buildInputDecoration('Senha'), obscureText: true),
                  const SizedBox(height: 16),
                  TextFormField(controller: _confirmPasswordController, decoration: _buildInputDecoration('Confirmar Senha'), obscureText: true),
                ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
              ),
              Step(
                title: const Text('Pessoal'),
                isActive: _currentStep >= 1,
                content: Column(children: [
                   GestureDetector(onTap: _pickImage, child: Stack(alignment: Alignment.bottomRight, children: [ CircleAvatar(radius: 60, backgroundColor: Colors.white.withAlpha(25), backgroundImage: _studentImageBytes != null ? MemoryImage(_studentImageBytes!) : null, child: _studentImageBytes == null ? const Icon(Icons.person_add_alt_1, size: 60, color: Colors.white70) : null), Container(decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle), child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.add_a_photo, color: Colors.white, size: 20),),)])),
                   const SizedBox(height: 8),
                   const Text("Sua Foto (Opcional)", style: TextStyle(color: Colors.white70)),
                   const SizedBox(height: 24),
                   TextFormField(controller: _nameController, decoration: _buildInputDecoration('Nome Completo')),
                   const SizedBox(height: 16),
                   DropdownButtonFormField<School>(decoration: _buildInputDecoration('Selecione sua Escola'), value: _selectedSchool, items: _schoolsList.map((school) => DropdownMenuItem(value: school, child: Text(school.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (School? school) => setState(() => _selectedSchool = school), validator: (value) => value == null ? 'Campo obrigatório' : null, isExpanded: true),
                   const SizedBox(height: 16),
                   TextFormField(controller: _birthDateController, decoration: _buildInputDecoration('Data de Nascimento', suffixIcon: const Icon(Icons.calendar_today)), inputFormatters: [_birthDateMaskFormatter], onTap: () => _selectDate(context), readOnly: true),
                   const SizedBox(height: 16),
                   TextFormField(controller: _gradeController, decoration: _buildInputDecoration('Série / Ano')),
                   const SizedBox(height: 16),
                   if (_showGuardianField)
                      TextFormField(controller: _guardianController, decoration: _buildInputDecoration('Nome do Responsável')).animate().fade(),
                ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
              ),
              Step(
                title: const Text('Contato'),
                isActive: _currentStep >= 2,
                content: Column(children: [
                  TextFormField(controller: _phoneController, decoration: _buildInputDecoration('Telefone / WhatsApp'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  TextFormField(controller: _cepController, focusNode: _cepFocusNode, decoration: _buildInputDecoration('CEP'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressController, decoration: _buildInputDecoration('Rua / Logradouro')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressNumberController, decoration: _buildInputDecoration('Número'), keyboardType: TextInputType.number),
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