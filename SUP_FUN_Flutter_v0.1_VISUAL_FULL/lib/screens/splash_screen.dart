// Splash screen for SUP FUN - displays full splash image (Full HD vertical)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Select splash image based on platform and screen size
  String _getSplashAsset() {
    // For web - use optimized Full HD JPEG (lightweight)
    if (kIsWeb) {
      return 'assets/splash/splash_1080.jpg';
    }

    // For Android - use asset based on density
    // Default to Full HD for most modern Samsung devices
    return 'assets/splash/splash_1080.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final devicePixelRatio = mediaQuery.devicePixelRatio;

    // Choose the best quality image based on actual pixel count
    String assetPath;
    final actualPixels = screenWidth * devicePixelRatio;
    if (actualPixels <= 360) {
      assetPath = 'assets/splash/splash_540.jpg';
    } else if (actualPixels <= 540) {
      assetPath = 'assets/splash/splash_720.jpg';
    } else if (actualPixels <= 720) {
      assetPath = 'assets/splash/splash_1080.jpg';
    } else {
      assetPath = 'assets/splash/splash_1440.jpg';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A4A6E),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                cacheWidth: (screenWidth * devicePixelRatio).round(),
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to logo if splash image fails
                  return Container(
                    color: const Color(0xFF1A4A6E),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        width: screenWidth * 0.6,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) {
                          return const Text(
                            'SUP FUN',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
