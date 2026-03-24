import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/driver_db.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_container.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _driverName = "Driver";
  String? _avatarUrl;
  int _ridesToday = 0;
  int _pendingSync = 0;
  double _totalEarningsNaira = 0.0;
  double _withdrawableNaira = 0.0;
  bool _isBalanceVisible = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('driver_name') ?? "Driver";
    final avatar = prefs.getString('driver_avatar_url');
    
    final serverLedger = prefs.getDouble('server_ledger_naira') ?? 0.0;
    final serverAvailable = prefs.getDouble('server_available_naira') ?? 0.0;

    final notes = await DriverDB.instance.getUnsyncedNotes();
    
    int amountKobo = 0;
    for (var n in notes) {
      amountKobo += (n['amount_charged'] as int);
    }

    if (mounted) {
      setState(() {
        _driverName = name;
        _avatarUrl = avatar;
        _pendingSync = notes.length;
        _ridesToday = notes.length;
        _totalEarningsNaira = serverLedger + (amountKobo / 100);
        _withdrawableNaira = serverAvailable;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildMiniAvatar(ThemeData theme) {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('/') || _avatarUrl!.startsWith('file://')) {
        final path = _avatarUrl!.replaceFirst('file://', '');
        return CircleAvatar(
          radius: 22,
          backgroundImage: FileImage(File(path)),
          backgroundColor: theme.primaryColor.withOpacity(0.1),
        );
      } else {
        final baseUrl = ApiService.baseUrl;
        final fullUrl = _avatarUrl!.startsWith('http') ? _avatarUrl! : '$baseUrl$_avatarUrl';
        return CircleAvatar(
          radius: 22,
          backgroundImage: NetworkImage(fullUrl),
          onBackgroundImageError: (_, __) {},
          backgroundColor: theme.primaryColor.withOpacity(0.1),
        );
      }
    } else {
      final initials = _driverName.isNotEmpty ? _driverName.substring(0, 1).toUpperCase() : '?';
      return CircleAvatar(
        radius: 22,
        backgroundColor: theme.primaryColor.withOpacity(0.15),
        child: Text(initials, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
      );
    }
  }

  void _showWithdrawSheet() {
    final theme = Theme.of(context);
    final accountNumCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController();
    bool isProcessing = false;

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
              // Amount Preview
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
                    Text('WITHDRAWABLE BALANCE', style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Text('₦ ${_withdrawableNaira.toStringAsFixed(2)}', style: TextStyle(color: theme.pPrimaryText, fontSize: 36, fontWeight: FontWeight.w900)),
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
                        amountNaira: _withdrawableNaira,
                        bankAccount: num,
                        bankCode: name,
                      );
                      
                      final prefs = await SharedPreferences.getInstance();
                      final currentWithdrawn = prefs.getDouble('local_withdrawn_naira') ?? 0.0;
                      await prefs.setDouble('local_withdrawn_naira', currentWithdrawn + _withdrawableNaira);
                      
                      await _loadData();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Withdrawal successful.'),
                            backgroundColor: Colors.teal,
                          ),
                        );
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
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.primaryColor,
          backgroundColor: theme.cardColor,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header Row: Avatar, Greeting, Notifications
                Padding(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
                  child: Row(
                    children: [
                      _buildMiniAvatar(theme),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getGreeting(), style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text(
                              _driverName,
                              style: TextStyle(color: theme.pPrimaryText, fontSize: 22, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: theme.pPrimaryText.withOpacity(0.05), shape: BoxShape.circle),
                          child: Icon(Icons.notifications_none, color: theme.pPrimaryText, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Massive Earnings Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL EARNINGS',
                                style: TextStyle(color: theme.primaryColor, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2.0),
                              ),
                              Icon(_isBalanceVisible ? Icons.visibility_off : Icons.visibility, color: theme.pSecondaryText, size: 28),
                            ],
                          ),
                          const SizedBox(height: 20),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isBalanceVisible ? '₦ ${_totalEarningsNaira.toStringAsFixed(2)}' : '₦ ••••••••',
                              style: TextStyle(color: theme.pPrimaryText, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Withdraw Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.account_balance, size: 22),
                      label: const Text('WITHDRAW FUNDS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _showWithdrawSheet,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(24),
                          borderRadius: 20,
                          child: Column(
                            children: [
                              Text('RIDES', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                              const SizedBox(height: 12),
                              Text('$_ridesToday', style: TextStyle(color: theme.pPrimaryText, fontSize: 36, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(24),
                          borderRadius: 20,
                          child: Column(
                            children: [
                              Text('PENDING', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$_pendingSync', style: TextStyle(color: theme.pPrimaryText, fontSize: 36, fontWeight: FontWeight.w800)),
                                  if (_pendingSync > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 10, height: 10,
                                      decoration: const BoxDecoration(color: Colors.deepOrangeAccent, shape: BoxShape.circle),
                                    )
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
