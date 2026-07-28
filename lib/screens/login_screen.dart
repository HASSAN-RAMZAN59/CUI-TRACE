// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_service.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AppService _authService = AppService();

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('savedEmail');
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final user = await _authService.loginUser(email, password);

      if (user != null && mounted) {
        await _saveLoginData(email, user);
        _navigateToHome();
      }
    } catch (e) {
      _showErrorSnackBar('Login failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLoginData(String email, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', user.id);
    await prefs.setString('email', email);
    await prefs.setString('displayName', user.displayName);
    await prefs.setString('username', user.username);

    if (_rememberMe) {
      await prefs.setString('savedEmail', email);
    } else {
      await prefs.remove('savedEmail');
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // Future<void> _googleLogin() async {
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
  //   //     _navigateToHome();
  //   //   }
  //   // } catch (e) {
  //   //   _showErrorSnackBar("Google Sign-In failed: $e");
  //   // } finally {
  //   //   if (mounted) setState(() => _isLoading = false);
  //   // }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 40),
                  _buildFormSection(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 32),
                  _buildGoogleButton(),
                  const SizedBox(height: 32),
                  _buildSignupOption(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.shade100, width: 2),
          ),
          child: const Icon(
              Icons.inventory_2_outlined, size: 60, color: Colors.blue),
        ),
        const SizedBox(height: 20),
        const Text(
          'CUI Trace',
          style: TextStyle(fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'COMSATS University Sahiwal',
          style: TextStyle(fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Login to Your Account',
          style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons
                            .visibility_outlined, color: Colors.grey.shade600),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _login(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 0.9,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Text('Remember me', style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isLoading ? null : () =>
                    Navigator.pushNamed(context, '/forgot_password'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 14,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 24,
            width: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Text('Login',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        // onPressed: _isLoading ? null : _googleLogin,
        onPressed: null,
        icon: Image.network(
          "https://cdn-icons-png.flaticon.com/512/2991/2991148.png",
          height: 24,
          width: 24,
        ),
        label: const Text("Continue with Google",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSignupOption() {
    return Column(
      children: [
        Text("Don't have an account?",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () =>
                Navigator.pushReplacementNamed(context, '/signup'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.blue.shade400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Create New Account',
              style: TextStyle(fontSize: 15,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}