// Сплеш — бренд-заставка на время тихого входа (проверка токена и profile).
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/splash/splash_1080.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF006C6B),
                child: Center(
                  child: Text(
                    'SUP FUN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 74,
              child: Column(
                children: [
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      label!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
