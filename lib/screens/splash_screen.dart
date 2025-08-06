import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacrei_app/screens/onboarding/onboarding_screen.dart';
import 'package:lacrei_app/screens/profile_selection_screen.dart';

class Lacre {
  late Offset position;
  late double size;
  late double speed;
  late double rotation;
  late double rotationSpeed;

  Lacre({required Size screenSize}) {
    final random = Random();
    position = Offset(random.nextDouble() * screenSize.width, random.nextDouble() * screenSize.height);
    speed = random.nextDouble() * 1.5 + 0.5;
    size = random.nextDouble() * 20 + 15;
    rotation = random.nextDouble() * 2 * pi;
    rotationSpeed = random.nextDouble() * 0.02 - 0.01;
  }

  void update(Size screenSize) {
    position = Offset(position.dx, position.dy + speed);
    rotation += rotationSpeed;
    if (position.dy > screenSize.height) {
      position = Offset(Random().nextDouble() * screenSize.width, -size);
    }
  }
}

class LacrePainter extends CustomPainter {
  final List<Lacre> lacres;
  final ui.Image image;

  LacrePainter({required this.lacres, required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var lacre in lacres) {
      canvas.save();
      canvas.translate(lacre.position.dx + lacre.size / 2, lacre.position.dy + lacre.size / 2);
      canvas.rotate(lacre.rotation);
      canvas.translate(-(lacre.position.dx + lacre.size / 2), -(lacre.position.dy + lacre.size / 2));
      canvas.drawImageRect(
        image,
        Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(lacre.position.dx, lacre.position.dy, lacre.size, lacre.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SplashScreen extends StatefulWidget {
  final bool seenOnboarding;
  const SplashScreen({super.key, required this.seenOnboarding});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _isAnimationVisible = false;
  bool _isTextVisible = false;
  late final AnimationController _animationController;
  final List<Lacre> _lacres = [];
  final int _numberOfLacres = 40;
  bool _areLacresInitialized = false;
  ui.Image? _lacreImage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadImage();
    _startAnimationSequence();
  }

  Future<void> _loadImage() async {
    final ByteData data = await rootBundle.load('assets/lacre_latinha.png');
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _lacreImage = fi.image;
      });
    }
  }
  
  void _startAnimationSequence() {
    const textAnimationDelay = Duration(milliseconds: 2500);
    const transitionDelay = Duration(milliseconds: 6500);

    Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _isAnimationVisible = true);
    });
    Timer(textAnimationDelay, () {
      if (mounted) setState(() => _isTextVisible = true);
    });
    Timer(transitionDelay, () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                widget.seenOnboarding
                    ? const ProfileSelectionScreen()
                    : const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F051E),
      body: Stack(
        children: [
          if (_lacreImage != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
                
                if (!_areLacresInitialized) {
                  for (int i = 0; i < _numberOfLacres; i++) {
                    _lacres.add(Lacre(screenSize: screenSize));
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if(mounted) {
                      setState(() {
                        _areLacresInitialized = true;
                      });
                    }
                  });
                }

                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    if (_areLacresInitialized) {
                      for (var lacre in _lacres) {
                        lacre.update(screenSize);
                      }
                    }
                    return CustomPaint(
                      size: screenSize,
                      painter: LacrePainter(
                        lacres: _lacres,
                        image: _lacreImage!,
                      ),
                    );
                  },
                );
              },
            ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _isAnimationVisible ? 1.0 : 0.0,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeIn,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 260,
                        height: 260,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Image.asset(
                        'assets/mp4-unscreen.gif',
                        width: 250,
                        height: 250,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: _isTextVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeIn,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    //
                    // <<<<<<<<<<<<<<<<<<<< ALTERAÇÃO AQUI <<<<<<<<<<<<<<<<<<<<
                    //
                    // Removido o Padding e adicionado um 'width' para controlar o tamanho.
                    child: Image.asset(
                      'assets/Marca_Lacrei.png',
                      width: 180,
                    ),
                    //
                    // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                    //
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}