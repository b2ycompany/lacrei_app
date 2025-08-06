import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:lacrei_app/screens/profile_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700, color: Colors.white),
      bodyTextStyle: TextStyle(fontSize: 19.0, color: Colors.white70),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Color.fromARGB(255, 48, 20, 78),
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      globalBackgroundColor: const Color.fromARGB(255, 48, 20, 78),
      pages: [
        PageViewModel(
          title: "Bem-vindo ao Projeto Lacrei!",
          body: "Junte-se a nós em uma campanha para arrecadar lacres de alumínio e ajudar a APAE.",
          //
          // <<<<<<<<<<<<<<<<<<<< ALTERAÇÃO AQUI <<<<<<<<<<<<<<<<<<<<
          //
          image: Center(
            child: Image.asset('assets/Marca_Lacrei.png', width: 250),
          ),
          //
          // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
          //
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Como Funciona?",
          body: "Sua escola acumula pontos ao arrecadar lacres. Acompanhe o progresso e concorra a prêmios incríveis de nossos parceiros.",
          image: const Center(child: Icon(Icons.school, size: 100.0, color: Colors.purpleAccent)),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Faça a Diferença",
          body: "Cada lacre conta! Sua contribuição se transforma em recursos valiosos e apoia uma causa nobre. Vamos começar?",
          image: const Center(child: Icon(Icons.recycling, size: 100.0, color: Colors.purpleAccent)),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text('Pular', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      next: const Icon(Icons.arrow_forward, color: Colors.white),
      done: const Text('Começar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: Colors.white30,
        activeColor: Colors.purpleAccent,
        activeSize: const Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
    );
  }
}