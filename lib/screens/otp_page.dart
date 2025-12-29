import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';
import 'home_page.dart';
import '../admin/dashboard.dart';

/// OTP flow types
enum OtpFlow {
  signupVerify,      // Passenger signup OTP
  passengerLogin2fa, // Passenger login OTP
  adminLogin2fa,     // ✅ Admin login OTP
}

class OtpScreen extends StatefulWidget {
  final OtpFlow flow;
  final int challengeId;
  final String? tempToken;

  const OtpScreen({
    super.key,
    required this.flow,
    required this.challengeId,
    this.tempToken,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();

    // ✅ OTP validation
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 6-digit OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;

      // =======================
      // OTP VERIFICATION LOGIC
      // =======================

      if (widget.flow == OtpFlow.signupVerify) {
        // Passenger signup OTP
        result = await AuthApi.verifySignupOtp(
          challengeId: widget.challengeId,
          otp: otp,
        );
      } else {
        if (widget.tempToken == null) {
          throw Exception("Session expired. Please login again.");
        }

        // Passenger or Admin login OTP
        if (widget.flow == OtpFlow.adminLogin2fa) {
          result = await AuthApi.verifyAdminLoginOtp(
            tempToken: widget.tempToken!,
            challengeId: widget.challengeId,
            otp: otp,
          );
        } else {
          result = await AuthApi.verifyLoginOtp(
            tempToken: widget.tempToken!,
            challengeId: widget.challengeId,
            otp: otp,
          );
        }
      }

      // =======================
      // SAVE TOKENS & ROLE
      // =======================
      final accessToken = result["accessToken"];
      final refreshToken = result["refreshToken"];
      final role = result["role"];

      if (accessToken == null || refreshToken == null || role == null) {
        throw Exception("Invalid authentication response");
      }

      await TokenStore.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await TokenStore.saveRole(role);

      // 🔍 DEBUG (can remove later)
      await TokenStore.debugPrintTokens();

      if (!mounted) return;

      // =======================
      // ROLE-BASED NAVIGATION
      // =======================
      if (role == "admin") {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.flow == OtpFlow.signupVerify
        ? "Verify Your Account"
        : "Two-Factor Verification";

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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter the 6-digit code sent to your email or phone",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: "OTP",
                      hintText: "123456",
                      prefixIcon: Icon(Icons.lock_outline,
                          color: Colors.blue.shade700),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterText: "",
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              "Verify",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
