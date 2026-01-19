
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'Widgets/reusable.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: '1. Detecting Counterfeit Coins',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Start with these fundamentals:',
                      style: TextStyle(color: Color(0xFF92C9A4), height: 1.5),
                    ),
                    SizedBox(height: 12),
                    Bullet(label: 'Visual inspection:', text: 'Look for sharp details and clean edges.'),
                    Bullet(label: 'Weight & size:', text: 'Use a digital scale and calipers.'),
                    Bullet(label: 'Magnet test:', text: 'Most precious-metal coins are not magnetic.'),
                    Bullet(label: 'Edge & sound:', text: 'Check for clean, even reeding.'),
                  ],
                ),
              ),
              SectionCard(
                title: '2. The 1909 Lincoln Penny',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'The first regular U.S. coin to feature a real historical figure.',
                      style: TextStyle(color: Color(0xFF92C9A4), height: 1.5),
                    ),
                    SizedBox(height: 12),
                    Bullet(label: 'Designer:', text: 'Victor David Brenner created the design.'),
                    Bullet(label: 'Key variety:', text: '1909-S VDB is highly sought after.'),
                  ],
                ),
              ),
              SectionCard(
                title: '3. Silver vs. Gold Coins',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Bullet(label: 'Silver coins:', text: 'More affordable, ideal for beginners.'),
                    Bullet(label: 'Gold coins:', text: 'High value in a small space.'),
                    Bullet(label: 'Balanced approach:', text: 'Many collectors hold both metals.'),
                  ],
                ),
              ),
              SectionCard(
                title: '4. How Coin Grading Works',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'The standard U.S. scale runs from Poor (P-1) to Mint State (MS-70).',
                      style: TextStyle(color: Color(0xFF92C9A4), height: 1.5),
                    ),
                    SizedBox(height: 12),
                    Bullet(label: 'Circulated grades:', text: 'Poor to About Uncirculated.'),
                    Bullet(label: 'Uncirculated:', text: 'MS-60 to MS-70, no wear from circulation.'),
                  ],
                ),
              ),
              SectionCard(
                title: '5. Rare Coins in Everyday Change',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Bullet(label: 'Wheat cents:', text: 'Older Lincoln cents (1909-1958).'),
                    Bullet(label: 'Pre-1965 silver:', text: 'Dimes, quarters, halves contain 90% silver.'),
                    Bullet(label: 'Error coins:', text: 'Off-center strikes, doubled designs.'),
                  ],
                ),
              ),
              SectionCard(
                title: '6. Understanding Mint Marks',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Bullet(label: 'Common U.S. marks:', text: 'P = Philadelphia, D = Denver, S = San Francisco.'),
                    Bullet(label: 'Rarity by mint:', text: 'Some mints produced fewer coins in certain years.'),
                  ],
                ),
              ),
              SectionCard(
                title: '7. Building a Collection',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bullet(label: 'Choose a focus:', text: 'Pick an era, country, or denomination.'),
                    Bullet(label: 'Quality over quantity:', text: 'Well-chosen coins are more satisfying.'),
                    Bullet(label: 'Protect your coins:', text: 'Use proper holders and avoid cleaning.'),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}


