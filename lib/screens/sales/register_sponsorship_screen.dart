// lib/screens/sales/register_sponsorship_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class RegisterSponsorshipScreen extends StatefulWidget {
  const RegisterSponsorshipScreen({super.key});

  @override
  State<RegisterSponsorshipScreen> createState() => _RegisterSponsorshipScreenState();
}

class _RegisterSponsorshipScreenState extends State<RegisterSponsorshipScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  DocumentSnapshot? _selectedPartner;
  DocumentSnapshot? _selectedPlan;
  DateTime _sponsorshipDate = DateTime.now();
  
  final _cnpjController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();
  final _loteController = TextEditingController();

  final _cnpjMaskFormatter = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMaskFormatter = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void dispose() {
    _cnpjController.dispose();
    _contactEmailController.dispose();
    _responsiblePhoneController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  Future<void> _registerSponsorship() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Utilizador não autenticado.")));
      return;
    }

    try {
      final partnerData = _selectedPartner!.data() as Map<String, dynamic>;
      final planData = _selectedPlan!.data() as Map<String, dynamic>;
      final expiryDate = DateTime(_sponsorshipDate.year + 1, _sponsorshipDate.month, _sponsorshipDate.day);
      
      final batch = FirebaseFirestore.instance.batch();

      final sponsorshipRef = FirebaseFirestore.instance.collection('sponsorships').doc();
      batch.set(sponsorshipRef, {
        'salespersonId': user.uid,
        'salespersonName': user.displayName,
        'partnerId': _selectedPartner!.id,
        'partnerName': partnerData['name'],
        'planId': _selectedPlan!.id,
        'planName': planData['name'],
        'planPrice': planData['price'],
        'cnpj': _cnpjController.text,
        'contactEmail': _contactEmailController.text,
        'responsiblePhone': _responsiblePhoneController.text,
        'lote': int.tryParse(_loteController.text) ?? 0,
        'sponsorshipDate': Timestamp.fromDate(_sponsorshipDate),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'status': 'active',
      });

      final salespersonRef = FirebaseFirestore.instance.collection('salespeople').doc(user.uid);
      batch.update(salespersonRef, {
        'salesCount': FieldValue.increment(1),
        'totalSalesValue': FieldValue.increment(planData['price']),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Patrocínio registado com sucesso!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao registar patrocínio: ${e.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registar Novo Patrocínio")),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDropdownFromCollection('partners', 'name', 'Selecione o Parceiro (Empresa)', (doc) {
                    final data = doc?.data() as Map<String, dynamic>?;
                    setState(() {
                      _selectedPartner = doc;
                      _contactEmailController.text = data?['contactEmail'] ?? '';
                      _responsiblePhoneController.text = data?['contactPhone'] ?? '';
                    });
                  }),
                  const SizedBox(height: 16),
                  _buildDropdownFromCollection('sponsorship_plans', 'name', 'Selecione o Plano', (doc) => setState(() => _selectedPlan = doc)),
                  const SizedBox(height: 24),
                  
                  TextFormField(controller: _cnpjController, decoration: const InputDecoration(labelText: 'CNPJ da Empresa'), inputFormatters: [_cnpjMaskFormatter], keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _contactEmailController, decoration: const InputDecoration(labelText: 'E-mail do Responsável'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextFormField(controller: _responsiblePhoneController, decoration: const InputDecoration(labelText: 'Telefone do Responsável'), inputFormatters: [_phoneMaskFormatter], keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  TextFormField(controller: _loteController, decoration: const InputDecoration(labelText: 'Lote (Nº de Urnas)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Data de Contratação'),
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _sponsorshipDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (picked != null) setState(() => _sponsorshipDate = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(DateFormat('dd/MM/yyyy').format(_sponsorshipDate)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerSponsorship,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Registar Patrocínio"),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildDropdownFromCollection(String collection, String nameField, String hint, ValueChanged<DocumentSnapshot?> onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return DropdownButtonFormField<DocumentSnapshot>(
          hint: Text(hint),
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<DocumentSnapshot>(value: doc, child: Text(data[nameField] ?? ''));
          }).toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Campo obrigatório' : null,
          isExpanded: true,
        );
      },
    );
  }
}