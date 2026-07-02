import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../legal/terms_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  // ──────────────────────────────────────────────────────────
  //  Delete Account Flow
  // ──────────────────────────────────────────────────────────

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is permanent and cannot be undone.\n\nAll your data will be permanently deleted:',
                  style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                _deletionItem('Your profile and personal info'),
                _deletionItem('All posts, photos, and comments'),
                _deletionItem('Direct messages and chat history'),
                _deletionItem('Followers and following lists'),
                const SizedBox(height: 20),
                const Text(
                  'Enter your password to confirm:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1F1F1F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    errorText: errorText,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
            TextButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  setDialogState(() => errorText = 'Password is required');
                  return;
                }
                try {
                  final authService = context.read<AuthService>();
                  final email = authService.currentUser?.email ?? '';
                  await authService.reauthenticate(email, password);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setDialogState(() => errorText = 'Incorrect password');
                }
              },
              child: const Text('Delete Forever', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      // Store navigator reference before async gap
      final rootNav = Navigator.of(context, rootNavigator: true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              color: Color(0xFF2A2A2A),
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 16),
                    Text('Deleting account...', style: TextStyle(color: Colors.white)),
                    SizedBox(height: 4),
                    Text('This may take a moment', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      try {
        final authService = context.read<AuthService>();
        await authService.deleteAccountPermanently();
        // Dismiss the loading dialog and pop to root — AuthWrapper will show LoginPage
        if (rootNav.mounted) {
          rootNav.popUntil((route) => route.isFirst);
        }
      } catch (e) {
        // Dismiss loading dialog
        if (rootNav.mounted) {
          rootNav.pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _deletionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account Section ──
          _buildSectionHeader('Account'),
          _buildTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () => Navigator.pop(context, 'edit_profile'),
          ),
          _buildTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your password via email',
            onTap: () async {
              final authService = context.read<AuthService>();
              final email = authService.currentUser?.email;
              if (email == null || email.isEmpty) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Error', style: TextStyle(color: Colors.red)),
                      content: const Text('Could not find your email address.', style: TextStyle(color: Colors.grey)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFFF29F05)))),
                      ],
                    ),
                  );
                }
                return;
              }
              try {
                await authService.sendPasswordResetEmail(email);
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Email Sent ✓', style: TextStyle(color: Colors.white)),
                      content: Text(
                        'A password reset link has been sent to:\n$email\n\nCheck your inbox (and spam folder) and follow the link to update your password.',
                        style: const TextStyle(color: Colors.grey, height: 1.5),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFFF29F05), fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Error', style: TextStyle(color: Colors.red)),
                      content: Text('Failed to send reset email: $e', style: const TextStyle(color: Colors.grey)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFFF29F05)))),
                      ],
                    ),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 16),

          // ── About Section ──
          _buildSectionHeader('About'),
          _buildTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.2',
            showChevron: false,
          ),
          _buildTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () async {
              final uri = Uri.parse('https://hhf-social.web.app/privacy-policy.html');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          _buildTile(
            icon: Icons.gavel_outlined,
            title: 'Terms of Use (EULA)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsPage()),
              );
            },
          ),

          const SizedBox(height: 32),

          // ── Danger Zone ──
          _buildSectionHeader('Danger Zone', isDestructive: true),
          _buildTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            isDestructive: true,
            onTap: _showDeleteAccountDialog,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  UI Helpers
  // ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDestructive ? Colors.red.withOpacity(0.7) : Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool showChevron = true,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final color = isDestructive ? Colors.red : Colors.white;
    final iconColor = isDestructive ? Colors.red : const Color(0xFFF29F05);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12))
            : null,
        trailing: showChevron
            ? Icon(Icons.chevron_right, color: Colors.grey[700], size: 20)
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
