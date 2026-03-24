import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import '../db/driver_db.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/logo_loader.dart';
import '../theme/theme_provider.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  int _unsyncedNotesCount = 0;
  int _unsyncedAmountKobo = 0;
  double _serverLedgerNaira = 0;
  double _serverAvailableNaira = 0;
  double _localWithdrawnNaira = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final double savedLedger = prefs.getDouble('server_ledger_naira') ?? 0.0;
    final double savedAvailable = prefs.getDouble('server_available_naira') ?? 0.0;
    final double savedWithdrawn = prefs.getDouble('local_withdrawn_naira') ?? 0.0;

    final notes = await DriverDB.instance.getUnsyncedNotes();
    int amount = 0;
    for (var n in notes) {
      amount += (n['amount_charged'] as int);
    }
    setState(() {
      _unsyncedNotesCount = notes.length;
      _unsyncedAmountKobo = amount;
      _serverLedgerNaira = savedLedger;
      _serverAvailableNaira = savedAvailable;
      _localWithdrawnNaira = savedWithdrawn;
    });
  }

  Future<void> _loginIfNeeded() async {
    if (await ApiService.isLoggedIn()) return;
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driver_id') ?? '';
    final password = prefs.getString('driver_password') ?? '';
    if (driverId.isNotEmpty && password.isNotEmpty) {
      try {
        await ApiService.login(userId: driverId, password: password, role: 'driver');
      } catch (_) {}
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await _loginIfNeeded();

      // 1. Upload unsynced promise notes
      final notes = await DriverDB.instance.getUnsyncedNotes();
      if (notes.isNotEmpty) {
        final notesPayload = notes.map((n) => {
          'student_id': n['user_id'],
          'amount_charged_naira': (n['amount_charged'] as int) ~/ 100,
          'nonce': n['nonce'],
          'signature': n['signature'],
          'raw_payload': n['raw_payload'],
          'timestamp': n['scanned_at'],
        }).toList();

        await ApiService.driverSyncUpload(notesPayload);
        final ids = notes.map((n) => n['id'] as int).toList();
        await DriverDB.instance.markNotesSynced(ids);
      }

      // 2. Download blacklist, public keys, and balances
      final data = await ApiService.driverSyncDownload();

      // Update local blacklist
      final blacklist = List<String>.from(data['blacklisted_student_ids']);
      await DriverDB.instance.updateBlacklist(blacklist);

      // Cache public keys
      final pubKeys = List<Map<String, dynamic>>.from(data['public_keys']);
      for (var pk in pubKeys) {
        await DriverDB.instance.savePublicKey(pk['student_id'], pk['public_key_pem']);
      }

      setState(() {
        _serverLedgerNaira = (data['ledger_balance_naira'] as num).toDouble();
        _serverAvailableNaira = (data['available_balance_naira'] as num).toDouble();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('server_ledger_naira', _serverLedgerNaira);
      await prefs.setDouble('server_available_naira', _serverAvailableNaira);

      await _loadBalance();
      if (mounted) showGlassSnackBar(context, '✅ Synced! ${blacklist.length} blacklisted, ${pubKeys.length} keys cached');
    } on ApiException catch (e) {
      if (mounted) showGlassSnackBar(context, 'Sync failed: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) showGlassSnackBar(context, 'Offline — sync when connected.', isWarning: true);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _handleWithdraw() {
    final theme = Theme.of(context);
    final accountNumCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController();
    bool isProcessing = false;
    final double withdrawable = _serverAvailableNaira;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: theme.pSecondaryText.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text('WITHDRAW FUNDS', style: TextStyle(color: theme.primaryColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              const SizedBox(height: 4),
              Text('Enter your bank details to proceed with withdrawal.', style: TextStyle(color: theme.pSecondaryText, fontSize: 14, height: 1.4)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text('READY TO WITHDRAW', style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Text('₦ ${withdrawable.toStringAsFixed(2)}', style: TextStyle(color: theme.pPrimaryText, fontSize: 36, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: accountNumCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 2.0),
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  labelStyle: TextStyle(color: theme.pSecondaryText),
                  counterText: '',
                  prefixIcon: Icon(Icons.account_balance, color: theme.primaryColor),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: accountNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  labelStyle: TextStyle(color: theme.pSecondaryText),
                  prefixIcon: Icon(Icons.person_outline, color: theme.primaryColor),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isProcessing ? null : () async {
                    final num = accountNumCtrl.text.trim();
                    final name = accountNameCtrl.text.trim();
                    if (num.length < 10 || name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: const Text('Please fill in all fields correctly.'), backgroundColor: Colors.redAccent.shade700),
                      );
                      return;
                    }
                    setSheetState(() => isProcessing = true);
                    try {
                      final res = await ApiService.withdrawFunds(
                        amountNaira: withdrawable,
                        bankAccount: num,
                        bankCode: name,
                      );
                      
                      final prefs = await SharedPreferences.getInstance();
                      final currentWithdrawn = prefs.getDouble('local_withdrawn_naira') ?? 0.0;
                      await prefs.setDouble('local_withdrawn_naira', currentWithdrawn + withdrawable);
                      
                      // Fetch new balances down from the server sync immediately
                      await _syncNow();
                      
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        if (mounted) showGlassSnackBar(context, res['message'] ?? 'Withdrawal successful.');
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString().replaceAll('ApiException', '').trim()}'), backgroundColor: Colors.redAccent.shade700),
                        );
                      }
                    } finally {
                      if (ctx.mounted) {
                        setSheetState(() => isProcessing = false);
                      }
                    }
                  },
                  child: isProcessing
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('INITIATE WITHDRAWAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Calculate logical balances
    final double withdrawable = _serverAvailableNaira;
    // Pending includes money the server is processing offline, PLUS offline money strictly on device
    final double pending = (_serverLedgerNaira - _serverAvailableNaira) + (_unsyncedAmountKobo / 100);
    final double total = _serverLedgerNaira + (_unsyncedAmountKobo / 100);

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
                      Icon(Icons.account_balance_wallet, color: theme.primaryColor, size: 28),
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

                        // Massive Hero Floating Balance (Fintech Apple-Card style)
                        Center(
                          child: Text('TOTAL BALANCE', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
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
                              Expanded(child: _buildActionTile(Icons.account_balance, 'WITHDRAW', theme.primaryColor, theme, _handleWithdraw)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildActionTile(Icons.sync, 'SYNC FARES', Colors.orangeAccent, theme, _isSyncing ? null : _syncNow)),
                            ],
                          ),
                        ),

                        // Explicit Flat Explanatory Breakdown List
                        Padding(
                          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 56.0, bottom: 8.0),
                          child: Text('LEDGER BREAKDOWN', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                        ),

                        _buildBreakdownRow(
                          title: 'READY TO WITHDRAW',
                          amount: withdrawable,
                          description: 'Money that has fully cleared and is ready to be transferred to your bank account.',
                          color: theme.primaryColor,
                          theme: theme,
                        ),
                        Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 24, endIndent: 24),
                        
                        _buildBreakdownRow(
                          title: 'PENDING CLEARANCE',
                          amount: pending,
                          description: 'Fares you scanned offline today, or fares still waiting for final bank processing.',
                          color: Colors.orangeAccent,
                          extraInfo: _unsyncedNotesCount > 0 ? '($_unsyncedNotesCount offline scans waiting to upload)' : null,
                          theme: theme,
                        ),
                        Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 24, endIndent: 24),

                        _buildBreakdownRow(
                          title: 'TOTAL WITHDRAWN',
                          amount: _localWithdrawnNaira,
                          description: 'The lifetime sum of all money you have successfully withdrawn to your bank account.',
                          color: Colors.greenAccent.shade700,
                          theme: theme,
                        ),
                        Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 24, endIndent: 24),

                        _buildBreakdownRow(
                          title: 'TOTAL COMBINED EARNINGS',
                          amount: total,
                          description: 'The complete sum of everything; all cleared and pending fares combined.',
                          color: theme.pPrimaryText,
                          theme: theme,
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
                color: theme.pBackground.withOpacity(0.85), // Replaces pure black overlay
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
          color: color.withOpacity(theme.isDark ? 0.05 : 0.1), // Adjusted for light mode contrast
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
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({required String title, required double amount, required String description, required Color color, String? extraInfo, required ThemeData theme}) {
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
