import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_fare_crypto_core/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/theme_provider.dart';
import '../widgets/glass_container.dart';
import 'entry_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _driverName = "Loading...";
  String _driverId = "---";
  String? _avatarUrl;
  String _currentTheme = 'System Default';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    setState(() {
      _driverName = prefs.getString('driver_name') ?? 'Unknown Driver';
      _driverId = prefs.getString('driver_id') ?? 'N/A';
      _avatarUrl = prefs.getString('driver_avatar_url');
      _currentTheme = themeProvider.themeName;
    });
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[DRIVER_PROFILE] $msg');
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Widget _buildAvatarWidget(ThemeData theme) {
    Widget avatarContent;
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('/') || _avatarUrl!.startsWith('file://')) {
        final path = _avatarUrl!.replaceFirst('file://', '');
        avatarContent = CircleAvatar(
          radius: 43,
          backgroundImage: FileImage(File(path)),
          backgroundColor: theme.primaryColor.withOpacity(0.1),
        );
      } else {
        final baseUrl = ApiService.baseUrl;
        final fullUrl = _avatarUrl!.startsWith('http') ? _avatarUrl! : '$baseUrl$_avatarUrl';
        avatarContent = CircleAvatar(
          radius: 43,
          backgroundImage: NetworkImage(fullUrl),
          onBackgroundImageError: (_, __) {},
          backgroundColor: theme.primaryColor.withOpacity(0.1),
        );
      }
    } else {
      final initials = _driverName.isNotEmpty ? _driverName.substring(0, 1).toUpperCase() : '?';
      avatarContent = CircleAvatar(
        radius: 43,
        backgroundColor: theme.primaryColor.withOpacity(0.15),
        child: Text(initials, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w900, fontSize: 32)),
      );
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 2),
          ),
          child: avatarContent,
        ),
        Positioned(
          bottom: 0, right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
              ),
              child: _isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.camera_alt, color: Colors.black, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      // 1. Save Locally (Offline First)
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'driver_avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
      final localPath = p.join(appDir.path, fileName);

      await File(picked.path).copy(localPath);
      _log('Saved avatar locally: $localPath');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_avatar_url', localPath);
      await prefs.setString('pending_driver_avatar_path', localPath);

      if (mounted) {
        setState(() => _avatarUrl = localPath);
        _showSuccess('Photo updated locally. Syncing in background...');
      }

      // 2. Silent Background Upload
      try {
        _log('Attempting silent avatar upload...');
        final result = await ApiService.uploadDriverAvatar(localPath); // Same endpoint works for driver
        final serverUrl = result['avatar_url'] as String? ?? result['url'] as String?;
        if (serverUrl != null) {
          await prefs.setString('driver_avatar_url', serverUrl);
          await prefs.remove('pending_driver_avatar_path');
          if (mounted) setState(() => _avatarUrl = serverUrl);
          _log('Background upload succeeded.');
        }
      } catch (e) {
        _log('Silent upload failed (will retry on next sync): $e');
      }
    } catch (e) {
      _log('Local save failed: $e');
      if (mounted) _showError('Failed to save photo: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Edit Name ──────────────────────────────────────────────────────────────

  void _showEditNameSheet() {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: _driverName);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: theme.pSecondaryText.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('EDIT DISPLAY NAME', style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: theme.pSecondaryText),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving ? null : () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;
                  setSheetState(() => isSaving = true);
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('driver_name', newName);
                    await prefs.setString('pending_driver_name', newName);

                    if (mounted) {
                      setState(() => _driverName = newName);
                      Navigator.pop(ctx);
                      _showSuccess('Name updated locally. Syncing in background...');
                    }

                    // Silent Background Sync
                    try {
                      _log('Attempting silent name sync...');
                      await ApiService.updateStudentProfile(name: newName);
                      await prefs.remove('pending_driver_name');
                      _log('Silent name sync successful!');
                    } catch (e) {
                      _log('Silent name sync failed (will retry): $e');
                    }
                  } finally {
                    if (mounted) setSheetState(() => isSaving = false);
                  }
                },
                child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      )),
    );
  }

  // ── Change PIN ─────────────────────────────────────────────────────────────

  void _showChangePinSheet() {
    final theme = Theme.of(context);
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: theme.pSecondaryText.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('CHANGE PASSWORD', style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            _buildPinField(currentPinCtrl, 'Current Password', theme),
            const SizedBox(height: 12),
            _buildPinField(newPinCtrl, 'New Password', theme),
            const SizedBox(height: 12),
            _buildPinField(confirmPinCtrl, 'Confirm New Password', theme),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving ? null : () async {
                  if (newPinCtrl.text != confirmPinCtrl.text) {
                    _showError('New passwords do not match');
                    return;
                  }
                  if (newPinCtrl.text.length < 4) {
                    _showError('Password must be at least 4 characters');
                    return;
                  }
                  setSheetState(() => isSaving = true);
                  try {
                    // Save locally (dummy for hackathon — no real password API)
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('driver_password', newPinCtrl.text);
                    _log('Password updated locally.');
                    if (mounted) {
                      Navigator.pop(ctx);
                      _showSuccess('Password changed successfully!');
                    }
                  } catch (e) {
                    if (mounted) _showError('Failed: $e');
                  } finally {
                    if (mounted) setSheetState(() => isSaving = false);
                  }
                },
                child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('UPDATE PASSWORD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      )),
    );
  }

  Widget _buildPinField(TextEditingController ctrl, String label, ThemeData theme) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: TextStyle(color: theme.pPrimaryText, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.pSecondaryText),
        filled: true,
        fillColor: theme.cardColor,
        prefixIcon: Icon(Icons.lock_outline, color: theme.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor)),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('CONFIRM LOGOUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ],
        ),
        content: Text(
          'Are you sure you want to end your shift? Unsynced fares will be kept securely on your device.',
          style: TextStyle(color: Theme.of(context).pSecondaryText, fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Theme.of(context).pSecondaryText, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DriverEntryScreen()),
                (route) => false,
              );
            },
            child: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('DELETE ACCOUNT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ],
        ),
        content: Text(
          'This action is irreversible. All your driver data will be permanently deleted.',
          style: TextStyle(color: Theme.of(context).pSecondaryText, fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Theme.of(context).pSecondaryText, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DriverEntryScreen()),
                (route) => false,
              );
            },
            child: const Text('PERMANENTLY DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  void _showThemePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('APPEARANCE', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                  const SizedBox(height: 16),
                  _buildThemeOption('System Default', Icons.brightness_auto, setModalState, themeProvider),
                  _buildThemeOption('Light Mode', Icons.light_mode, setModalState, themeProvider),
                  _buildThemeOption('Dark Mode', Icons.dark_mode, setModalState, themeProvider),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildThemeOption(String title, IconData icon, StateSetter setModalState, ThemeProvider themeProvider) {
    final isSelected = _currentTheme == title;
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.primaryColor : theme.pSecondaryText.withOpacity(0.5)),
      title: Text(title, style: TextStyle(color: isSelected ? theme.pPrimaryText : theme.pSecondaryText, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check, color: theme.primaryColor) : null,
      onTap: () {
        setModalState(() => _currentTheme = title); 
        setState(() => _currentTheme = title); 
        themeProvider.setTheme(title);
        Navigator.pop(context);
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.teal),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Text(
                  'DRIVER HUB', 
                  style: TextStyle(color: theme.pPrimaryText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5)
                ),
              ),

              // Driver ID Card
              GlassContainer(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                padding: const EdgeInsets.all(24),
                borderRadius: 28,
                child: Row(
                  children: [
                    _buildAvatarWidget(theme),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverName, 
                            style: TextStyle(color: theme.pPrimaryText, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('ID: $_driverId', style: TextStyle(color: theme.pAccentText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Account Settings
              Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 8.0),
                child: Text('ACCOUNT', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              ),
              _buildListRow(Icons.edit_note, 'Edit Display Name', theme, onTap: _showEditNameSheet),
              Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 68),
              _buildListRow(Icons.shield_outlined, 'Change Password', theme, onTap: _showChangePinSheet),
              Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 68),
              _buildListRow(Icons.notifications_outlined, 'Notifications', theme, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              }),

              // Preferences
              Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 8.0),
                child: Text('PREFERENCES', style: TextStyle(color: theme.pSecondaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              ),
              _buildListRow(Icons.brightness_medium, 'App Appearance', theme, trailingText: _currentTheme, onTap: _showThemePicker),
              Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 68),
              _buildListRow(Icons.support_agent_outlined, 'Help & Support', theme, onTap: () {}),

              // Danger Zone
              const Padding(
                padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 8.0),
                child: Text('DANGER ZONE', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              ),
              _buildListRow(Icons.power_settings_new, 'Safe Log Out', theme, isDestructive: true, onTap: _handleLogout),
              Divider(color: theme.pSecondaryText.withOpacity(0.1), height: 1, indent: 68),
              _buildListRow(Icons.person_remove, 'Delete Account', theme, isDestructive: true, onTap: _handleDeleteAccount),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListRow(IconData icon, String title, ThemeData theme, {bool isDestructive = false, String? trailingText, VoidCallback? onTap}) {
    final color = isDestructive ? Colors.redAccent : theme.pPrimaryText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Row(
            children: [
              Icon(icon, color: isDestructive ? Colors.redAccent : theme.primaryColor, size: 28),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              if (trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(trailingText, style: TextStyle(color: theme.pSecondaryText, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              Icon(Icons.arrow_forward_ios, color: theme.pSecondaryText.withOpacity(0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
