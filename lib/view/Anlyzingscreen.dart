import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../main.dart'; // for getPromptForType(...)
import '../services/config_service.dart'; // make sure this path is correct
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

  static const bgDark = Color(0xFF102216);
  static const gold = Color(0xFF13EC5B);

  String _statusText = 'Analyzing...';
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _statusText = 'Analyzing your ${_getItemName()}...';
    _analyzeItem();
  }

  String _getItemName() {
    switch (widget.type.toLowerCase()) {
      case 'coin':
        return 'coin';
      case 'banknote':
        return 'banknote';
      case 'medal':
        return 'medal';
      case 'token':
        return 'token';
      default:
        return 'item';
    }
  }

  IconData _getItemIconData() {
    switch (widget.type.toLowerCase()) {
      case 'coin':
        return Icons.toll;
      case 'banknote':
        return Icons.payments;
      case 'medal':
        return Icons.military_tech;
      case 'token':
        return Icons.category;
      default:
        return Icons.toll;
    }
  }

  Future<void> _analyzeItem() async {
    setState(() => _statusText = 'Uploading image...');

    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _statusText = 'Analyzing ${_getItemName()} details...');

    try {
      // Get key from your ConfigService
      final apiKey = ConfigService().getGeminiKey();

      debugPrint(
        '🔑 Gemini key loaded: ${apiKey.isNotEmpty ? '***${apiKey.substring(apiKey.length - 4)}' : 'EMPTY'}',
      );

      if (apiKey.isEmpty) {
        throw Exception(
          'Gemini API key is missing. Please check your ConfigService / settings.',
        );
      }

      // Use a valid Gemini multimodal model
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // or 'gemini-1.5-pro'
        apiKey: apiKey,
      );

      final imageBytes = await widget.imageFile.readAsBytes();
      final prompt = getPromptForType(widget.type);

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      debugPrint('🚀 Sending request to Gemini...');
      final response = await model.generateContent(content);
      debugPrint('✅ Gemini response received');

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
        _showErrorDialog('No analysis text returned from AI.');
      }
    } catch (e, st) {
      debugPrint('❌ Error analyzing: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showErrorDialog('Error analyzing: $e');
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: gold.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Analysis Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(color: Color(0xFF92C9A4)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back from analyzing screen
            },
            child: const Text(
              'Go Back',
              style: TextStyle(color: Color(0xFF92C9A4)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: bgDark,
            ),
            onPressed: () {
              Navigator.pop(context); // close dialog
              setState(() {
                _isAnalyzing = true;
                _statusText = 'Retrying...';
              });
              _analyzeItem();
            },
            child: const Text('Retry'),
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

  Widget _buildProgressDots() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final opacity =
            (1 - (value - 0.5).abs() * 2).clamp(0.3, 1.0); // double 0.3–1.0
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold.withValues(alpha: 0.1),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Analyzing ${_getItemName()[0].toUpperCase()}${_getItemName().substring(1)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: (size.width * 0.5).clamp(150.0, 300.0),
                        height: (size.width * 0.5).clamp(150.0, 300.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gold.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (_isAnalyzing)
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _controller,
                                builder: (_, child) => Transform.rotate(
                                  angle: _controller.value * 6.28318,
                                  child: child,
                                ),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: gold.withValues(alpha: 0.2),
                                      width: 4,
                                    ),
                                  ),
                                  child: CustomPaint(
                                    painter: _ArcPainter(color: gold),
                                  ),
                                ),
                              ),
                              Icon(_getItemIconData(), size: 32, color: gold),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This usually takes a few seconds',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF92C9A4),
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (_isAnalyzing) _buildProgressDots(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -1.5708, 1.5708, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}