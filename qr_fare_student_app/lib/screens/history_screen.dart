import 'package:flutter/material.dart';
import '../db/wallet_db.dart';
import '../theme/theme_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final trips = await WalletDB.instance.getTripHistory();
    if (mounted) {
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: theme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Text('TRIP HISTORY', style: TextStyle(color: theme.pPrimaryText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                  : RefreshIndicator(
                      color: theme.primaryColor,
                      backgroundColor: theme.cardColor,
                      onRefresh: _loadHistory,
                      child: _trips.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              itemCount: _trips.length,
                              itemBuilder: (context, index) {
                                final trip = _trips[index];
                                return _buildTripCard(trip, theme, index);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 80, color: theme.pSecondaryText.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text('NO TRIPS YET', style: TextStyle(color: theme.pSecondaryText.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 3.0, fontSize: 16)),
            const SizedBox(height: 12),
            Text('Generate your first pass\nto start tracking your trips.', textAlign: TextAlign.center, style: TextStyle(color: theme.pSecondaryText.withOpacity(0.35), fontSize: 14, height: 1.6)),
          ],
        ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, ThemeData theme, int index) {
    final fareNaira = (trip['fare_kobo'] as int) / 100.0;
    final isRecent = index == 0;

    return GestureDetector(
      onTap: () => _showTripDetail(trip, theme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRecent ? theme.primaryColor.withOpacity(0.4) : theme.pSecondaryText.withOpacity(0.1),
            width: isRecent ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Route icon column
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle)),
                  Container(width: 2, height: 28, color: theme.pSecondaryText.withOpacity(0.2)),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Route labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip['pickup'] as String, style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(trip['destination'] as String, style: TextStyle(color: theme.pSecondaryText, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Fare + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₦ ${fareNaira.toStringAsFixed(0)}', style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                Text(_formatTime(trip['timestamp'] as int), style: TextStyle(color: theme.pSecondaryText, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: theme.pSecondaryText.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  void _showTripDetail(Map<String, dynamic> trip, ThemeData theme) {
    final fareNaira = (trip['fare_kobo'] as int) / 100.0;
    final dt = DateTime.fromMillisecondsSinceEpoch(trip['timestamp'] as int);
    final dateStr = '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.pSecondaryText.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 28),
            Text('TRIP DETAILS', style: TextStyle(color: theme.pSecondaryText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
            const SizedBox(height: 20),
            _detailRow('FROM', trip['pickup'] as String, theme),
            const SizedBox(height: 16),
            _detailRow('TO', trip['destination'] as String, theme),
            const SizedBox(height: 16),
            _detailRow('FARE PAID', '₦ ${fareNaira.toStringAsFixed(2)}', theme, valueColor: theme.primaryColor),
            const SizedBox(height: 16),
            _detailRow('DATE', dateStr, theme),
            const SizedBox(height: 16),
            _detailRow('TRIP NONCE', '#${trip['nonce']}', theme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.pSecondaryText, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
        const SizedBox(width: 24),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: valueColor ?? theme.pPrimaryText, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
