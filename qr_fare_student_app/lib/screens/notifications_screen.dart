import 'package:flutter/material.dart';
import 'package:qr_fare_crypto_core/api_service.dart';
import '../theme/theme_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    _log('Fetching notifications...');
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchNotifications();
      _log('Successfully fetched ${data.length} notifications.');
      if (mounted) setState(() => _notifications = data);
    } catch (e) {
      _log('Error fetching notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[NOTIFICATIONS_DEBUG] $msg');
  }

  Future<void> _markAsRead(int id, int index) async {
    _log('Marking notification $id as read...');
    try {
      await ApiService.markNotificationRead(id);
      _log('Successfully marked $id as read.');
      if (mounted) {
        setState(() {
          _notifications[index]['is_read'] = true;
        });
      }
    } catch (e) {
      _log('Error marking $id as read: $e');
    }
  }

  String _timeAgo(String createdAt) {
    final date = DateTime.tryParse(createdAt);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.pPrimaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: theme.pPrimaryText,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount new',
                  style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          IconButton(
            icon: _isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                : Icon(Icons.refresh, color: theme.primaryColor),
            onPressed: _isLoading ? null : _fetchNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  color: theme.primaryColor,
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == true;
                      return _buildNotificationTile(theme, n, isRead, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: theme.pSecondaryText.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(color: theme.pSecondaryText, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see announcements here',
            style: TextStyle(color: theme.pSecondaryText.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(ThemeData theme, Map<String, dynamic> n, bool isRead, int index) {
    return GestureDetector(
      onTap: () {
        if (!isRead) _markAsRead(n['id'] as int, index);
        _showNotificationDetail(theme, n);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? theme.cardColor.withOpacity(0.5)
              : theme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? theme.pGlassBorder.withOpacity(0.2)
                : theme.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRead
                    ? theme.pSecondaryText.withOpacity(0.1)
                    : theme.primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRead ? Icons.mail_outline : Icons.mark_email_unread_outlined,
                color: isRead ? theme.pSecondaryText : theme.primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] ?? 'Notification',
                    style: TextStyle(
                      color: theme.pPrimaryText,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['body'] ?? '',
                    style: TextStyle(color: theme.pSecondaryText, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(n['created_at'] ?? ''),
                  style: TextStyle(color: theme.pSecondaryText.withOpacity(0.6), fontSize: 10),
                ),
                if (!isRead) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetail(ThemeData theme, Map<String, dynamic> n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.pSecondaryText.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              n['title'] ?? 'Notification',
              style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _timeAgo(n['created_at'] ?? ''),
              style: TextStyle(color: theme.pSecondaryText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              n['body'] ?? '',
              style: TextStyle(color: theme.pPrimaryText, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
