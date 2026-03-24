import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'home_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      // Welcome-screen görselini tam ekran göster
      body: SizedBox.expand(
        child: Image.asset(
          'assets/welcome-screen/welcome-screen.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Görsel bulunamazsa fallback olarak logoyu göster
            return Center(
              child: Image.asset(
                'assets/icon/appicon-transparent.png',
                width: 150,
              ),
            );
          },
        ),
      ),
    );
  }
}
