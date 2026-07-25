// screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AppService _authService = AppService();

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    if (!_termsAccepted) {
      _showSnackBar('Please accept terms and conditions', isError: true);
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('📝 Starting registration for: $email');

      final user = await _authService.registerUser(
        email: email,
        password: password,
        username: username,
        displayName: name,
      );

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', user.id);
        await prefs.setString('email', user.email);
        await prefs.setString('displayName', name);
        await prefs.setString('username', username);

        _showSnackBar('✅ Account created successfully!', isError: false);

        _nameController.clear();
        _emailController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        if (mounted) {
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('🔥 Error: $e');
      _showSnackBar('Registration failed: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Future<void> _googleSignup() async {
  //   // Google Sign-In temporarily disabled
  //   // setState(() => _isLoading = true);
  //   // try {
  //   //   final user = await _authService.signInWithGoogle();
  //   //   if (user != null) {
  //   //     final prefs = await SharedPreferences.getInstance();
  //   //     await prefs.setBool('isLoggedIn', true);
  //   //     await prefs.setString('userId', user.id);
  //   //     await prefs.setString('email', user.email);
  //   //     await prefs.setString('displayName', user.displayName);
  //   //     await prefs.setString('username', user.username);
  //   //     Navigator.pushReplacementNamed(context, '/home');
  //   //   }
  //   // } catch (e) {
  //   //   _showSnackBar('Google Sign-In failed: $e', isError: true);
  //   // } finally {
  //   //   if (mounted) setState(() => _isLoading = false);
  //   // }
  // }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          action: isError ? SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ) : null,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Full name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return 'Only letters, numbers, and underscore allowed';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.person_add_alt_1_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                'COMSATS University Sahiwal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email),
                        hintText: 'e.g., john_doe123',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateUsername,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'example@email.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: _validateConfirmPassword,
                      onFieldSubmitted: (_) => _signup(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    onChanged: (value) => setState(() => _termsAccepted = value!),
                    activeColor: Colors.blue,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Terms & Conditions'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('By creating an account, you agree to:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(height: 10),
                                  Text('• Use the app responsibly'),
                                  Text('• Provide accurate information'),
                                  Text('• Respect other users'),
                                  Text('• Report suspicious activity'),
                                  Text('• Follow university policies'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('I Understand'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          text: 'I agree to ',
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: 'terms and conditions',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade300),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  // onPressed: _isLoading ? null : _googleSignup,
                  onPressed: null,
                  icon: Image.network(
                    "https://cdn-icons-png.flaticon.com/512/2991/2991148.png",
                    height: 24,
                    width: 24,
                  ),
                  label: const Text(
                    "Sign Up with Google",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}