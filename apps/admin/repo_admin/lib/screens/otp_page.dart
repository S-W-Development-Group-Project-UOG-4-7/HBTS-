import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';
import 'home_page.dart';
import '../admin/dashboard.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_brand.dart';

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
  final bool saveTokens;
  final VoidCallback? onVerified;

  const OtpScreen({
    super.key,
    required this.flow,
    required this.challengeId,
    this.tempToken,
    this.saveTokens = true,
    this.onVerified,
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

      if (!mounted) return;

      if (!widget.saveTokens) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account verified successfully")),
        );
        if (widget.onVerified != null) {
          widget.onVerified!();
        } else {
          Navigator.pop(context);
        }
        return;
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
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppBrand(subtitle: "Secure Access"),
                  const SizedBox(height: 30),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Enter the 6-digit code sent to your email or phone.",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: "OTP Code",
                              hintText: "123456",
                              prefixIcon: Icon(Icons.lock_outline),
                              counterText: "",
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verify,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("Verify"),
                            ),
                          ),
                        ],
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
