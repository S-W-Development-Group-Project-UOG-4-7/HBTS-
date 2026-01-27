import 'package:flutter/material.dart';

import 'signup_page.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';
import 'otp_page.dart';
import 'home_page.dart';
import '../admin/dashboard.dart';

// ✅ operator imports
import '../operator/operator_start_page.dart';
import '../operator/pages/services/operator_api.dart';
import '../operator/pages/services/utils/operator_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // ✅ NEW: operator toggle
  bool _loginAsOperator = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  // =======================
  // AUTO LOGIN CHECK
  // =======================
  Future<void> _checkExistingLogin() async {
    final loggedIn = await TokenStore.isLoggedIn();
    if (!loggedIn) return;

    final role = await TokenStore.getRole();
    if (!mounted) return;

    if (role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
      return;
    }

    if (role == "operator") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OperatorStartPage()),
      );
      return;
    }

    // default user/passenger
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // =======================
  // LOGIN HANDLER
  // =======================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // ✅ OPERATOR LOGIN (no OTP, token comes directly)
      if (_loginAsOperator) {
        final result = await OperatorApi.login(email: email, password: password);

        final token = result["token"]?.toString();
        final operator = (result["operator"] is Map)
            ? Map<String, dynamic>.from(result["operator"] as Map)
            : null;

        if (token == null || operator == null) {
          throw Exception("Invalid operator login response from server");
        }

        final operatorId = int.tryParse(operator["id"]?.toString() ?? "");
        if (operatorId == null) {
          throw Exception("Operator id missing/invalid in response");
        }

        // save session in memory (your existing code uses this)
        OperatorSession.token = token;
        OperatorSession.operatorId = operatorId;
        OperatorSession.operatorName = operator["name"]?.toString();

        // ✅ save to TokenStore so main.dart routing works
        await TokenStore.saveToken(token);
        await TokenStore.saveRole("operator");

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OperatorStartPage()),
        );
        return;
      }

      // =======================
      // PASSENGER / ADMIN LOGIN (OTP FLOW)
      // =======================
      final result = await AuthApi.unifiedLogin(
        identifier: email, // email OR phone
        password: password,
      );

      final tempToken = result["tempToken"] as String?;
      final challengeIdRaw = result["challengeId"];
      final int? challengeId = int.tryParse(challengeIdRaw.toString());

      if (tempToken == null || challengeId == null) {
        throw Exception("Invalid response from server");
      }

      if (!mounted) return;

      // Unified login uses a single OTP flow
      final otpFlow = OtpFlow.login2fa;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            flow: otpFlow,
            challengeId: challengeId,
            tempToken: tempToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst("Exception: ", ""),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =======================
  // UI
  // =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to continue your journey',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ NEW: Operator toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: Colors.blue.shade700),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Login as Operator",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: _loginAsOperator,
                            onChanged: _isLoading
                                ? null
                                : (v) => setState(() => _loginAsOperator = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =======================
                    // EMAIL
                    // =======================
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocus);
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.blue.shade700,
                        ),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email or phone';
                        }

                        final v = value.trim();

                        // allow common phone formats by stripping spaces/dashes
                        final phoneCandidate = v.replaceAll(RegExp(r'[\s\-()]'), '');

                        final isEmail = v.contains('@');
                        final isPhone = RegExp(r'^\+?\d{9,15}$').hasMatch(phoneCandidate);

                        if (!isEmail && !isPhone) {
                          return 'Enter a valid email or phone number';
                        }

                        return null;
                      },

                    ),

                    const SizedBox(height: 20),

                    // =======================
                    // PASSWORD
                    // =======================
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_isLoading) return;
                        _handleLogin();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.blue.shade700,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // =======================
                    // LOGIN BUTTON
                    // =======================
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _loginAsOperator ? 'Login (Operator)' : 'Login',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =======================
                    // SIGNUP LINK
                    // =======================
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? "),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
