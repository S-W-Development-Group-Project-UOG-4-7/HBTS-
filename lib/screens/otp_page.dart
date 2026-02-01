import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';
import '../app_routes.dart';
import '/admin/dashboard.dart';
import 'package:flutter/services.dart';


/// OTP flow types
enum OtpFlow {
  signupVerify,      // Passenger signup OTP
  login2fa,          // ✅ Unified login OTP (all roles)
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
        // Passenger signup OTP (unchanged)
        result = await AuthApi.verifySignupOtp(
          challengeId: widget.challengeId,
          otp: otp,
        );
      } else {
        // ✅ Unified login OTP (all roles)
        if (widget.tempToken == null) {
          throw Exception("Session expired. Please login again.");
        }

        result = await AuthApi.verifyUnifiedLoginOtp(
          tempToken: widget.tempToken!,
          challengeId: widget.challengeId,
          otp: otp,
        );
      }

      // =======================
      // SAVE TOKENS + ROLE
      // =======================
      final accessToken = result["accessToken"] as String?;
      final refreshToken = result["refreshToken"] as String?;
      final roleRaw = result["role"];

      if (accessToken == null || refreshToken == null || roleRaw == null) {
        throw Exception("Invalid authentication response");
      }

      // ✅ Show token in console + dialog for easy Postman use
printLong("ACCESS TOKEN => $accessToken");
await showTokenDialog(accessToken);


      final role = roleRaw.toString().toLowerCase();

      await TokenStore.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await TokenStore.saveRole(role);

      // Verify saved
      final storedToken = await TokenStore.getAccessToken();
      if (storedToken == null || storedToken.isEmpty) {
        throw Exception("Failed to save access token");
      }

      if (!mounted) return;

      // =======================
      // ROLE-BASED NAVIGATION
      // =======================
      if (role == "conductor") {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.conductorHome,
          (_) => false,
        );
      } else {
        final isStaff = role == "admin" || role == "operator" || role == "driver";

        if (isStaff) {
          // For now, all staff go to AdminDashboard.
          // Later you can route operator/driver to their dashboards.
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
            (_) => false,
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          );
        }
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

  void printLong(String text) {
  const chunkSize = 800;
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize > text.length) ? text.length : i + chunkSize;
    // ignore: avoid_print
    print(text.substring(i, end));
  }
}

Future<void> showTokenDialog(String token) async {
  if (!mounted) return;

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Access Token (copy for Postman)'),
      content: SingleChildScrollView(child: SelectableText(token)),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: token));
            if (mounted) Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token copied to clipboard')),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
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
