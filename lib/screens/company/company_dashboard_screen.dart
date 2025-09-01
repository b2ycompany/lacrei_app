// lib/screens/company/company_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../profile_selection_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  // Variáveis de estado para controlar o carregamento e os dados
  bool _isLoading = true;
  String? _errorMessage;
  DocumentSnapshot? _companyDoc; // Para guardar os dados da empresa

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  // Lógica de carregamento de dados refeita para seguir o fluxo correto
  Future<void> _loadCompanyData() async {
    // Garante que o estado seja atualizado no início
    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Obter o usuário logado
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não autenticado.");
      }

      // 2. Buscar o perfil do usuário na coleção 'users' para encontrar o companyId
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception("Perfil do usuário não encontrado no Firestore.");
      }

      // 3. Obter o ID da empresa a partir do perfil do usuário
      final companyId = userDoc.data()!['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) {
        throw Exception("Este usuário não está vinculado a nenhuma empresa.");
      }

      // 4. Usar o companyId para buscar os dados corretos na coleção 'companies'
      final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (!companyDoc.exists) {
        throw Exception("A empresa vinculada a este perfil não foi encontrada.");
      }

      // 5. Se tudo deu certo, armazena os dados da empresa e para de carregar
      if (mounted) {
        setState(() {
          _companyDoc = companyDoc;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // --- FUNÇÃO DE LOGOUT MELHORADA ---
  Future<void> _logout() async {
    // --- ALTERAÇÃO 1: Adicionar diálogo de confirmação ---
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Saída'),
        content: const Text('Tem a certeza de que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    // Se o usuário não confirmou (pressionou cancelar ou fora do dialog), a função para aqui.
    if (confirmLogout != true) {
      return;
    }

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // --- ALTERAÇÃO 2: Adicionar tratamento de erro ---
      // Se ocorrer um erro, mostramos uma SnackBar com a mensagem.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao tentar sair: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel da Empresa"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Tela de Carregamento
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Tela de Erro (agora com detalhes)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Erro ao carregar dados da empresa.\n\nDetalhe: $_errorMessage",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
        ),
      );
    }

    // Tela de Sucesso (Painel com os dados corretos)
    if (_companyDoc != null) {
      final companyData = _companyDoc!.data() as Map<String, dynamic>;
      final user = FirebaseAuth.instance.currentUser;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bem-vindo(a), ${user?.displayName ?? ''}!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              companyData['companyName'] ?? 'Nome da Empresa não encontrado',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const Divider(height: 32),
            
            // Aqui você pode adicionar todos os seus indicadores e funcionalidades
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Tipo de Empresa"),
                subtitle: Text(companyData['companyType'] ?? 'Não informado'),
              ),
            ),
             Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: const Text("CNPJ"),
                subtitle: Text(companyData['cnpj'] ?? 'Não informado'),
              ),
            ),
            // Adicione mais cards conforme sua necessidade...
          ],
        ),
      );
    }
    
    // Estado de segurança, caso algo inesperado ocorra
    return const Center(child: Text("Ocorreu um erro inesperado."));
  }
}
