import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final String analysis;
  final String type;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.analysis,
    this.type = 'coin',
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isFavorite = false;

  // --- THEME CONSTANTS (Your Original Colors) ---
  static const Color bgColor = Color(0xFF102216);
  static const Color cardColor = Color(0xFF1C3A27); // Slightly lighter for cards
  static const Color textColor = Color(0xFF92C9A4);
  static const Color highlightColor = Color(0xFF13EC5B); // Your Gold/Neon Green

  @override
  void initState() {
    super.initState();
    // Check if already favorites (optional implementation)
  }

  Future<void> _saveToCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];

    final item = {
      'type': widget.type,
      'analysis': widget.analysis,
      'imagePath': widget.imageFile.path,
      'favorite': _isFavorite,
      'savedAt': DateTime.now().toIso8601String(),
    };
    list.add(jsonEncode(item));
    await prefs.setStringList('collection', list);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Saved to Collection',
          style: TextStyle(color: bgColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: highlightColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- WIDGETS FOR NEW DESIGN ---

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(Icons.more_horiz, color: textColor),
        ],
      ),
    );
  }

  // Parses your AI text and wraps it in the new Card style
  Widget _buildAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormattedContent(widget.analysis),
        ],
      ),
    );
  }

  // --- TEXT PARSING LOGIC ---
  Widget _buildFormattedContent(String rawText) {
    List<Widget> children = [];
    List<String> lines = rawText.split('\n');

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 12));
        continue;
      }

      // Check for Headers (##)
      if (line.startsWith('##')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.replaceAll('#', '').trim(),
              style: const TextStyle(
                color: Colors.white, // White headers like screenshots
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      // Check for Bullet points
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: highlightColor, fontSize: 16)),
                Expanded(child: _buildRichTextLine(line.substring(2))),
              ],
            ),
          ),
        );
      }
      // Standard text
      else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildRichTextLine(line),
          ),
        );
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildRichTextLine(String text) {
    List<InlineSpan> spans = [];
    List<String> parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Normal text
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
            text: parts[i],
            style: const TextStyle(color: textColor, fontSize: 15, height: 1.5),
          ));
        }
      } else {
        // Bold text (Highlighted)
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
            text: parts[i],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5
            ),
          ));
        }
      }
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. SCROLLABLE CONTENT
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100), // Space for button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60), // SafeArea top spacing

                // --- TOP NAVIGATION ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      ),
                      Expanded(
                        child: Text(
                          "${widget.type[0].toUpperCase()}${widget.type.substring(1)} Details",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {}, // Optional: Menu action
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- MAIN IMAGE WITH GLOW (Like Image 1/6) ---
                Center(
                  child: Container(
                    height: 260,
                    width: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: highlightColor.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- CONTENT CONTAINER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- STATS ROW (Like Image 4/6) ---
                      // Note: Since we don't have exact parsed JSON, we use static labels
                      // referencing that the analysis text below contains the data.
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white.withOpacity(0.1)),
                            bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem("Type", widget.type.toUpperCase()),
                            Container(width: 1, height: 30, color: Colors.white24),
                            _buildStatItem("Status", "IDENTIFIED"),
                            Container(width: 1, height: 30, color: Colors.white24),
                            _buildStatItem("Origin", "AI SCAN"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- ANALYSIS CARD (Like Image 1) ---
                      _buildSectionHeader("Analysis Report"),
                      _buildAnalysisCard(),

                      const SizedBox(height: 20),

                      // --- PLACEHOLDER FOR VALUE (Like Image 5) ---
                      // Since AI output is text, we guide user to read it
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2F20), // Darker goldish tint
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: highlightColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on_outlined, color: highlightColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Check the description above for estimated value and grading details.",
                                style: TextStyle(color: textColor, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. BOTTOM FLOATING BUTTON (Like Image 1 & 3)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withOpacity(0.0),
                    bgColor.withOpacity(0.9),
                    bgColor,
                  ],
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: _saveToCollection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlightColor,
                  foregroundColor: bgColor, // Text color
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: highlightColor.withOpacity(0.4),
                ),
                icon: const Icon(Icons.add_circle_outline, weight: 600),
                label: const Text(
                  'Add to Collection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}