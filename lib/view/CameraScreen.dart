import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'Anlyzingscreen.dart';

class CameraScanScreen extends StatefulWidget {
  final String initialType;
  const CameraScanScreen({super.key, this.initialType = 'coin'});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  late AnimationController _pulseController;
  String _scanType = 'coin';

  @override
  void initState() {
    super.initState();
    _scanType = widget.initialType.toLowerCase();
    _initializeCamera();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      _showError('No camera found');
      return;
    }

    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        final prefs = await SharedPreferences.getInstance();
        final quality = prefs.getString('cameraQuality') ?? 'high';
        final preset =
        {
          'low': ResolutionPreset.low,
          'medium': ResolutionPreset.medium,
          'high': ResolutionPreset.high,
          'max': ResolutionPreset.max,
        }[quality]!;
        _cameraController = CameraController(cameras[0], preset, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      } else {
        _showError('Camera permission denied');
      }
    } catch (e) {
      _showError('Error initializing camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile image = await _cameraController!.takePicture();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AnalyzingCoinScreen(imageFile: File(image.path), type: _scanType)),
      );
    } catch (e) {
      _showError('Error taking picture: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AnalyzingCoinScreen(imageFile: File(image.path), type: _scanType)),
        );
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      setState(() => _isFlashOn = !_isFlashOn);
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      _showError('Error toggling flash: $e');
    }
  }

  String get _scanTypeLabel {
    switch (_scanType) {
      case 'coin':
        return 'coin';
      case 'banknote':
        return 'banknote';
      case 'medal':
        return 'medal';
      case 'token':
        return 'token or artifact';
      default:
        return 'item';
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Responsive Scan Size
    final double scanSize = (min(size.width, size.height) * 0.75).clamp(200.0, 400.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            Center(child: CircularProgressIndicator(color: const Color(0xFF13EC5B))),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3))),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopButton(Icons.close_rounded, () => Navigator.pop(context)),
                      Row(
                        children: [
                          _buildTopButton(Icons.info_outline_rounded, _showInfoDialog),
                          const SizedBox(width: 12),
                          _buildTopButton(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, _toggleFlash),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildScanTypeSelector()),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder:
                              (_, __) => Container(
                            width: scanSize,
                            height: scanSize,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF13EC5B).withValues(alpha: 0.3 * _pulseController.value),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                _buildCornerBracket(top: 0, left: 0, rotation: 0),
                                _buildCornerBracket(top: 0, right: 0, rotation: 90),
                                _buildCornerBracket(bottom: 0, right: 0, rotation: 180),
                                _buildCornerBracket(bottom: 0, left: 0, rotation: 270),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Align the $_scanTypeLabel inside the frame',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF13EC5B), Color(0xFF0FD850)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBottomButton(Icons.photo_library_rounded, _pickFromGallery),
                        GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF102216), width: 4),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 36, color: Color(0xFF13EC5B)),
                          ),
                        ),
                        const SizedBox(width: 56),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(30)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScanTypeChip('coin', Icons.toll, 'Coin'),
            _buildScanTypeChip('banknote', Icons.payments, 'Banknote'),
            _buildScanTypeChip('medal', Icons.military_tech, 'Medal'),
            _buildScanTypeChip('token', Icons.category, 'Token'),
          ],
        ),
      ),
    );
  }

  Widget _buildScanTypeChip(String type, IconData icon, String label) {
    final bool selected = _scanType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        selected: selected,
        onSelected: (value) {
          if (value) setState(() => _scanType = type);
        },
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? const Color(0xFF102216) : Colors.white),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: selected ? const Color(0xFF102216) : Colors.white)),
          ],
        ),
        backgroundColor: Colors.transparent,
        selectedColor: const Color(0xFF13EC5B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? const Color(0xFF13EC5B) : Colors.white.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _buildTopButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
      child: IconButton(onPressed: onPressed, icon: Icon(icon, color: Colors.white), iconSize: 22),
    );
  }

  Widget _buildBottomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: IconButton(onPressed: onPressed, icon: Icon(icon), iconSize: 28, color: const Color(0xFF102216)),
    );
  }

  Widget _buildCornerBracket({double? top, double? bottom, double? left, double? right, required double rotation}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        backgroundColor: const Color(0xFF193322),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('How to scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          '1. Place the item on a flat surface\n'
              '2. Ensure good lighting\n'
              '3. Select what you are scanning\n'
              '4. Align it within the frame\n'
              '5. Keep the camera steady\n'
              '6. Tap the camera button',
          style: TextStyle(color: Color(0xFF92C9A4), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Color(0xFF13EC5B), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
