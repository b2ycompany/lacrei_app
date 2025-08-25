// lib/screens/registration/aluno_registration_screen.dart

import 'dart:typed_data';
import 'dart:math';
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
import '../login_screen.dart';
import '../../widgets/terms_dialog.dart';
import '../../widgets/guardian_terms_dialog.dart';

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

  // --- NOVO: Variáveis para o Nível de Ensino ---
  String? _selectedEducationLevel;
  final List<String> _educationLevels = ['Ensino Fundamental', 'Ensino Médio', 'Ensino Superior'];

  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  String _userType = 'aluno';
  final _positionController = TextEditingController();
  final _gradeController = TextEditingController();
  final _guardianController = TextEditingController();
  bool _showGuardianTerms = false;
  int _calculatedAge = 0;
  bool _termsAccepted = false;
  bool _guardianTermsAccepted = false;

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

  @override
  void dispose() {
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
    _positionController.dispose();
    _gradeController.dispose();
    _guardianController.dispose();
    _cepFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('schools').orderBy('schoolName').get();
      final schools = snapshot.docs.map((doc) => School(id: doc.id, name: doc.data()['schoolName'] ?? 'Nome não encontrado')).toList();
      if(mounted) setState(() => _schoolsList = schools);
    } catch (e) {
      _showSnackBar("Erro ao carregar a lista de escolas: ${e.toString()}", isError: true);
    }
  }
  
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null || !mounted) return;
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [ WebUiSettings(context: context) ],
    );
    if (croppedFile != null) {
      final bytes = await croppedFile.readAsBytes();
      setState(() => _studentImageBytes = bytes);
    }
  }

  Future<void> _registerUser() async {
    setState(() => _isLoading = true);
    User? user; 

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      user = userCredential.user;
      if (user == null) throw Exception("Erro ao criar usuário na autenticação.");

      String? studentImageUrl;
      if (_studentImageBytes != null) {
        final storageRef = FirebaseStorage.instance.ref('student_avatars/${user.uid}');
        await storageRef.putData(_studentImageBytes!);
        studentImageUrl = await storageRef.getDownloadURL();
      }

      final studentName = _nameController.text.trim();
      await user.updateDisplayName(studentName);
      if(studentImageUrl != null) await user.updatePhotoURL(studentImageUrl);
      
      final luckyNumber = '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(100)}';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': studentName, 'email': _emailController.text.trim(), 'userImageUrl': studentImageUrl,
        'role': 'aluno', 'schoolId': _selectedSchool!.id, 'schoolName': _selectedSchool!.name,
        'schoolLinkStatus': 'pending', 'phone': _phoneController.text.trim(), 'birthDate': _birthDateController.text.trim(),
        'cep': _cepController.text.trim(), 'address': _addressController.text.trim(), 'createdAt': Timestamp.now(),
        'age': _calculatedAge, 'userType': _userType,
        // --- NOVO: Salvando o nível de ensino no banco de dados ---
        'educationLevel': _selectedEducationLevel,
        'grade': _userType == 'aluno' ? _gradeController.text.trim() : null,
        'position': _userType == 'funcionario' ? _positionController.text.trim() : null,
        'guardianName': _showGuardianTerms ? _guardianController.text.trim() : null,
        'luckyNumber': luckyNumber,
      });

      await FirebaseFirestore.instance.collection('schools').doc(_selectedSchool!.id).collection('pendingRequests').doc(user.uid).set({
        'studentName': studentName, 'studentUid': user.uid,
        'studentImageUrl': studentImageUrl, 'requestDate': Timestamp.now(),
      });

      if (mounted) {
        _showSnackBar("Cadastro realizado! Aguardando aprovação da escola.", isError: false);
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    } catch (e) {
      if (user != null) {
        await user.delete();
      }
      _showSnackBar("Ocorreu um erro durante o cadastro. Detalhe: ${e.toString()}", isError: true);
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
            _addressController.text = data['logradouro']; _addressDistrictController.text = data['bairro'];
            _addressCityController.text = data['localidade']; _addressStateController.text = data['uf'];
          });
        }
      }
    } catch (e) {
      _showSnackBar("Erro ao buscar CEP", isError: true);
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
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1920), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'));
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        _calculatedAge = _calculateAge(picked);
        _showGuardianTerms = _calculatedAge < 16;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green));
    }
  }
  
  InputDecoration _buildInputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label, suffixIcon: suffixIcon, labelStyle: const TextStyle(color: Colors.white70), filled: true,
      fillColor: Colors.white.withAlpha(25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,),
    );
  }
  
  void _showTermsDialog() {
    showDialog(context: context, builder: (context) => const TermsDialog());
  }
  
  void _showGuardianTermsDialog() {
    showDialog(context: context, builder: (context) => const GuardianTermsDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Aluno/Funcionário")),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: () {
              bool isStepValid = false;
              if (_currentStep == 0) {
                 isStepValid = _formKeyStep0.currentState?.validate() ?? false;
              } else if (_currentStep == 1) {
                 isStepValid = _formKeyStep1.currentState?.validate() ?? false;
                 if (isStepValid && _showGuardianTerms && !_guardianTermsAccepted) {
                    _showSnackBar("O responsável precisa aceitar os Termos para menores.");
                    isStepValid = false;
                 }
              } else if (_currentStep == 2) {
                isStepValid = _formKeyStep2.currentState?.validate() ?? false;
                if (isStepValid && !_termsAccepted) {
                  _showSnackBar("Você precisa aceitar os Termos de Serviço.");
                  isStepValid = false;
                }
              }

              if (_currentStep == 2 && isStepValid) { 
                _registerUser(); 
              } 
              else if (isStepValid) { 
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
                content: Form(
                  key: _formKeyStep0,
                  child: Column(children: [
                    TextFormField(controller: _emailController, decoration: _buildInputDecoration('E-mail'), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, decoration: _buildInputDecoration('Senha (mínimo 6 caracteres)'), obscureText: true, validator: (v) => (v?.length ?? 0) < 6 ? 'A senha é muito curta.' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _confirmPasswordController, decoration: _buildInputDecoration('Confirmar Senha'), obscureText: true, autovalidateMode: AutovalidateMode.onUserInteraction, validator: (v) => v != _passwordController.text ? 'As senhas não coincidem.' : null),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                )
              ),
              Step(
                title: const Text('Pessoal'),
                isActive: _currentStep >= 1,
                content: Form(
                  key: _formKeyStep1,
                  child: Column(children: [
                    GestureDetector(onTap: _pickImage, child: Stack(alignment: Alignment.bottomRight, children: [ CircleAvatar(radius: 60, backgroundColor: Colors.white.withAlpha(25), backgroundImage: _studentImageBytes != null ? MemoryImage(_studentImageBytes!) : null, child: _studentImageBytes == null ? const Icon(Icons.person_add_alt_1, size: 60, color: Colors.white70) : null), Container(decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle), child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.add_a_photo, color: Colors.white, size: 20),),)])),
                    const SizedBox(height: 8), const Text("Sua Foto (Opcional)", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    ToggleButtons(
                      isSelected: [_userType == 'aluno', _userType == 'funcionario'],
                      onPressed: (index) => setState(() => _userType = index == 0 ? 'aluno' : 'funcionario'),
                      borderRadius: BorderRadius.circular(8),
                      constraints: BoxConstraints(minWidth: (MediaQuery.of(context).size.width - 80) / 2, minHeight: 40),
                      children: const [ Text('Sou Aluno'), Text('Sou Funcionário') ],
                    ),
                    const SizedBox(height: 16),
                    
                    // --- NOVO: Campo de Nível de Ensino ---
                    DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration('Nível de Ensino'),
                      value: _selectedEducationLevel,
                      items: _educationLevels.map((level) => DropdownMenuItem(value: level, child: Text(level))).toList(),
                      onChanged: (value) => setState(() => _selectedEducationLevel = value),
                      validator: (value) => value == null ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(controller: _nameController, decoration: _buildInputDecoration('Nome Completo'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                    const SizedBox(height: 16),

                    if (_userType == 'funcionario')
                        TextFormField(controller: _positionController, decoration: _buildInputDecoration('Qual o seu Cargo?'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null).animate().fade(),
                    if (_userType == 'aluno')
                        TextFormField(controller: _gradeController, decoration: _buildInputDecoration('Série / Ano'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null).animate().fade(),
                    const SizedBox(height: 16),
                    
                    // --- ALTERADO: Label do campo ---
                    DropdownButtonFormField<School>(decoration: _buildInputDecoration('Selecione sua Escola/Faculdade'), value: _selectedSchool, items: _schoolsList.map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (s) => setState(() => _selectedSchool = s), validator: (value) => value == null ? 'Obrigatório' : null, isExpanded: true),
                    const SizedBox(height: 16),
                    TextFormField(controller: _birthDateController, decoration: _buildInputDecoration('Data de Nascimento', suffixIcon: const Icon(Icons.calendar_today)), inputFormatters: [_birthDateMaskFormatter], onTap: () => _selectDate(context), readOnly: true, validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                    if (_showGuardianTerms)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextFormField(
                             controller: _guardianController,
                             decoration: _buildInputDecoration('Nome do Responsável'),
                             validator: (v) => v!.isEmpty ? 'Obrigatório' : null
                          ),
                        ).animate().fade(),
                    if (_showGuardianTerms)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: CheckboxListTile(
                            title: const Text("O meu responsável leu e aceita os Termos de Consentimento para a minha participação."),
                            subtitle: GestureDetector(onTap: _showGuardianTermsDialog, child: const Text("Clique para ler os termos do responsável.", style: TextStyle(color: Colors.purpleAccent, decoration: TextDecoration.underline))),
                            value: _guardianTermsAccepted,
                            onChanged: (val) => setState(() => _guardianTermsAccepted = val!),
                            controlAffinity: ListTileControlAffinity.leading, activeColor: Colors.purpleAccent,
                          ),
                        ).animate().fade(),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                )
              ),
              Step(
                title: const Text('Contato & Termos'),
                isActive: _currentStep >= 2,
                content: Form(
                  key: _formKeyStep2,
                  child: Column(children: [
                    TextFormField(controller: _phoneController, decoration: _buildInputDecoration('Telefone / WhatsApp'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    TextFormField(controller: _cepController, focusNode: _cepFocusNode, decoration: _buildInputDecoration('CEP'), inputFormatters: [_cepMaskFormatter], keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    TextFormField(controller: _addressController, decoration: _buildInputDecoration('Rua / Logradouro')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _addressNumberController, decoration: _buildInputDecoration('Número'), keyboardType: TextInputType.number),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      title: const Text("Li e aceito os Termos de Serviço e a Política de Privacidade."),
                      subtitle: GestureDetector(onTap: _showTermsDialog, child: const Text("Clique para ler os termos.", style: TextStyle(color: Colors.purpleAccent, decoration: TextDecoration.underline))),
                      value: _termsAccepted,
                      onChanged: (val) => setState(() => _termsAccepted = val!),
                      controlAffinity: ListTileControlAffinity.leading, activeColor: Colors.purpleAccent,
                    ),
                  ]).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                )
              ),
            ],
          ),
          if (_isLoading) Container(color: Colors.black.withAlpha(128), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}