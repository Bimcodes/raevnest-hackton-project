import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/logo_loader.dart';

class DriverRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  const DriverRegistrationScreen({super.key, required this.onRegistered});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _driverIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _driverIdController.addListener(_validateForm);
    _nameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    final isValid = _driverIdController.text.trim().isNotEmpty &&
                    _nameController.text.trim().isNotEmpty &&
                    _passwordController.text.trim().isNotEmpty;
    if (isValid != _isFormValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  @override
  void dispose() {
    _driverIdController.removeListener(_validateForm);
    _nameController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _driverIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final driverId = _driverIdController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (driverId.isEmpty || name.isEmpty || password.isEmpty) {
      showGlassSnackBar(context, 'Fill in all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.registerDriver(driverId: driverId, name: name, password: password);
      await ApiService.login(userId: driverId, password: password, role: 'driver');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_id', driverId);
      await prefs.setString('driver_name', name);
      await prefs.setString('driver_password', password);
      await prefs.setBool('driver_registered', true);

      widget.onRegistered();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        const SizedBox(height: 32),
                        Center(child: Image.asset('assets/images/logo.png', height: 48)),
                        const SizedBox(height: 32),
                        const Text(
                          'SECURE TRANSIT.\nEFFICIENT DRIVING.',
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
                                  'hey driver!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Register your credentials and start scanning QR fares instantly.',
                                  style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                                ),
                                const SizedBox(height: 32),
                                _buildInputField(
                                  controller: _driverIdController,
                                  label: 'Driver ID',
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
                              color: _isFormValid && !_isLoading ? Colors.white : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isFormValid ? Colors.white : Colors.white10,
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
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
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
