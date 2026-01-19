import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../revenueCat.dart';
import 'CameraScreen.dart';
import 'PayWallscreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _revenueCat = RevenueCatService();
  int scansLeft = 3;
  bool isPremium = false;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    await _revenueCat.refreshCustomerInfo();
    setState(() {
      scansLeft = prefs.getInt('scansLeft') ?? 3;
      isPremium = _revenueCat.isPremium;
    });
  }

  Future<void> _showPaywall() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PaywallScreen(), fullscreenDialog: true),
    );
    if (result == true) await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final scansText = isPremium ? 'Unlimited scans' : '$scansLeft scans left';
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: SafeArea(
        child: Center(
          // Max width constraint for wide screens
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.05),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('$_greeting, coin lover!', style: Theme.of(context).textTheme.headlineLarge),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF23482F), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield, size: 16),
                            const SizedBox(width: 6),
                            Text(scansText, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildPlanChip(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSubscriptionBanner(),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: GridView.count(
                      // ✅ GridView will scroll
                      physics: const BouncingScrollPhysics(), // or ClampingScrollPhysics()
                      crossAxisCount: isTablet ? 4 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildIdentifyCard(context, Icons.toll, 'Identify\nCoins', const Color(0xFF13EC5B), 'coin'),
                        _buildIdentifyCard(context, Icons.payments, 'Identify\nBanknotes', const Color(0xFF4E9F5A), 'banknote'),
                        _buildIdentifyCard(context, Icons.military_tech, 'Identify\nMedals', const Color(0xFFF0A961), 'medal'),
                        _buildIdentifyCard(context, Icons.category, 'Identify Tokens\n& artifacts', const Color(0xFF92C9A4), 'token'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanChip() {
    final color = isPremium ? const Color(0xFF13EC5B) : const Color(0xFF92C9A4);
    final icon = isPremium ? Icons.workspace_premium : Icons.lock_open;
    final text = isPremium ? 'Premium' : 'Free plan';

    return GestureDetector(
      onTap: isPremium ? null : _showPaywall,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF193322),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    const totalFree = 3;
    final used = (totalFree - scansLeft).clamp(0, totalFree);
    final progress = isPremium ? 1.0 : (totalFree == 0 ? 0.0 : used / totalFree);

    if (isPremium) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF13EC5B), Color(0xFF92C9A4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF13EC5B).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF102216).withValues(alpha: 0.95)),
                child: const Icon(Icons.workspace_premium, color: Color(0xFF13EC5B), size: 30),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium active',
                      style: TextStyle(color: Color(0xFF102216), fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Unlimited identifications and all features.',
                      style: TextStyle(color: Color(0xFF102216), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF23482F), Color(0xFF193322)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF13EC5B).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF13EC5B).withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.lock_open, color: Color(0xFF13EC5B), size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("You're on the Free plan", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Upgrade for unlimited scans.', style: TextStyle(color: Color(0xFF92C9A4), fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Free scans', style: TextStyle(fontSize: 12, color: Color(0xFF92C9A4))),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF13EC5B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$used / $totalFree', style: const TextStyle(fontSize: 12, color: Color(0xFF92C9A4))),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _showPaywall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13EC5B),
                  foregroundColor: const Color(0xFF102216),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifyCard(BuildContext context, IconData icon, String title, Color accentColor, String type) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CameraScanScreen(initialType: type))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF193322),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
