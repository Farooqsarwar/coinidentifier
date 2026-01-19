import 'dart:ui';

import 'package:coinidentifier/revenueCat.dart';
import 'package:coinidentifier/view/CameraScreen.dart';
import 'package:coinidentifier/view/CollectionScreen.dart';
import 'package:coinidentifier/view/LearnScreen.dart';
import 'package:coinidentifier/view/PayWallscreen.dart';
import 'package:coinidentifier/view/ProfileScreen.dart';
import 'package:coinidentifier/view/home%20screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final _revenueCat = RevenueCatService();

  final List<Widget> _screens = const [
    HomeScreen(),
    LearnScreen(),
    MyCollectionScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomAppBar(
            color: const Color(0xFF193322).withValues(alpha: 0.8),
            elevation: 0,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [_buildNavItem(Icons.home_rounded, 'Home', 0), _buildNavItem(Icons.menu_book_rounded, 'Learn', 1)],
                      ),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(Icons.collections_bookmark_outlined, 'Collection', 2),
                          _buildNavItem(Icons.person_outline_rounded, 'Profile', 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF13EC5B), Color(0xFF0FD850)]),
          boxShadow: [
            BoxShadow(color: const Color(0xFF13EC5B).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _onScanPressed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.camera_alt_rounded, size: 28, color: Color(0xFF102216)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Future<void> _onScanPressed() async {
    final prefs = await SharedPreferences.getInstance();
    await _revenueCat.refreshCustomerInfo();
    final isPremium = _revenueCat.isPremium;
    var scansLeft = prefs.getInt('scansLeft') ?? 3;

    if (!isPremium && scansLeft <= 0) {
      _showPaywall();
      return;
    }

    if (!isPremium) {
      scansLeft = scansLeft - 1;
      await prefs.setInt('scansLeft', scansLeft);
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraScanScreen(initialType: 'coin')));
  }

  void _showPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaywallScreen(), fullscreenDialog: true),
    ).then((result) {
      if (result == true) setState(() {});
    });
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isActive ? const Color(0xFF13EC5B) : const Color(0xFF92C9A4)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF13EC5B) : const Color(0xFF92C9A4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
