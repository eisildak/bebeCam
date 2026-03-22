import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import 'home_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _onboardingImages = [
    'assests/onboarding/onboarding1.png',
    'assests/onboarding/onboarding2.png',
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

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
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return SizedBox.expand(
                child: Image.asset(
                  _onboardingImages[index],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          
          // Görsellerin üzerine tıklanabilir görünmez bir katman koyarak
          // Sayfa geçişlerini ya da bitirmeyi sağlıyoruz (Görseller kendinden butonluysa)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                if (_currentPage == _onboardingImages.length - 1) {
                  _completeOnboarding();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  );
                }
              },
              child: Container(
                color: Colors.transparent, 
                height: 100, // Alt kısımdaki "DEVAM ET" ve "BAŞLA" butonlarının üzerine oturan görünmez buton
              ),
            ),
          )
        ],
      ),
    );
  }
}
