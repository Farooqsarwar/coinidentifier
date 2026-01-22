import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../main.dart';
import '../services/config_service.dart';
import 'Resultscreen.dart';

class AnalyzingCoinScreen extends StatefulWidget {
  final File imageFile;
  final String type;

  const AnalyzingCoinScreen({
    super.key,
    required this.imageFile,
    this.type = 'coin',
  });

  @override
  State<AnalyzingCoinScreen> createState() => _AnalyzingCoinScreenState();
}

class _AnalyzingCoinScreenState extends State<AnalyzingCoinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Theme Constants
  static const bgDark = Color(0xFF102216);
  static const gold = Color(0xFF13EC5B);

  String _statusText = 'Initializing...';
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _statusText = 'Scanning ${_getItemName()} features...';
    _analyzeItem();
  }

  String _getItemName() {
    // Simple helper to clean up type names
    return widget.type.toLowerCase();
  }

  Future<void> _analyzeItem() async {
    // Delay to show the UI animation (UX)
    await Future.delayed(const Duration(milliseconds: 800));
    if(!mounted) return;
    setState(() => _statusText = 'Identifying details...');

    try {
      final apiKey = ConfigService().getGeminiKey();

      if (apiKey.isEmpty) {
        throw Exception('API Key missing');
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final imageBytes = await widget.imageFile.readAsBytes();
      // Ensure your getPromptForType asks for headers like "## Supply Analysis"
      // to match the parser in ResultScreen.
      final prompt = getPromptForType(widget.type);

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await model.generateContent(content);

      if (!mounted) return;

      setState(() => _isAnalyzing = false);

      final text = response.text?.trim();
      if (text != null && text.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imageFile: widget.imageFile,
              analysis: text,
              type: widget.type,
            ),
          ),
        );
      } else {
        _showErrorDialog('AI returned empty response.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: gold.withOpacity(0.3))),
        title: const Text('Analysis Failed', style: TextStyle(color: Colors.white)),
        content: Text(error, style: const TextStyle(color: Color(0xFF92C9A4))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry', style: TextStyle(color: gold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Analyzing...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the close button
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular Image with Scanning Animation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: gold.withOpacity(0.2),
                                blurRadius: 40,
                                spreadRadius: 5,
                              )
                            ]
                        ),
                      ),
                      // Rotating Border
                      SizedBox(
                        width: 210,
                        height: 210,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(gold),
                          strokeWidth: 2,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      // Actual Image
                      Container(
                        width: 200,
                        height: 200,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "This may take a moment",
                    style: TextStyle(
                      color: Color(0xFF92C9A4),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}