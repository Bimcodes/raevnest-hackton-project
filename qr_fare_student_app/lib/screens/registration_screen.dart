import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import 'package:pointycastle/export.dart' as pc;
import '../utils/snackbar_helper.dart';
import '../widgets/logo_loader.dart';
import 'home_screen.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _studentIdController.addListener(_validateForm);
    _nameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    final isValid = _studentIdController.text.trim().isNotEmpty &&
                    _nameController.text.trim().isNotEmpty &&
                    _passwordController.text.trim().isNotEmpty;
    if (isValid != _isFormValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  @override
  void dispose() {
    _studentIdController.removeListener(_validateForm);
    _nameController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _studentIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final studentId = _studentIdController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (studentId.isEmpty || name.isEmpty || password.isEmpty) {
      showGlassSnackBar(context, 'Fill in all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Ensure keys exist
      var privateKey = await KeyManager.loadPrivateKey();
      if (privateKey == null) {
        final keyPair = KeyManager.generateKeyPair();
        privateKey = keyPair.privateKey as pc.ECPrivateKey;
        await KeyManager.savePrivateKey(privateKey);
      }

      // 2. Derive public key
      final ecPoint = privateKey.parameters!.G * privateKey.d;
      final pubKey = pc.ECPublicKey(ecPoint, privateKey.parameters!);
      final pubKeyPem = KeyManager.exportPublicKeyPem(pubKey);

      // 3. Register with backend
      await ApiService.registerStudent(
        studentId: studentId,
        name: name,
        password: password,
        publicKeyPem: pubKeyPem,
      );

      // 4. Login immediately
      await ApiService.login(userId: studentId, password: password, role: 'student');

      // 5. Save state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_id', studentId);
      await prefs.setString('student_name', name);
      await prefs.setString('student_password', password);
      await prefs.setBool('student_registered', true);

      if (mounted) {
        // Push user to their new dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) showGlassSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showGlassSnackBar(context, 'Connection error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Stack(
          children: [
            // Underlying Page Content
            CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Section
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(child: Image.asset('assets/images/logo.png', height: 48)),
                        const SizedBox(height: 32),
                        const Text(
                          'YOUR OFFLINE\nCAMPUS WALLET.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Middle Card Section
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1E1E1E), Color(0xFF101010)],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(32),
                                bottomRight: Radius.circular(32),
                                topRight: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                              border: Border.all(color: Colors.white10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.02),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'hey student!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Register your credentials and deposit funds to start generating passes.',
                                  style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                                ),
                                const SizedBox(height: 32),
                                _buildInputField(
                                  controller: _studentIdController,
                                  label: 'Matric / Student ID',
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  isPassword: true,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom Animated Button
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: 64,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _isFormValid && !_isLoading ? Colors.cyanAccent : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isFormValid ? Colors.cyanAccent : Colors.white10,
                                width: 1,
                              ),
                              boxShadow: _isFormValid && !_isLoading 
                                ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
                                : [const BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0)],
                            ),
                            child: TextButton(
                              onPressed: (_isLoading || !_isFormValid) ? null : _register,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                disabledForegroundColor: Colors.white54,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text(
                                'CONTINUE WITH REGISTRATION',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Colossal Center Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.85),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LogoLoader(size: 80),
                    const SizedBox(height: 32),
                    const Text('AUTHENTICATING...', style: TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.cyanAccent.withOpacity(0.7), fontSize: 15),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          border: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: const BorderSide(color: Colors.cyanAccent, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
