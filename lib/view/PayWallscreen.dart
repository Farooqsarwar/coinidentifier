import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';

import '../main.dart';
import '../revenueCat.dart';
import 'Widgets/reusable.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _revenueCat = RevenueCatService();
  bool _isLoading = false;
  String? _selectedPackageId;
  List<Package> _packages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _revenueCat.fetchOfferings();

      setState(() {
        _packages = _revenueCat.getPackages();
        if (_packages.isNotEmpty) {
          final yearly = _revenueCat.getYearlyPackage();
          final lifetime = _revenueCat.getLifetimePackage();
          _selectedPackageId = yearly?.identifier ?? lifetime?.identifier ?? _packages.first.identifier;
        } else {
          _errorMessage = 'No products available. Please try again later.';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load products: $e';
      });
    }
  }

  Future<void> _purchase() async {
    if (_selectedPackageId == null || _packages.isEmpty) return;

    final package = _packages.firstWhere(
          (p) => p.identifier == _selectedPackageId,
      orElse: () => _packages.first,
    );

    setState(() => _isLoading = true);
    final result = await _revenueCat.purchasePackage(package);
    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success || result.isPremium ? const Color(0xFF13EC5B) : Colors.orange,
      ),
    );

    if (result.success || result.isPremium) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    final result = await _revenueCat.restorePurchases();
    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isPremium ? const Color(0xFF13EC5B) : Colors.orange,
      ),
    );

    if (result.isPremium) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: SafeArea(
        child: _isLoading && _packages.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF13EC5B)))
            : Center(
          // Constrained for Tablets/Desktop
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF13EC5B), Color(0xFF0FD850)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF13EC5B).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 10),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium, size: 50, color: Color(0xFF102216)),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Unlock Coinium Premium',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Get unlimited coin identifications and access to all features',
                    style: TextStyle(fontSize: 16, color: Color(0xFF92C9A4)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildFeaturesList(),
                  const SizedBox(height: 32),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.orange))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_packages.isNotEmpty) ...[
                    ..._packages.map((package) => _buildPackageOption(package)),
                  ] else if (_errorMessage == null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF193322),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.cloud_off, color: Color(0xFF92C9A4), size: 40),
                          SizedBox(height: 12),
                          Text(
                            'Unable to load subscription options.\nPlease check your connection.',
                            style: TextStyle(color: Color(0xFF92C9A4)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_packages.isEmpty)
                    ElevatedButton.icon(
                      onPressed: _loadPackages,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF193322),
                        foregroundColor: const Color(0xFF13EC5B),
                      ),
                    ),
                  if (_packages.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _purchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13EC5B),
                          foregroundColor: const Color(0xFF102216),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          disabledBackgroundColor: const Color(0xFF13EC5B).withValues(alpha: 0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF102216)),
                        )
                            : const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _restore,
                    child: const Text(
                      'Restore Purchases',
                      style: TextStyle(color: Color(0xFF92C9A4), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed:
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => const StaticTextScreen(
                              title: 'Terms of Use',
                              body: '''
• Coinium is provided "as is" without warranty.
• AI results are estimates and may be inaccurate.
Subscription Terms:
• Payment will be charged to your account at confirmation.
• Subscription automatically renews unless cancelled 24 hours before the end of the current period.
• You can manage subscriptions in your account settings.
''',
                            ),
                          ),
                        ),
                        child: const Text('Terms', style: TextStyle(color: Color(0xFF92C9A4), fontSize: 12)),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFF92C9A4))),
                      TextButton(
                        onPressed:
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => const StaticTextScreen(
                              title: 'Privacy Policy',
                              body: '''
Coinium stores your data locally on your device.
Images are only sent to the AI service when you request analysis.
We do not:
• Run background tracking
• Sell personal data
''',
                            ),
                          ),
                        ),
                        child: const Text('Privacy', style: TextStyle(color: Color(0xFF92C9A4), fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    const features = [
      ('Unlimited coin identifications', Icons.all_inclusive),
      ('Identify banknotes, medals & tokens', Icons.category),
      ('Save unlimited items to collection', Icons.collections_bookmark),
      ('Priority AI analysis', Icons.bolt),
      ('No ads', Icons.block),
    ];

    return Column(
      children:
      features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13EC5B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(feature.$2, color: const Color(0xFF13EC5B), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(feature.$1, style: const TextStyle(color: Colors.white, fontSize: 16))),
              const Icon(Icons.check_circle, color: Color(0xFF13EC5B), size: 20),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPackageOption(Package package) {
    final isSelected = _selectedPackageId == package.identifier;
    final product = package.storeProduct;
    final isBestValue = package.packageType == PackageType.annual;
    final isLifetime = package.packageType == PackageType.lifetime || package.identifier.toLowerCase().contains('lifetime');

    String? savings;
    if (package.packageType == PackageType.annual) {
      final monthly = _revenueCat.getMonthlyPackage();
      if (monthly != null) {
        final yearlyPrice = product.price;
        final monthlyPrice = monthly.storeProduct.price * 12;
        if (monthlyPrice > 0) {
          final savingsPercent = ((monthlyPrice - yearlyPrice) / monthlyPrice * 100).round();
          if (savingsPercent > 0) savings = 'Save $savingsPercent%';
        }
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPackageId = package.identifier),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF13EC5B).withValues(alpha: 0.1) : const Color(0xFF193322),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF13EC5B) : const Color(0xFF326744).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF13EC5B) : const Color(0xFF92C9A4),
                  width: 2,
                ),
              ),
              child:
              isSelected ? const Center(child: CircleAvatar(radius: 6, backgroundColor: Color(0xFF13EC5B))) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getPackageTitle(package),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13EC5B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(color: Color(0xFF102216), fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                      if (isLifetime) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                          child: const Text(
                            'FOREVER',
                            style: TextStyle(color: Color(0xFF102216), fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPackageDescription(package),
                    style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.priceString,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF13EC5B)),
                ),
                if (savings != null) Text(savings, style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPackageTitle(Package package) {
    final id = package.identifier.toLowerCase();
    if (id.contains('lifetime')) return 'Lifetime';
    if (id.contains('year') || id.contains('annual')) return 'Yearly';
    if (id.contains('month')) return 'Monthly';
    if (id.contains('week')) return 'Weekly';

    switch (package.packageType) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.weekly:
        return 'Weekly';
      default:
        return package.storeProduct.title;
    }
  }

  String _getPackageDescription(Package package) {
    final id = package.identifier.toLowerCase();
    if (id.contains('lifetime')) return 'One-time payment, forever';
    if (id.contains('year') || id.contains('annual')) return 'Billed annually, cancel anytime';
    if (id.contains('month')) return 'Billed monthly, cancel anytime';
    if (id.contains('week')) return 'Billed weekly, cancel anytime';

    switch (package.packageType) {
      case PackageType.monthly:
        return 'Billed monthly, cancel anytime';
      case PackageType.annual:
        return 'Billed annually, cancel anytime';
      case PackageType.lifetime:
        return 'One-time payment, forever';
      case PackageType.weekly:
        return 'Billed weekly, cancel anytime';
      default:
        return package.storeProduct.description;
    }
  }
}