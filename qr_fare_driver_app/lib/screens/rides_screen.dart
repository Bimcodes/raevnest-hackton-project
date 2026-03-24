import 'package:flutter/material.dart';
import '../db/driver_db.dart';
import '../theme/theme_provider.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final notes = await DriverDB.instance.getAllNotes(limit: 50);
    setState(() {
      _rides = notes;
      _isLoading = false;
    });
  }

  String _formatTime(int epochSeconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month} • $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Sleek Header
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
              child: Row(
                children: [
                   Icon(Icons.format_list_bulleted_outlined, color: theme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                   Text('RIDE HISTORY', style: TextStyle(color: theme.pPrimaryText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                  const Spacer(),
                ],
              ),
            ),

             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('RECENT SCANS', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              ),
            ),

            Expanded(
              child: _isLoading
                ?  Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : _rides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 60, color: theme.pSecondaryText.withOpacity(0.2)),
                          const SizedBox(height: 16),
                           Text('No rides scanned yet.', style: TextStyle(color: theme.pSecondaryText, fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: theme.primaryColor,
                      backgroundColor: theme.cardColor,
                      onRefresh: _loadHistory,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        itemCount: _rides.length + 1, // +1 for navbar clearance
                        separatorBuilder: (context, index) {
                          if (index == _rides.length - 1) return const SizedBox.shrink(); // Don't separate the massive bottom padding
                          return const SizedBox(height: 16);
                        },
                        itemBuilder: (context, index) {
                          if (index == _rides.length) return const SizedBox(height: 120); // Extruded navbar pad

                          final ride = _rides[index];
                          final bool isSynced = (ride['is_synced'] as int) == 1;
                          final double amount = (ride['amount_charged'] as int) / 100;
                          final String timeStr = _formatTime(ride['scanned_at'] as int);
                          final String studentId = (ride['user_id'] as String).toUpperCase();

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: theme.pSecondaryText.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                // Left Icon Identity
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child:  Icon(Icons.person, color: theme.primaryColor, size: 24),
                                ),
                                const SizedBox(width: 16),
                                
                                // Middle Meta Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ID: $studentId', style:  TextStyle(color: theme.pPrimaryText, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(isSynced ? Icons.cloud_done : Icons.cloud_upload, size: 14, color: isSynced ? Colors.greenAccent : Colors.orangeAccent),
                                          const SizedBox(width: 6),
                                          Text(timeStr, style:  TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Right Financial Impact
                                Text('₦${amount.toStringAsFixed(0)}', style:  TextStyle(color: theme.pPrimaryText, fontSize: 20, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
