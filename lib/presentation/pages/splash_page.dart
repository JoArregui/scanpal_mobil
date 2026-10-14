import 'package:flutter/material.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _moveAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  static const double _logoSize = 200;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _moveAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-3.2, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: ConstantTween(Offset.zero),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(-0.25, 0))
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.25, 0), end: const Offset(4.0, 0))
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.24)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.24, end: -0.20)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.20, end: 0.14)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.14, end: -0.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.08, end: 0.04)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.04, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 32,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.70)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.70, end: 1.12)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.03)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 28,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        _navigateToLoginWithFade();
      }
    });
  }

  void _navigateToLoginWithFade() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _scaleAnimation.value;

            final double baseCorrection =
                (_logoSize - (_logoSize * scale)) / 2;

            return FractionalTranslation(
              translation: _moveAnimation.value,
              child: Transform.translate(
                offset: Offset(0, baseCorrection),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateZ(_rotationAnimation.value)
                    ..scaleByDouble(1.0, scale, 1.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: Image.asset(
            'assets/icon/Ecomputer.jpg',
            width: _logoSize,
            height: _logoSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}