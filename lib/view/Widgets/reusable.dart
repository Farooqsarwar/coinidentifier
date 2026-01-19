import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../SplashScreen.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF193322),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 12), child],
      ),
    );
  }
}

class HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const HelpItem({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF13EC5B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF13EC5B), size: 20),
      ),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF92C9A4)),
      onTap: onTap,
    );
  }
}
class StaticTextScreen extends StatelessWidget {
  final String title;
  final String body;

  const StaticTextScreen({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(body, style: const TextStyle(color: Color(0xFF92C9A4), height: 1.6, fontSize: 14)),
      ),
    );
  }
}
class Bullet extends StatelessWidget {
  final String label;
  final String text;
  const Bullet({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Color(0xFF92C9A4))),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  TextSpan(text: ' $text', style: const TextStyle(color: Color(0xFF92C9A4), height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor();

  @override
  State<BlinkingCursor> createState() => BlinkingCursorState();
}

class BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Opacity(
        opacity: ctrl.value,
        child: Container(
          width: 2,
          height: 20,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: SplashScreen.primaryGreen,
            borderRadius: BorderRadius.circular(1),
            boxShadow: [BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
