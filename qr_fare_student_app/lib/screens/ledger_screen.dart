import 'package:flutter/material.dart';
import '../db/wallet_db.dart';
import '../widgets/logo_loader.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/snackbar_helper.dart';
import '../theme/theme_provider.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  int _balanceKobo = 0;
  int _lockedKobo = 0;
  int _unsyncedClaimsCount = 0;
  int _pendingRefundKobo = 0;
  bool _isSyncing = false;
  double _serverBalanceNaira = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final state = await WalletDB.instance.getWalletState();
    final claims = await WalletDB.instance.getUnsyncedRefundClaims();
    
    if (mounted) {
      setState(() {
        _balanceKobo = state['balance'] as int;
        _lockedKobo = state['locked_amount'] as int;
        _unsyncedClaimsCount = claims.length;
        _pendingRefundKobo = claims.length * 5000;
      });
    }
  }

  Future<void> _loginIfNeeded() async {
    if (await ApiService.isLoggedIn()) return;
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? '';
    final password = prefs.getString('student_password') ?? '';
    if (studentId.isNotEmpty && password.isNotEmpty) {
      try {
        await ApiService.login(userId: studentId, password: password, role: 'student');
      } catch (_) {}
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await _loginIfNeeded();
      
      final claims = await WalletDB.instance.getUnsyncedRefundClaims();
      if (claims.isNotEmpty) {
        final claimsPayload = claims.map((c) => {
          'nonce': c['nonce'],
          'actual_fare_naira': (c['actual_fare'] as int) ~/ 100,
          'stop_id': c['stop_id'],
          'gps_proof_json': c['gps_proof_json'],
        }).toList();

        await ApiService.studentSyncUpload(claimsPayload);
        final nonces = claims.map((c) => c['nonce'] as int).toList();
        await WalletDB.instance.clearSyncedRefundClaims(nonces);
      }

      final serverState = await ApiService.studentSyncDownload();
      _serverBalanceNaira = (serverState['balance_naira'] as num).toDouble();
      
      if (_lockedKobo == 0) {
        await WalletDB.instance.updateBalance((_serverBalanceNaira * 100).round());
      }

      await _loadBalance();
      if (mounted) showGlassSnackBar(context, '✅ Synced successfully with Cloud!');
    } on ApiException catch (e) {
      if (mounted) showGlassSnackBar(context, 'Sync failed: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) showGlassSnackBar(context, 'Offline — sync when connected.', isWarning: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _handleDeposit() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5))),
        title: Text('DEPOSIT FUNDS', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        content: Text(
          'Online payment gateway will be implemented here. When completed, you can instantly top up your wallet using a card or bank transfer.',
          style: TextStyle(color: Theme.of(context).pSecondaryText, fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double available = _balanceKobo / 100.0;
    final double locked = _lockedKobo / 100.0;
    final double pending = _pendingRefundKobo / 100.0;
    final double total = available + locked + pending;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Custom Sleek Header
                Padding(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: theme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text('LEDGER', style: TextStyle(color: theme.pPrimaryText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                      const Spacer(),
                    ],
                  ),
                ),

                // Main Ledger Content
                Expanded(
                  child: RefreshIndicator(
                    color: theme.primaryColor,
                    backgroundColor: theme.cardColor,
                    onRefresh: _loadBalance,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 32),

                        // Massive Hero Floating Balance
                        Center(
                          child: Text('TOTAL WALLET VALUE', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            '₦ ${total.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: theme.pPrimaryText, height: 1.0, shadows: [
                              Shadow(color: theme.pPrimaryText.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10))
                            ]),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Side-by-side Quick Actions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Expanded(child: _buildActionTile(Icons.account_balance, 'TOP UP', theme.primaryColor, theme, _handleDeposit)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildActionTile(Icons.sync, 'SYNC WALLET', Colors.orangeAccent, theme, _isSyncing ? null : _syncNow)),
                            ],
                          ),
                        ),

                        // Explicit Flat Explanatory Breakdown List
                        Padding(
                          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 56.0, bottom: 8.0),
                          child: Text('LEDGER BREAKDOWN', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                        ),

                        _buildBreakdownRow(
                          title: 'AVAILABLE TO SPEND',
                          amount: available,
                          description: 'Funds ready to use for generating your next transit QR pass safely.',
                          color: theme.primaryColor,
                          theme: theme,
                        ),
                        Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 24, endIndent: 24),
                        
                        _buildBreakdownRow(
                          title: 'LOCKED FOR TRANSIT',
                          amount: locked,
                          description: 'Maximum baseline fare currently being held securely until your active trip ends.',
                          color: Colors.orangeAccent,
                          theme: theme,
                        ),
                        Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 24, endIndent: 24),

                        _buildBreakdownRow(
                          title: 'PENDING REFUNDS',
                          amount: pending,
                          description: 'Expected refunds from recently ended offline trips waiting to be synced entirely.',
                          color: theme.pPrimaryText,
                          theme: theme,
                          extraInfo: _unsyncedClaimsCount > 0 ? '($_unsyncedClaimsCount offline claims waiting to sync)' : null,
                        ),

                        const SizedBox(height: 120), // Clearance for navbar
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Colossal Center Loading Overlay
            if (_isSyncing)
              Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.92),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LogoLoader(size: 80),
                    const SizedBox(height: 32),
                    Text('SYNCING TO CLOUD...', style: TextStyle(color: theme.primaryColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3.0)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, Color color, ThemeData theme, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: color.withOpacity(theme.isDark ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({required String title, required double amount, required String description, required Color color, required ThemeData theme, String? extraInfo}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
               Text('₦ ${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: theme.pSecondaryText, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500)),
          if (extraInfo != null) ...[
             const SizedBox(height: 8),
             Text(extraInfo, style: TextStyle(color: color.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }
}
