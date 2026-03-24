import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:provider/provider.dart';
import 'package:qr_fare_crypto_core/api_service.dart';
import 'package:qr_fare_crypto_core/key_manager.dart';
import 'package:qr_fare_crypto_core/qr_payload.dart';
import 'package:qr_fare_crypto_core/transaction_signer.dart';
import 'package:qr_fare_student_app/db/wallet_db.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/user_provider.dart';
import '../theme/theme_provider.dart';
import 'notifications_screen.dart';

class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  bool _isInitialized = false;
  pc.ECPrivateKey? _privateKey;
  String _userId = "";

  int _balanceKobo = 0;
  int _lockedKobo = 0;
  double _serverBalanceNaira = 0;
  bool _isBlacklisted = false;
  DateTime? _lastSynced;

  QRPayload? _currentQrPayload;
  Timer? _qrTimer;
  int _qrSecondsLeft = 300;

  // Group ride: 1 = solo, up to 4 people
  int _passengerCount = 1;
  static const int _farePerPersonKobo = 10000; // ₦100 per person

  // Routes from backend
  List<String> _availableStops = [];
  String? _selectedPickup;
  String? _selectedDropoff;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('student_id') ?? '';

    _privateKey = await KeyManager.loadPrivateKey();
    if (_privateKey == null) {
      final keyPair = KeyManager.generateKeyPair();
      _privateKey = keyPair.privateKey as pc.ECPrivateKey;
      await KeyManager.savePrivateKey(_privateKey!);
    }

    _log('Initializing PassScreen (Offline-First)...');
    await _loadWalletState();

    // Start loading routes without blocking initial UI
    _loadRoutes();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _log('UI Initialized from Local Data.');
      });
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[PASS_SCREEN_DEBUG] $msg');
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await ApiService.fetchRoutes().timeout(
        const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() {
          _availableStops = routes.map((r) => r['name'] as String).toList();
        });
      }
    } catch (_) {
      if (mounted && _availableStops.isEmpty) {
        setState(() {
          _availableStops = [
            'Main Gate',
            'Faculty Block',
            'Library',
            'Hostels',
            'Sports Complex',
          ];
        });
      }
    }
  }

  Future<void> _loadWalletState() async {
    final state = await WalletDB.instance.getWalletState();
    if (mounted) {
      setState(() {
        _balanceKobo = state['balance'] as int;
        _lockedKobo = state['locked_amount'] as int;
      });
    }
  }

  // ── QR Countdown Timer ────────────────────────────────────────────────────
  void _startQrTimer() {
    _qrTimer?.cancel();
    _qrSecondsLeft = 300;
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _qrSecondsLeft - 1;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _qrSecondsLeft = 0;
          // BUG FIX: Intentionally retaining _currentQrPayload so trip stays active!
        });
        if (mounted) _showError('QR pass expired for scanning. Trip remains active.');
      } else {
        setState(() => _qrSecondsLeft = remaining);
      }
    });
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _loginIfNeeded() async {
    if (await ApiService.isLoggedIn()) return;
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString('student_password') ?? '';
    if (_userId.isNotEmpty && password.isNotEmpty) {
      try {
        await ApiService.login(
          userId: _userId,
          password: password,
          role: 'student',
        );
      } catch (_) {}
    }
  }

  // ── Wallet Top-Up ─────────────────────────────────────────────────────────
  void _showTopUpSheet() {
    final theme = Theme.of(context);
    const maxBalanceKobo = 200000; // ₦2,000
    final remainingCapKobo = maxBalanceKobo - _balanceKobo;
    final remainingCapNaira = remainingCapKobo ~/ 100;

    if (remainingCapKobo <= 0) {
      _showError('Wallet is at maximum capacity (₦2,000).');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> doTopUp(int amountNaira) async {
              if (amountNaira > remainingCapNaira) {
                _showError('You can add up to ₦$remainingCapNaira more.');
                Navigator.pop(ctx);
                return;
              }
              setSheetState(() => isLoading = true);
              try {
                await _loginIfNeeded();
                final result = await ApiService.fundWallet(amountNaira);
                _serverBalanceNaira =
                    (result['new_balance_naira'] as num).toDouble();
                await WalletDB.instance.updateBalance(
                  (_serverBalanceNaira * 100).round(),
                );
                await _loadWalletState();
                if (mounted) Navigator.pop(ctx);
                if (mounted)
                  _showSuccess(
                    '₦$amountNaira added! Balance: ₦${_serverBalanceNaira.toStringAsFixed(0)}',
                  );
              } on ApiException {
                final addKobo = amountNaira * 100;
                await WalletDB.instance.updateBalance(_balanceKobo + addKobo);
                await _loadWalletState();
                if (mounted) Navigator.pop(ctx);
                if (mounted)
                  _showSuccess('₦$amountNaira added offline. Sync to confirm.');
              } catch (e) {
                if (mounted)
                  _showError(e.toString().replaceFirst('Exception: ', ''));
              } finally {
                if (mounted) setSheetState(() => isLoading = false);
              }
            }

            final presets =
                [
                  200,
                  500,
                  1000,
                  2000,
                ].where((v) => v <= remainingCapNaira).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.pSecondaryText.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'TOP UP WALLET',
                    style: TextStyle(
                      color: theme.pPrimaryText,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max: ₦2,000 · Add up to ₦$remainingCapNaira',
                    style: TextStyle(color: theme.pSecondaryText, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          presets
                              .map(
                                (amount) => GestureDetector(
                                  onTap: () => doTopUp(amount),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.primaryColor.withOpacity(
                                          0.4,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '+ ₦$amount',
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Trip Start/End ─────────────────────────────────────────────────────────
  Future<void> _startTrip() async {
    final totalFare = _farePerPersonKobo * _passengerCount;
    try {
      if (_balanceKobo < totalFare) {
        throw Exception(
          'Need ₦${(totalFare / 100).toStringAsFixed(0)} for $_passengerCount passenger(s). Top up first.',
        );
      }
      if (_selectedPickup == null || _selectedDropoff == null) {
        throw Exception('Select pickup and destination first.');
      }
      if (_selectedPickup == _selectedDropoff) {
        throw Exception('Pickup and destination cannot be the same.');
      }

      await WalletDB.instance.deductAndLock(totalFare);
      final nonce = await WalletDB.instance.getNextNonce();

      final payload = TransactionSigner.createSignedTripStart(
        _userId,
        totalFare,
        nonce,
        _privateKey!,
      );

      setState(() => _currentQrPayload = payload);
      _startQrTimer();
      await _loadWalletState();
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _endTrip() async {
    if (_currentQrPayload == null) return;
    _qrTimer?.cancel();

    final totalLocked = _farePerPersonKobo * _passengerCount;

    await WalletDB.instance.addTripHistory(
      nonce: _currentQrPayload!.nonce,
      pickup: _selectedPickup ?? 'Unknown',
      destination: _selectedDropoff ?? 'Unknown',
      fareKobo: totalLocked,
      peopleCount: _passengerCount,
    );

    await WalletDB.instance.unlock(0);
    await WalletDB.instance.addRefundClaim(
      _currentQrPayload!.nonce,
      totalLocked,
      _selectedDropoff ?? 'Unknown Stop',
      '{"lat": 0.0, "lng": 0.0}',
    );

    setState(() {
      _currentQrPayload = null;
      _passengerCount = 1;
    });
    await _loadWalletState();
    if (mounted) _showSuccess('Trip ended! Sync to confirm with server.');
  }

  // ── Sync ──────────────────────────────────────────────────────────────────
  Future<void> _syncWithServer() async {
    _log('Starting background sync...');
    try {
      await _loginIfNeeded();
      final prefs = await SharedPreferences.getInstance();

      // 1. Silent Avatar Sync
      final pendingPath = prefs.getString('pending_avatar_path');
      if (pendingPath != null && pendingPath.isNotEmpty) {
        _log('Found pending avatar upload: $pendingPath');
        try {
          final res = await ApiService.uploadStudentAvatar(pendingPath);
          final serverUrl =
              res['avatar_url'] as String? ?? res['url'] as String?;
          if (serverUrl != null) {
            await prefs.setString('avatar_url', serverUrl);
            if (mounted) {
              final userProv = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              userProv.updateAvatar(serverUrl);
              await prefs.remove('pending_avatar_path');
            }
            _log('Background avatar upload successful.');
          }
        } catch (e) {
          _log('Background avatar upload failed (still pending): $e');
        }
      }

      // 1b. Silent Name Sync
      final pendingName = prefs.getString('pending_student_name');
      if (pendingName != null && pendingName.isNotEmpty) {
        _log('Found pending name change: $pendingName');
        try {
          await ApiService.updateStudentProfile(name: pendingName);
          await prefs.remove('pending_student_name');
          _log('Background name sync successful.');
        } catch (e) {
          _log('Background name sync failed (still pending): $e');
        }
      }

      // 2. Refund Claims Sync
      final claims = await WalletDB.instance.getUnsyncedRefundClaims();
      if (claims.isNotEmpty) {
        _log('Syncing ${claims.length} refund claims...');
        final claimsPayload =
            claims
                .map(
                  (c) => {
                    'nonce': c['nonce'],
                    'actual_fare_naira': (c['actual_fare'] as int) ~/ 100,
                    'stop_id': c['stop_id'],
                    'gps_proof_json': c['gps_proof_json'],
                  },
                )
                .toList();

        await ApiService.studentSyncUpload(claimsPayload);
        final nonces = claims.map((c) => c['nonce'] as int).toList();
        await WalletDB.instance.clearSyncedRefundClaims(nonces);
        _log('Refund claims synced.');
      }

      // 3. Download Balance/State
      final serverState = await ApiService.studentSyncDownload();
      _serverBalanceNaira = (serverState['balance_naira'] as num).toDouble();
      _isBlacklisted = serverState['is_blacklisted'] as bool;

      if (_lockedKobo == 0) {
        await WalletDB.instance.updateBalance(
          (_serverBalanceNaira * 100).round(),
        );
        await _loadWalletState();
      }

      if (mounted) {
        setState(() => _lastSynced = DateTime.now());
        _showSuccess(
          'Synced! Balance: ₦${_serverBalanceNaira.toStringAsFixed(0)}',
        );
      }
    } on ApiException catch (e) {
      _log('Sync failed (API Error): ${e.message}');
      if (mounted) _showError('Sync failed: ${e.message}');
    } catch (e) {
      _log('Sync failed (Network Error): $e');
      if (mounted) {
        final msg =
            e.toString().contains('Timeout')
                ? 'Sync failed due to timeout because of slow internet.'
                : 'Offline — sync when connected.';
        _showError(msg);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.teal));
  }

  Widget _buildAvatar(ThemeData theme, double size) {
    return Consumer<UserProvider>(
      builder: (_, user, __) {
        final url = user.avatarUrl;
        if (url != null && url.isNotEmpty) {
          if (url.startsWith('/') || url.startsWith('file://')) {
            final path = url.replaceFirst('file://', '');
            return CircleAvatar(
              radius: size / 2,
              backgroundImage: FileImage(File(path)),
              backgroundColor: theme.primaryColor.withOpacity(0.1),
            );
          } else {
            final baseUrl = ApiService.baseUrl;
            final fullUrl = url.startsWith('http') ? url : '$baseUrl$url';
            return CircleAvatar(
              radius: size / 2,
              backgroundImage: NetworkImage(fullUrl),
              onBackgroundImageError: (_, __) {},
              backgroundColor: theme.primaryColor.withOpacity(0.1),
            );
          }
        }
        final initials =
            user.name.isNotEmpty
                ? user.name.substring(0, 1).toUpperCase()
                : '?';
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: theme.primaryColor.withOpacity(0.15),
          child: Text(
            initials,
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.4,
            ),
          ),
        );
      },
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  _buildAvatar(theme, 44),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<UserProvider>(
                      builder:
                          (_, user, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WELCOME BACK',
                                style: TextStyle(
                                  color: theme.pSecondaryText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              Text(
                                user.name.toUpperCase(),
                                style: TextStyle(
                                  color: theme.pPrimaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: theme.primaryColor,
                backgroundColor: theme.cardColor,
                onRefresh: () async {
                  await _syncWithServer();
                  await _loadWalletState();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Balance + Top Up ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AVAILABLE BALANCE',
                                  style: TextStyle(
                                    color: theme.pSecondaryText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                Text(
                                  '₦ ${(_balanceKobo / 100).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: theme.pPrimaryText,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (_lastSynced != null)
                                  Text(
                                    'Synced ${_timeSince(_lastSynced!)}',
                                    style: TextStyle(
                                      color: theme.pSecondaryText.withOpacity(
                                        0.5,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                            GestureDetector(
                              onTap:
                                  _currentQrPayload != null
                                      ? null
                                      : _showTopUpSheet,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _currentQrPayload != null
                                          ? theme.cardColor.withOpacity(0.5)
                                          : theme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      color:
                                          _currentQrPayload != null
                                              ? theme.pSecondaryText
                                                  .withOpacity(0.4)
                                              : Colors.black,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'TOP UP',
                                      style: TextStyle(
                                        color:
                                            _currentQrPayload != null
                                                ? theme.pSecondaryText
                                                    .withOpacity(0.4)
                                                : Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_lockedKobo > 0 || _isBlacklisted)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                          ).copyWith(bottom: 8),
                          child: Row(
                            children: [
                              if (_lockedKobo > 0)
                                Expanded(
                                  child: Text(
                                    'LOCKED: ₦${(_lockedKobo / 100).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              if (_isBlacklisted)
                                const Expanded(
                                  child: Text(
                                    '⚠️ ACCOUNT FLAGGED',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // ── Route + Passenger Selector ─────────────────────────
                      if (_currentQrPayload == null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildLocationDropdown(
                                  'PICKUP',
                                  _selectedPickup,
                                  (val) =>
                                      setState(() => _selectedPickup = val),
                                  theme,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildLocationDropdown(
                                  'DESTINATION',
                                  _selectedDropoff,
                                  (val) =>
                                      setState(() => _selectedDropoff = val),
                                  theme,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Passenger Count Selector
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Text(
                                'PASSENGERS',
                                style: TextStyle(
                                  color: theme.pSecondaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Spacer(),
                              _buildPassengerSelector(theme),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Total: ₦${((_farePerPersonKobo * _passengerCount) / 100).toStringAsFixed(0)} · ₦${(_farePerPersonKobo / 100).toStringAsFixed(0)}/person',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Transit Card / QR ──────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _currentQrPayload == null
                                  ? theme.pGlassBackground
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color:
                                _currentQrPayload == null
                                    ? theme.pGlassBorder
                                    : theme.primaryColor,
                            width: 2,
                          ),
                          boxShadow:
                              _currentQrPayload == null
                                  ? [
                                    BoxShadow(
                                      color: theme.shadowColor.withOpacity(0.1),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10),
                                    ),
                                  ]
                                  : [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Column(
                            children: [
                              // Card Header
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.directions_bus,
                                          color:
                                              _currentQrPayload == null
                                                  ? theme.pSecondaryText
                                                  : Colors.black87,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'CAMPUS TRANSIT',
                                          style: TextStyle(
                                            color:
                                                _currentQrPayload == null
                                                    ? theme.pSecondaryText
                                                    : Colors.black87,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_currentQrPayload != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _formatCountdown(_qrSecondsLeft),
                                          style: TextStyle(
                                            color:
                                                _qrSecondsLeft < 60
                                                    ? Colors.orangeAccent
                                                    : Colors.green,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.pSecondaryText
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'INACTIVE',
                                          style: TextStyle(
                                            color: theme.pSecondaryText,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // QR or Placeholder
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child:
                                    _currentQrPayload == null
                                        ? Container(
                                          height: 260,
                                          key: const ValueKey('inactive'),
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.qr_code_scanner_rounded,
                                                size: 80,
                                                color: theme.pPrimaryText
                                                    .withOpacity(0.05),
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                'NO ACTIVE PASS',
                                                style: TextStyle(
                                                  color: theme.pSecondaryText
                                                      .withOpacity(0.5),
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 2.0,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : Column(
                                          key: const ValueKey('active'),
                                          children: [
                                            // Countdown progress bar
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                  ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: _qrSecondsLeft / 300.0,
                                                  backgroundColor:
                                                      Colors.black12,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        _qrSecondsLeft < 60
                                                            ? Colors
                                                                .orangeAccent
                                                            : Colors
                                                                .greenAccent,
                                                      ),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 240,
                                              alignment: Alignment.center,
                                              child: _qrSecondsLeft > 0
                                                  ? QrImageView(
                                                      data: _currentQrPayload!.toJsonString(),
                                                      version: QrVersions.auto,
                                                      size: 220.0,
                                                      backgroundColor: Colors.white,
                                                    )
                                                  : const Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.timer_off_outlined, color: Colors.orangeAccent, size: 60),
                                                        SizedBox(height: 16),
                                                        Text('SCAN WINDOW CLOSED', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                                        SizedBox(height: 8),
                                                        Text('Trip is currently in progress.\nPress END TRIP when you arrive.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
                                                      ],
                                                    ),
                                            ),
                                            if (_passengerCount > 1)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Text(
                                                  '$_passengerCount passengers · ₦${(_farePerPersonKobo * _passengerCount / 100).toStringAsFixed(0)}',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                              ),

                              // Dashed divider
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                child: Row(
                                  children: List.generate(
                                    35,
                                    (index) => Expanded(
                                      child: Container(
                                        height: 2,
                                        color:
                                            _currentQrPayload == null
                                                ? theme.pSecondaryText
                                                    .withOpacity(0.1)
                                                : Colors.black12,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Card Footer
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ROUTE',
                                          style: TextStyle(
                                            color:
                                                _currentQrPayload == null
                                                    ? theme.pSecondaryText
                                                        .withOpacity(0.5)
                                                    : Colors.black38,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedDropoff != null
                                              ? '→ $_selectedDropoff'
                                              : '—',
                                          style: TextStyle(
                                            color:
                                                _currentQrPayload == null
                                                    ? theme.pSecondaryText
                                                    : Colors.black87,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'STUDENT ID',
                                          style: TextStyle(
                                            color:
                                                _currentQrPayload == null
                                                    ? theme.pSecondaryText
                                                        .withOpacity(0.5)
                                                    : Colors.black38,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _userId.toUpperCase(),
                                          style: TextStyle(
                                            color:
                                                _currentQrPayload == null
                                                    ? theme.pSecondaryText
                                                    : Colors.black87,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Action Button ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: GestureDetector(
                          onTap:
                              _currentQrPayload == null ? _startTrip : _endTrip,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 64,
                            decoration: BoxDecoration(
                              color:
                                  _currentQrPayload == null
                                      ? theme.primaryColor
                                      : theme.cardColor,
                              border: Border.all(
                                color:
                                    _currentQrPayload == null
                                        ? theme.primaryColor
                                        : Colors.orangeAccent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow:
                                  _currentQrPayload == null
                                      ? [
                                        BoxShadow(
                                          color: theme.primaryColor.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                      : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _currentQrPayload == null
                                  ? 'GENERATE SECURE PASS'
                                  : 'END TRIP & CONFIRM',
                              style: TextStyle(
                                color:
                                    _currentQrPayload == null
                                        ? Colors.black
                                        : Colors.orangeAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            theme.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap:
                _passengerCount > 1
                    ? () => setState(() => _passengerCount--)
                    : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    _passengerCount > 1
                        ? theme.primaryColor.withOpacity(0.15)
                        : theme.pSecondaryText.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove,
                size: 20,
                color:
                    _passengerCount > 1
                        ? theme.primaryColor
                        : theme.pSecondaryText.withOpacity(0.3),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            alignment: Alignment.center,
            child: Text(
              '$_passengerCount',
              style: TextStyle(
                color: theme.pPrimaryText,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap:
                _passengerCount < 4
                    ? () => setState(() => _passengerCount++)
                    : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    _passengerCount < 4
                        ? theme.primaryColor.withOpacity(0.15)
                        : theme.pSecondaryText.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 20,
                color:
                    _passengerCount < 4
                        ? theme.primaryColor
                        : theme.pSecondaryText.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDropdown(
    String label,
    String? value,
    Function(String?) onChanged,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.pSecondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border.all(color: theme.pSecondaryText.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
              style: TextStyle(
                color: theme.pPrimaryText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              onChanged: onChanged,
              items:
                  _availableStops.map((String stop) {
                    return DropdownMenuItem<String>(
                      value: stop,
                      child: Text(
                        stop,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
