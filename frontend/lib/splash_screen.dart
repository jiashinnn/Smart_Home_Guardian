import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'main_navigation.dart';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _textController;
  late AnimationController _progressController;
  late Animation<double> _textAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _lottieController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Setup animations
    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));

    // Start animations sequence
    _startAnimations();
  }

  void _startAnimations() async {
    // Start Lottie animation
    _lottieController.forward();

    // Start text animation after a delay
    await Future.delayed(const Duration(milliseconds: 1000));
    _textController.forward();

    // Start progress animation
    await Future.delayed(const Duration(milliseconds: 2000));
    _progressController.forward();

    // Navigate to login after all animations
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFf0e6d8),
              Color(0xFFe6d4cb),
              Color(0xFFdcc2b0),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Lottie animation
              Container(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/animations/Animation - 1750154540442.json',
                  controller: _lottieController,
                  fit: BoxFit.contain,
                  onLoaded: (composition) {
                    _lottieController
                      ..duration = composition.duration
                      ..repeat()
                      ..setSpeed(0.5); // Adjust speed here
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Animated app title with enhanced effects
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - _textAnimation.value)),
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * _textAnimation.value),
                        child: Column(
                          children: [
                            Text(
                              'Smart Home',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF5d4e75),
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 3),
                                    blurRadius: 6,
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Guardian',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFF8b7355),
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 3),
                                    blurRadius: 6,
                                    color: Colors.black.withOpacity(0.15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              // Enhanced subtitle with fade-in effect
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textAnimation.value * 0.8,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _textAnimation.value)),
                      child: Text(
                        'Protecting Your Home, Empowering Your Life',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF5d4e75).withOpacity(0.7),
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // Enhanced loading indicator
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _progressAnimation.value,
                    child: Column(
                      children: [
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: const Color(0xFF5d4e75).withOpacity(0.2),
                          ),
                          child: Stack(
                            children: [
                              Container(
                                width: 200 * _progressAnimation.value,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5d4e75),
                                      Color(0xFF8b7355),
                                      Color(0xFF5d4e75),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5d4e75)
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: const Color(0xFF5d4e75).withOpacity(0.6),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on AnimationController {
  void setSpeed(double d) {}
}
