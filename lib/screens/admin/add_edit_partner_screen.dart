// lib/screens/admin/add_edit_partner_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AddEditPartnerScreen extends StatefulWidget {
  final DocumentSnapshot? partner;
  const AddEditPartnerScreen({super.key, this.partner});

  @override
  State<AddEditPartnerScreen> createState() => _AddEditPartnerScreenState();
}

class _AddEditPartnerScreenState extends State<AddEditPartnerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _contactEmailController;
  late TextEditingController _contactPhoneController;
  
  CroppedFile? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;

  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    final isEditing = widget.partner != null;
    
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _contactEmailController = TextEditingController();
    _contactPhoneController = TextEditingController();

    if (isEditing) {
      final data = widget.partner!.data() as Map<String, dynamic>?;
      _nameController.text = data?['name'] as String? ?? '';
      _descriptionController.text = data?['description'] as String? ?? '';
      _contactEmailController.text = data?['contactEmail'] as String? ?? '';
      _contactPhoneController.text = data?['contactPhone'] as String? ?? '';
      _existingImageUrl = data?['imageUrl'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (!mounted || pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [ WebUiSettings(context: context) ],
    );

    if (croppedFile != null) {
      setState(() {
        _imageFile = croppedFile;
        _existingImageUrl = null;
      });
    }
  }

  Future<void> _savePartner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null && _existingImageUrl == null) {
      _showSnackBar("Por favor, selecione uma imagem.", isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      String imageUrl = _existingImageUrl ?? '';
      final docId = widget.partner?.id ?? FirebaseFirestore.instance.collection('partners').doc().id;

      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        final storageRef = FirebaseStorage.instance.ref('partner_images/$docId');
        await storageRef.putData(imageBytes);
        imageUrl = await storageRef.getDownloadURL();
      }

      final partnerData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'contactEmail': _contactEmailController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'createdAt': widget.partner?.data() != null ? (widget.partner!.data() as Map<String, dynamic>)['createdAt'] : Timestamp.now(),
      };

      if (widget.partner != null) {
        await FirebaseFirestore.instance.collection('partners').doc(widget.partner!.id).update(partnerData);
      } else {
        await FirebaseFirestore.instance.collection('partners').doc(docId).set(partnerData);
      }
      
      _showSnackBar("Parceiro salvo com sucesso!", isError: false);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showSnackBar("Erro ao salvar parceiro: ${e.toString()}", isError: true);
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
  
  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return kIsWeb ? Image.network(_imageFile!.path, fit: BoxFit.cover) : Image.file(File(_imageFile!.path), fit: BoxFit.cover);
    }
    if (_existingImageUrl != null) {
      return Image.network(_existingImageUrl!, fit: BoxFit.cover);
    }
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 40), SizedBox(height: 8), Text("Selecionar Imagem")]));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.partner != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Editar Parceiro" : "Adicionar Parceiro")),
      body: Stack(
        children: [
          SingleChildScrollView(
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
                      child: ClipRRect(borderRadius: BorderRadius.circular(11), child: _buildImagePreview()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nome do Parceiro"),
                    validator: (value) => value == null || value.isEmpty ? "Campo obrigatório" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: "Descrição da Promoção"),
                    maxLines: 3,
                    validator: (value) => value == null || value.isEmpty ? "Campo obrigatório" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(labelText: "E-mail de Contato na Empresa"),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Campo obrigatório";
                      if (!value.contains('@')) return "E-mail inválido";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactPhoneController,
                    decoration: const InputDecoration(labelText: "Telefone de Contato"),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneMaskFormatter],
                    validator: (value) => value == null || value.isEmpty ? "Campo obrigatório" : null,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _savePartner,
                    icon: const Icon(Icons.save),
                    label: Text(isEditing ? "Salvar Alterações" : "Adicionar Parceiro"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  )
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black.withAlpha(128), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}