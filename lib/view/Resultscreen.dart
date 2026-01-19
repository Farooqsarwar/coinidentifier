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

  // Theme Constants
  static const Color bgColor = Color(0xFF102216);
  static const Color cardColor = Color(0xFF23482F);
  static const Color textColor = Color(0xFF92C9A4);
  static const Color highlightColor = Color(0xFF13EC5B);

  String get _title {
    switch (widget.type.toLowerCase()) {
      case 'coin':
        return 'Coin Details';
      case 'banknote':
        return 'Banknote Details';
      case 'medal':
        return 'Medal Details';
      case 'token':
        return 'Token / Artifact';
      default:
        return 'Item Details';
    }
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

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.black, size: 20),
            SizedBox(width: 12),
            Text('Saved to My Collection!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: highlightColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- MANUAL TEXT PARSING LOGIC (No Packages) ---

  Widget _buildFormattedContent(String rawText) {
    List<Widget> children = [];
    List<String> lines = rawText.split('\n');

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 12));
        continue;
      }

      if (line.startsWith('##')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.replaceAll('#', '').trim(),
              style: const TextStyle(color: highlightColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: highlightColor, fontSize: 16, height: 1.5)),
                Expanded(child: _buildRichTextLine(line.substring(2))),
              ],
            ),
          ),
        );
      } else {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 4), child: _buildRichTextLine(line)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildRichTextLine(String text) {
    List<InlineSpan> spans = [];
    List<String> parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
            text: parts[i],
            style: const TextStyle(color: textColor, fontSize: 15, height: 1.5),
          ));
        }
      } else {
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
            text: parts[i],
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
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
      // 1. SIMPLE APP BAR
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // 2. STACK FOR FLOATING BUTTON
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image displayed in the body
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: FileImage(widget.imageFile),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                ),

                const SizedBox(height: 24),

                // Analysis Result Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: _buildFormattedContent(widget.analysis),
                ),

                // Extra space for bottom button
                const SizedBox(height: 100),
              ],
            ),
          ),

          // 3. FLOATING BOTTOM BUTTON
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withOpacity(0.0),
                    bgColor,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveToCollection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: highlightColor,
                      foregroundColor: bgColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save to My Collection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}