import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../revenueCat.dart';
import 'PayWallscreen.dart';
import 'Widgets/reusable.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _revenueCat = RevenueCatService();
  bool isPremium = false;
  String displayName = 'Collector';
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await _revenueCat.refreshCustomerInfo();

    setState(() {
      isPremium = _revenueCat.isPremium;
      displayName = prefs.getString('displayName') ?? 'Collector';
      _nameCtrl.text = displayName;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayName', displayName.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: Color(0xFF13EC5B)));
  }

  Future<void> _showPaywall() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PaywallScreen(), fullscreenDialog: true),
    );
    if (result == true) await _load();
  }

  Future<void> _restorePurchases() async {
    final result = await _revenueCat.restorePurchases();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isPremium ? const Color(0xFF13EC5B) : Colors.orange,
      ),
    );

    if (result.isPremium) await _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Section
              SectionCard(
                title: 'Profile',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF13EC5B),
                      child: Text(
                        (displayName.isNotEmpty ? displayName[0] : 'C').toUpperCase(),
                        style: const TextStyle(color: Color(0xFF102216), fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          labelStyle: const TextStyle(color: Color(0xFF92C9A4)),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF326744)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF13EC5B)),
                          ),
                        ),
                        onChanged: (v) => displayName = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.save, color: Color(0xFF13EC5B)), onPressed: _saveProfile),
                  ],
                ),
              ),

              // Subscription Section
              SectionCard(
                title: 'Subscription',
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPremium ? const Color(0xFF13EC5B).withValues(alpha: 0.1) : const Color(0xFF23482F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPremium ? const Color(0xFF13EC5B) : const Color(0xFF326744).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(isPremium ? Icons.workspace_premium : Icons.lock_open, color: const Color(0xFF13EC5B), size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPremium ? 'Premium Active' : 'Free Plan',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isPremium ? 'Unlimited identifications' : '3 free identifications',
                                  style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (!isPremium)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showPaywall,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13EC5B),
                                foregroundColor: const Color(0xFF102216),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        if (!isPremium) const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _restorePurchases,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF13EC5B),
                              side: const BorderSide(color: Color(0xFF13EC5B)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    if (isPremium && _revenueCat.customerInfo != null) ...[const SizedBox(height: 16), _buildSubscriptionInfo()],
                  ],
                ),
              ),

              // Help & Legal Section
              SectionCard(
                title: 'Help & Legal',
                child: Column(
                  children: [
                    HelpItem(
                      icon: Icons.help_outline,
                      text: 'FAQ',
                      onTap:
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const StaticTextScreen(
                            title: 'FAQ',
                            body: '''
Q: How do I scan a coin or banknote?
A: Open the camera from Home, align the item in the frame, then tap the shutter button.
Q: How many free scans do I get?
A: You have 3 free scans. Upgrade to Premium for unlimited scans.
Q: How do I restore my purchase?
A: Go to Profile > Subscription > Restore to restore previous purchases.
Q: What types of items can I identify?
A: You can identify coins, banknotes, medals, tokens, and artifacts.
Q: Where is my collection stored?
A: All items are stored locally on your device.
Q: How accurate is the AI identification?
A: The AI provides detailed analysis, but we recommend verifying important valuations with professional numismatists.
''',
                          ),
                        ),
                      ),
                    ),
                    HelpItem(
                      icon: Icons.privacy_tip_outlined,
                      text: 'Privacy Policy',
                      onTap:
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const StaticTextScreen(
                            title: 'Privacy Policy',
                            body: '''
Privacy Policy for Coinium
Last updated: 2024
Your privacy is important to us. This policy explains how we handle your data.
DATA COLLECTION:
• We store your collection data locally on your device
• Images are only sent to Google's Gemini AI when you request analysis
• We do not collect personal information
DATA USAGE:
• Scan images are processed by AI for identification
• Collection data remains on your device
• No data is sold to third parties
DATA STORAGE:
• All data is stored locally using secure device storage
• Subscription status is managed by RevenueCat
THIRD-PARTY SERVICES:
• Google Gemini AI for image analysis
• RevenueCat for subscription management
• Apple App Store / Google Play for payments
CONTACT:
For privacy questions, contact us at support@coinium.app
''',
                          ),
                        ),
                      ),
                    ),
                    HelpItem(
                      icon: Icons.gavel_outlined,
                      text: 'Terms of Use',
                      onTap:
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const StaticTextScreen(
                            title: 'Terms of Use',
                            body: '''
Terms of Use for Coinium
Last updated: 2024
By using Coinium, you agree to these terms.
SERVICE DESCRIPTION:
• Coinium provides AI-powered coin and collectible identification
• Results are estimates and may not be 100% accurate
• Do not rely solely on the app for financial decisions
USER RESPONSIBILITIES:
• Use the app lawfully and responsibly
• Do not attempt to reverse engineer the app
• Report any bugs or issues to our support team
SUBSCRIPTION TERMS:
• Payment will be charged to your App Store or Google Play account
• Subscriptions automatically renew unless cancelled 24 hours before the end of the current period
• You can manage and cancel subscriptions in your account settings
DISCLAIMERS:
• The app is provided "as is" without warranty
• We are not responsible for decisions made based on AI analysis
• Always verify valuations with professional numismatists
CHANGES TO TERMS:
We may update these terms at any time. Continued use constitutes acceptance.
CONTACT:
For questions, contact support@coinium.app
''',
                          ),
                        ),
                      ),
                    ),
                    HelpItem(
                      icon: Icons.mail_outline,
                      text: 'Contact Support',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email: support@coinium.app'), backgroundColor: Color(0xFF13EC5B)),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // App Info
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    const Text('Coinium', style: TextStyle(color: Color(0xFF92C9A4), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(color: const Color(0xFF92C9A4).withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo() {
    final customerInfo = _revenueCat.customerInfo;
    if (customerInfo == null) return const SizedBox.shrink();

    // Check both possible entitlement names
    var entitlement = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId];
    entitlement ??= customerInfo.entitlements.active.values.firstOrNull;

    if (entitlement == null) return const SizedBox.shrink();

    String statusText = 'Active';
    IconData statusIcon = Icons.check_circle;
    Color statusColor = const Color(0xFF13EC5B);

    if (entitlement.expirationDate != null) {
      final expiry = DateTime.parse(entitlement.expirationDate!);
      final daysLeft = expiry.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        statusText = 'Renews in $daysLeft days';
        statusIcon = Icons.autorenew;
      } else if (daysLeft == 0) {
        statusText = 'Renews today';
        statusIcon = Icons.autorenew;
      } else {
        statusText = 'Expires soon';
        statusIcon = Icons.warning;
        statusColor = Colors.orange;
      }
    } else {
      statusText = 'Lifetime access';
      statusIcon = Icons.all_inclusive;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF23482F), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 8),
          Expanded(child: Text(statusText, style: TextStyle(color: statusColor))),
        ],
      ),
    );
  }
}
