// screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _appInitialized = false;
  bool _errorOccurred = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _appInitialized = true);
      await Future.delayed(const Duration(seconds: 1));
      await _checkNextScreen();
    } catch (e) {
      print('Initialization error: $e');
      setState(() => _errorOccurred = true);
      await _checkNextScreen();
    }
  }

  Future<void> _checkNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;

    Timer(const Duration(milliseconds: 500), () {
      if (!seenOnboarding) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else if (isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.find_in_page,
                size: 70,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 30),

            // App Title
            const Text(
              'CUI SWL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lost & Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // Loading Indicator
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _errorOccurred ? Colors.red : Colors.white,
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  if (_appInitialized)
                    const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 35,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Status Text
            Text(
              _errorOccurred
                  ? 'Connection Issue'
                  : _appInitialized
                  ? 'Ready to go!'
                  : 'Initializing...',
              style: TextStyle(
                color: _errorOccurred ? Colors.yellow[200] : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}