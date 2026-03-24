import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import '../db/driver_db.dart';
import '../theme/theme_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isTorchOn = false;
  int _sessionScans = 0;
  int _sessionEarningsKobo = 0;
  String? _lastScannedPayload;
  
  // Result overlay state
  bool _showResult = false;
  bool _lastScanSuccess = false;
  String _lastStudentId = '';
  int _lastAmountKobo = 0;
  String _lastError = '';

  final MobileScannerController _scannerController = MobileScannerController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processQR(String? rawData) async {
    if (rawData == null || _isProcessing || _showResult) return;
    setState(() => _isProcessing = true);

    try {
      final payload = QRPayload.fromJsonString(rawData);

      // 1. Blacklist check
      if (await DriverDB.instance.isUserBlacklisted(payload.userId)) {
        throw Exception('USER IS BLACKLISTED');
      }

      // 2. Nonce replay check
      if (await DriverDB.instance.hasNonceBeenUsed(payload.userId, payload.nonce)) {
        throw Exception('NONCE ALREADY USED');
      }

      // 3. Signature verification
      String? pubKeyPem = await DriverDB.instance.getPublicKeyPem(payload.userId);
      if (pubKeyPem != null) {
        final key = KeyManager.importPublicKeyPem(pubKeyPem);
        final isValid = TransactionSigner.verifySignature(payload.rawPayload, payload.signature, key);
        if (!isValid) throw Exception('INVALID SIGNATURE');
      }

      // 4. Time validity (5 minutes)
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - payload.timestamp > 300) {
        throw Exception('EXPIRED QR CODE');
      }

      // Save promise note
      await DriverDB.instance.savePromiseNote(
        payload.userId, payload.amount, payload.nonce, payload.signature, payload.rawPayload,
      );

      setState(() {
        _sessionScans++;
        _sessionEarningsKobo += payload.amount;
        _lastScanSuccess = true;
        _lastStudentId = payload.userId;
        _lastAmountKobo = payload.amount;
        _showResult = true;
      });
    } catch (e) {
      setState(() {
        _lastScanSuccess = false;
        _lastError = e.toString().replaceFirst('Exception: ', '');
        _showResult = true;
      });
    } finally {
      setState(() => _isProcessing = false);
      // Auto-dismiss result after 2.5 seconds
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) setState(() => _showResult = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: theme.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'OFFLINE SCANNER', 
                        style: TextStyle(color: theme.pPrimaryText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: _isTorchOn ? theme.primaryColor : theme.pSecondaryText, size: 26),
                        onPressed: () {
                          _scannerController.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                      ),
                    ],
                  ),
                ),

                // Session Stats Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatChip(theme, '$_sessionScans', 'SCANS', Icons.check_circle_outline),
                        Container(width: 1, height: 30, color: theme.primaryColor.withOpacity(0.2)),
                        _buildStatChip(theme, '₦ ${(_sessionEarningsKobo / 100).toStringAsFixed(0)}', 'EARNED', Icons.payments_outlined),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Camera Viewfinder
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(color: theme.primaryColor.withOpacity(0.15), blurRadius: 30, spreadRadius: 2)
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              final barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty) {
                                final currentPayload = barcodes.first.rawValue;
                                if (currentPayload != null && currentPayload != _lastScannedPayload) {
                                  _lastScannedPayload = currentPayload;
                                  _processQR(currentPayload);
                                }
                              }
                            },
                          ),
                          // Animated Laser Line
                          if (!_showResult)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: _animationController.value * (constraints.maxHeight - 4),
                                      left: 0, right: 0,
                                      child: child!,
                                    );
                                  },
                                  child: Container(
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 24),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.8), blurRadius: 15, spreadRadius: 3)],
                                    ),
                                  ),
                                );
                              }
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Instructional Text
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 96.0),
                  child: Center(
                    child: _isProcessing
                      ? CircularProgressIndicator(color: theme.primaryColor)
                      : Text(
                          'Point camera at student\'s QR pass.',
                          style: TextStyle(fontSize: 15, color: theme.pSecondaryText, fontWeight: FontWeight.w600)
                        ),
                  ),
                ),
              ],
            ),

            // ── Scan Result Overlay ──────────────────────────────────────────
            if (_showResult)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: _lastScanSuccess ? const Color(0xFF0A1F0A) : const Color(0xFF1F0A0A),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: _lastScanSuccess ? Colors.greenAccent : Colors.redAccent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_lastScanSuccess ? Colors.greenAccent : Colors.redAccent).withOpacity(0.3),
                            blurRadius: 40, spreadRadius: 4,
                          )
                        ],
                      ),
                      child: _lastScanSuccess
                          ? _buildSuccessResult()
                          : _buildErrorResult(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessResult() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
        const SizedBox(height: 16),
        const Text(
          '✅ FARE ACCEPTED',
          style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('AMOUNT COLLECTED', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              const SizedBox(height: 8),
              Text(
                '₦ ${(_lastAmountKobo / 100).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PASSENGER ID: ${_lastStudentId.length > 12 ? '${_lastStudentId.substring(0, 12)}...' : _lastStudentId}',
          style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          color: Colors.greenAccent,
          backgroundColor: Colors.greenAccent.withOpacity(0.1),
        ),
        const SizedBox(height: 8),
        const Text('Resuming scanner...', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildErrorResult() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cancel, color: Colors.redAccent, size: 64),
        const SizedBox(height: 16),
        const Text(
          '❌ FARE REJECTED',
          style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _lastError,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          color: Colors.redAccent,
          backgroundColor: Colors.redAccent.withOpacity(0.1),
        ),
        const SizedBox(height: 8),
        const Text('Resuming scanner...', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatChip(ThemeData theme, String value, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: theme.pPrimaryText, fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: theme.pSecondaryText, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ],
        ),
      ],
    );
  }
}
