
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ============================================================================
// RevenueCat Configuration
// ============================================================================

class RevenueCatConfig {
  // Your RevenueCat API keys
  static const String appleApiKey = 'test_EnaRoMtDRgYGpeUsbzjEBAqxBlG';
  static const String googleApiKey = 'test_EnaRoMtDRgYGpeUsbzjEBAqxBlG';

  // Entitlement ID from RevenueCat dashboard
  static const String premiumEntitlementId = 'Coin Identifier Premium';

  // Product IDs
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';
}

// ============================================================================
// RevenueCat Service
// ============================================================================

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;
  bool _isPremium = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  bool get isPremium => _isPremium;
  bool get isInitialized => _isInitialized;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;

  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      String apiKey;
      if (Platform.isIOS) {
        apiKey = RevenueCatConfig.appleApiKey;
      } else if (Platform.isAndroid) {
        apiKey = RevenueCatConfig.googleApiKey;
      } else {
        debugPrint('RevenueCat: Unsupported platform');
        await _loadLocalPremiumStatus();
        return;
      }

      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey));

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      await refreshCustomerInfo();
      await fetchOfferings();

      _isInitialized = true;
      debugPrint('RevenueCat initialized successfully');
    } catch (e) {
      debugPrint('Error initializing RevenueCat: $e');
      await _loadLocalPremiumStatus();
    }
  }

  /// Refresh customer info from RevenueCat
  Future<void> refreshCustomerInfo() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(_customerInfo!);
    } catch (e) {
      debugPrint('Error fetching customer info: $e');
      await _loadLocalPremiumStatus();
    }
  }

  /// Fetch available offerings/products
  Future<void> fetchOfferings() async {
    try {
      _offerings = await Purchases.getOfferings();
      debugPrint('Offerings fetched: ${_offerings?.current?.identifier}');
      if (_offerings?.current != null) {
        debugPrint('Available packages: ${_offerings!.current!.availablePackages.length}');
        for (var package in _offerings!.current!.availablePackages) {
          debugPrint('  - ${package.identifier}: ${package.storeProduct.priceString}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
    }
  }

  /// Update premium status based on customer info
  void _updatePremiumStatus(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;

    // Check for our specific entitlement
    final entitlement = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId];
    _isPremium = entitlement?.isActive ?? false;

    // Also check if ANY entitlement is active (fallback)
    if (!_isPremium && customerInfo.entitlements.active.isNotEmpty) {
      _isPremium = true;
      debugPrint('Premium activated via active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
    }

    _saveLocalPremiumStatus(_isPremium);

    debugPrint('Premium status updated: $_isPremium');
    debugPrint('All entitlements: ${customerInfo.entitlements.all.keys.toList()}');
    debugPrint('Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
  }

  Future<void> _loadLocalPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('isPremium') ?? false;
  }

  Future<void> _saveLocalPremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', isPremium);
  }

  /// Purchase a package
  /// FIXED: Renamed return type to AppPurchaseResult to avoid collision
  Future<AppPurchaseResult> purchasePackage(Package package) async {
    try {
      debugPrint('Starting purchase for package: ${package.identifier}');

      // FIXED: Purchases.purchasePackage returns CustomerInfo
      PurchaseResult customerInfo = await Purchases.purchasePackage(package);

      _updatePremiumStatus(customerInfo as CustomerInfo);

      return AppPurchaseResult(
        success: _isPremium,
        isPremium: _isPremium,
        message: _isPremium ? 'Purchase successful! Welcome to Premium.' : 'Purchase completed.',
      );
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('Purchase error code: $errorCode');
      debugPrint('Purchase error message: ${e.message}');

      String message;

      switch (errorCode) {
        case PurchasesErrorCode.purchaseCancelledError:
          message = 'Purchase was cancelled';
          break;
        case PurchasesErrorCode.purchaseNotAllowedError:
          message = 'Purchase not allowed on this device';
          break;
        case PurchasesErrorCode.purchaseInvalidError:
          message = 'Invalid purchase';
          break;
        case PurchasesErrorCode.productNotAvailableForPurchaseError:
          message = 'Product not available for purchase';
          break;
        case PurchasesErrorCode.productAlreadyPurchasedError:
          message = 'Product already purchased. Try restoring purchases.';
          await refreshCustomerInfo();
          break;
        case PurchasesErrorCode.networkError:
          message = 'Network error. Please check your connection.';
          break;
        case PurchasesErrorCode.receiptAlreadyInUseError:
          message = 'Receipt already in use by another user';
          break;
        case PurchasesErrorCode.paymentPendingError:
          message = 'Payment is pending. Please complete the transaction.';
          break;
        case PurchasesErrorCode.storeProblemError:
          message = 'There was a problem with the store. Please try again.';
          break;
        default:
          message = e.message ?? 'An error occurred during purchase';
      }

      return AppPurchaseResult(
        success: false,
        isPremium: _isPremium,
        message: message,
      );
    } catch (e) {
      debugPrint('Unexpected purchase error: $e');
      await refreshCustomerInfo();

      return AppPurchaseResult(
        success: _isPremium,
        isPremium: _isPremium,
        message: _isPremium ? 'Purchase successful!' : 'An unexpected error occurred.',
      );
    }
  }

  /// Restore purchases
  /// FIXED: Renamed return type to AppRestoreResult
  Future<AppRestoreResult> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);

      if (_isPremium) {
        return AppRestoreResult(
          success: true,
          isPremium: true,
          message: 'Premium restored successfully!',
        );
      } else {
        return AppRestoreResult(
          success: true,
          isPremium: false,
          message: 'No previous purchases found',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Restore error: ${e.message}');
      return AppRestoreResult(
        success: false,
        isPremium: _isPremium,
        message: 'Failed to restore purchases: ${e.message}',
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      return AppRestoreResult(
        success: false,
        isPremium: _isPremium,
        message: 'Failed to restore purchases',
      );
    }
  }

  /// Login user
  Future<void> login(String userId) async {
    try {
      final result = await Purchases.logIn(userId);
      _updatePremiumStatus(result.customerInfo);
      debugPrint('User logged in: $userId');
    } catch (e) {
      debugPrint('Login error: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final customerInfo = await Purchases.logOut();
      _updatePremiumStatus(customerInfo);
      debugPrint('User logged out');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  List<Package> getPackages() {
    return _offerings?.current?.availablePackages ?? [];
  }

  Package? getMonthlyPackage() => _offerings?.current?.monthly;
  Package? getYearlyPackage() => _offerings?.current?.annual;
  Package? getLifetimePackage() => _offerings?.current?.lifetime;

  bool hasOfferings() {
    return _offerings?.current != null && _offerings!.current!.availablePackages.isNotEmpty;
  }
}

/// Custom result class for purchases (Renamed to avoid collision)
class AppPurchaseResult {
  final bool success;
  final bool isPremium;
  final String message;

  AppPurchaseResult({
    required this.success,
    required this.isPremium,
    required this.message,
  });
}

/// Custom result class for restore (Renamed to avoid collision)
class AppRestoreResult {
  final bool success;
  final bool isPremium;
  final String message;

  AppRestoreResult({
    required this.success,
    required this.isPremium,
    required this.message,
  });
}

// ============================================================================
// Main App Entry Point
// ============================================================================

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error getting cameras: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  prefs.setInt('scansLeft', prefs.getInt('scansLeft') ?? 3);
  prefs.setBool('isPremium', prefs.getBool('isPremium') ?? false);
  prefs.setStringList('collection', prefs.getStringList('collection') ?? []);
  prefs.setString('currency', prefs.getString('currency') ?? 'USD');
  prefs.setString('cameraQuality', prefs.getString('cameraQuality') ?? 'high');
  prefs.setDouble('metal_gold', prefs.getDouble('metal_gold') ?? 2400.0);
  prefs.setDouble('metal_silver', prefs.getDouble('metal_silver') ?? 30.0);
  prefs.setDouble('metal_platinum', prefs.getDouble('metal_platinum') ?? 1100.0);
  prefs.setString('displayName', prefs.getString('displayName') ?? 'Collector');

  await RevenueCatService().initialize();

  runApp(const CoiniumApp());
}

class CoiniumApp extends StatelessWidget {
  const CoiniumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coinium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF13EC5B),
        scaffoldBackgroundColor: const Color(0xFF102216),
        fontFamily: 'Manrope',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF13EC5B),
          secondary: Color(0xFF92C9A4),
          surface: Color(0xFF193322),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// Prompts
// ============================================================================

String getPromptForType(String type) {
  switch (type.toLowerCase()) {
    case 'coin':
      return '''
Analyze this coin image and provide detailed information:

**Name**: (Full name of the coin)
**Country**: (Country of origin)
**Year**: (Year minted, if visible)
**Denomination**: (Face value)
**Metal/Composition**: (If identifiable)
**Obverse/Reverse details**: (Key features, legends)
**Mint mark**: (If visible)
**Notes**: (Varieties, errors, historical context)
''';

    case 'banknote':
      return '''
Analyze this banknote image and provide details:

**Name**: (Type of banknote)
**Country**: (Issuing country)
**Year/Series**: (Year or series)
**Denomination**: (Face value)
**Security features**: (Watermark, microprinting, security thread)
**Obverse/Reverse details**: (Portraits, buildings, scenery)
**Notes**: (Varieties, signatures, serial ranges)
''';

    case 'medal':
      return '''
Analyze this medal image and provide details:

**Name**: (Name of the medal)
**Type**: (Military/Civilian/Sports/Commemorative/etc.)
**Country/Issuer**: (Organization or government)
**Year**: (Year of issue)
**Design details**: (Obverse/Reverse)
**Ribbon/Attachment**: (If visible)
**Notes**: (Award criteria, variants)
''';

    case 'token':
      return '''
Analyze this token or artifact image:

**Name/Type**: (Transit token, gaming token, commemorative, artifact)
**Origin**: (Country/region)
**Era/Period**: (Approximate date)
**Material**: (Metal, alloy, other)
**Design details**: (Obverse/Reverse)
**Notes**: (Usage, issuer, known sets)
''';

    default:
      return getPromptForType('coin');
  }
}

// ============================================================================
// Splash Screen
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const primaryGreen = Color(0xFF13EC5B);
  static const bgDark = Color(0xFF102216);
  static const lightGreen = Color(0xFF92C9A4);
  static const darkSurface = Color(0xFF193322);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController mainCtrl;
  late final AnimationController shimmerCtrl;
  late final AnimationController pulseCtrl;
  late final AnimationController progressCtrl;
  late final AnimationController particleCtrl;

  late final Animation<double> fade;
  late final Animation<double> scale;
  late final Animation<double> slide;
  late final Animation<double> taglineFade;
  late final Animation<double> taglineSlide;
  late final Animation<double> pulse;
  late final Animation<double> progress;

  final rnd = Random();
  late final List<_Particle> particles;

  @override
  void initState() {
    super.initState();

    mainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
    particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    fade = CurvedAnimation(parent: mainCtrl, curve: const Interval(0, .5));
    scale = CurvedAnimation(parent: mainCtrl, curve: const Interval(0, .6, curve: Curves.elasticOut));
    slide = Tween(begin: 50.0, end: 0.0).animate(mainCtrl);
    taglineFade = CurvedAnimation(parent: mainCtrl, curve: const Interval(.4, .8));
    taglineSlide = Tween(begin: 30.0, end: 0.0).animate(mainCtrl);
    pulse = Tween(begin: 1.0, end: 1.1).animate(pulseCtrl);
    progress = CurvedAnimation(parent: progressCtrl, curve: Curves.easeInOut);

    particles = List.generate(
      20,
          (_) => _Particle(
        rnd.nextDouble(),
        rnd.nextDouble(),
        rnd.nextDouble() * 8 + 4,
        rnd.nextDouble() * .3 + .1,
        rnd.nextDouble() * .5 + .2,
      ),
    );

    mainCtrl.forward();
    progressCtrl.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, a, __) => const MainNavigationScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .1), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    mainCtrl.dispose();
    shimmerCtrl.dispose();
    pulseCtrl.dispose();
    progressCtrl.dispose();
    particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SplashScreen.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: mainCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5 + mainCtrl.value * 0.5,
                  colors: [SplashScreen.darkSurface, SplashScreen.bgDark, Colors.black],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: mainCtrl,
            builder: (_, __) => CustomPaint(painter: _CirclesPainter(mainCtrl.value)),
          ),
          AnimatedBuilder(
            animation: shimmerCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + shimmerCtrl.value * 2, -1),
                  end: Alignment(1 + shimmerCtrl.value * 2, 1),
                  colors: [
                    SplashScreen.primaryGreen.withValues(alpha: 0.03),
                    Colors.transparent,
                    SplashScreen.primaryGreen.withValues(alpha: 0.05),
                    Colors.transparent,
                    SplashScreen.lightGreen.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.7)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: particleCtrl,
            builder: (_, __) => CustomPaint(painter: _ParticlePainter(particles, particleCtrl.value)),
          ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([mainCtrl, pulseCtrl, shimmerCtrl]),
              builder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: pulse.value,
                    child: Opacity(
                      opacity: fade.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [SplashScreen.primaryGreen, Color(0xFF0FD850)],
                          ),
                          boxShadow: [
                            BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 10),
                            BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.3), blurRadius: 80, spreadRadius: 20),
                          ],
                        ),
                        child: const Icon(Icons.toll, color: Color(0xFF102216), size: 60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  Transform.translate(
                    offset: Offset(0, slide.value),
                    child: Opacity(
                      opacity: fade.value,
                      child: Transform.scale(
                        scale: scale.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment(-2 + shimmerCtrl.value * 4, 0),
                            end: Alignment(0 + shimmerCtrl.value * 4, 0),
                            colors: const [Colors.white, SplashScreen.primaryGreen, Colors.white],
                          ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Coinium',
                            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Transform.translate(
                    offset: Offset(0, taglineSlide.value),
                    child: Opacity(opacity: taglineFade.value, child: const _Typewriter()),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 48,
            right: 48,
            child: AnimatedBuilder(
              animation: Listenable.merge([progressCtrl, shimmerCtrl]),
              builder: (_, __) => Column(
                children: [
                  Text(
                    '${(progress.value * 100).toInt()}%',
                    style: TextStyle(
                      color: SplashScreen.lightGreen.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: SplashScreen.darkSurface.withValues(alpha: 0.5),
                      border: Border.all(color: SplashScreen.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: progress.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(colors: [SplashScreen.primaryGreen, Color(0xFF0FD850)]),
                              boxShadow: [BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: mainCtrl,
              builder: (_, __) => Opacity(
                opacity: taglineFade.value * .7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SplashScreen.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SplashScreen.primaryGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: SplashScreen.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Powered by Gemini AI',
                            style: TextStyle(
                              color: SplashScreen.lightGreen.withValues(alpha: 0.9),
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CirclesPainter extends CustomPainter {
  final double progress;
  _CirclesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      paint.color = SplashScreen.primaryGreen.withValues(alpha: 0.1 * (4 - i) * progress);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), (100 + i * 80) * progress, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CirclesPainter oldDelegate) => oldDelegate.progress != progress;
}

class _Particle {
  double x, y, size, speed, opacity;
  _Particle(this.x, this.y, this.size, this.speed, this.opacity);
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  _ParticlePainter(this.particles, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final y = (p.y - time * p.speed) % 1;
      final paint = Paint()
        ..color = SplashScreen.primaryGreen.withValues(alpha: p.opacity * (1 - y * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(p.x * size.width, y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.time != time;
}

class _Typewriter extends StatefulWidget {
  const _Typewriter();

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> with SingleTickerProviderStateMixin {
  static const text = 'Scan. Identify. Collect.';
  late final AnimationController ctrl;
  String displayText = '';

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) ctrl.forward();
    });
    ctrl.addListener(_updateText);
  }

  void _updateText() {
    final charCount = (text.length * ctrl.value).round();
    if (mounted) setState(() => displayText = text.substring(0, charCount));
  }

  @override
  void dispose() {
    ctrl.removeListener(_updateText);
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayText,
          style: const TextStyle(
            color: SplashScreen.lightGreen,
            fontSize: 18,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (ctrl.value < 1.0) const _BlinkingCursor(),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
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

// ============================================================================
// Paywall Screen
// ============================================================================

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
            : SingleChildScrollView(
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _StaticTextScreen(
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _StaticTextScreen(
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Test Mode - No real charges', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
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
      children: features.map((feature) {
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
              child: isSelected
                  ? const Center(child: CircleAvatar(radius: 6, backgroundColor: Color(0xFF13EC5B)))
                  : null,
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
                if (savings != null)
                  Text(savings, style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 12)),
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

// ============================================================================
// Main Navigation
// ============================================================================

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
                        children: [
                          _buildNavItem(Icons.home_rounded, 'Home', 0),
                          _buildNavItem(Icons.menu_book_rounded, 'Learn', 1),
                        ],
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScanScreen(initialType: 'coin')),
    );
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
            Icon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFF13EC5B) : const Color(0xFF92C9A4),
            ),
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

// ============================================================================
// Home Screen
// ============================================================================

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('$_greeting, coin lover!', style: Theme.of(context).textTheme.headlineLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF23482F),
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF102216).withValues(alpha: 0.95),
                ),
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
                      Text(
                        "You're on the Free plan",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upgrade for unlimited scans.',
                        style: TextStyle(color: Color(0xFF92C9A4), fontSize: 12.5),
                      ),
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
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifyCard(BuildContext context, IconData icon, String title, Color accentColor, String type) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CameraScanScreen(initialType: type)),
      ),
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
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Camera Scan Screen
// ============================================================================

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
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
        final preset = {
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
        MaterialPageRoute(
          builder: (context) => AnalyzingCoinScreen(imageFile: File(image.path), type: _scanType),
        ),
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
          MaterialPageRoute(
            builder: (context) => AnalyzingCoinScreen(imageFile: File(image.path), type: _scanType),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF13EC5B))),
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
                          _buildTopButton(
                            _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            _toggleFlash,
                          ),
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
                          builder: (_, __) => Container(
                            width: 280,
                            height: 280,
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
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(30),
      ),
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
            border: Border(
              top: BorderSide(color: Colors.white, width: 4),
              left: BorderSide(color: Colors.white, width: 4),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

// ============================================================================
// Analyzing Screen
// ============================================================================

class AnalyzingCoinScreen extends StatefulWidget {
  final File imageFile;
  final String type;

  const AnalyzingCoinScreen({super.key, required this.imageFile, this.type = 'coin'});

  @override
  State<AnalyzingCoinScreen> createState() => _AnalyzingCoinScreenState();
}

class _AnalyzingCoinScreenState extends State<AnalyzingCoinScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const bgDark = Color(0xFF102216);
  static const gold = Color(0xFF13EC5B);

  String _statusText = 'Analyzing...';
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
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
      // Replace with your actual Gemini API key
      const apiKey = 'AIzaSyCqaPcPjyLzYZBVTnp5_JlFnOKbJ9Juh6U';

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final imageBytes = await widget.imageFile.readAsBytes();
      final prompt = getPromptForType(widget.type);

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);

      if (!mounted) return;

      setState(() => _isAnalyzing = false);

      final text = response.text?.trim();
      if (text != null && text.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(imageFile: widget.imageFile, analysis: text, type: widget.type),
          ),
        );
      } else {
        _showErrorDialog('No analysis text returned from AI.');
      }
    } catch (e) {
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(error, style: const TextStyle(color: Color(0xFF92C9A4))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Go Back', style: TextStyle(color: Color(0xFF92C9A4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: bgDark),
            onPressed: () {
              Navigator.pop(context);
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
            final opacity = (1 - (value - 0.5).abs() * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: opacity)),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Analyzing ${_getItemName()[0].toUpperCase()}${_getItemName().substring(1)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold.withValues(alpha: 0.3), width: 2),
                          boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(widget.imageFile, fit: BoxFit.cover),
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
                                    border: Border.all(color: gold.withValues(alpha: 0.2), width: 4),
                                  ),
                                  child: CustomPaint(painter: _ArcPainter(color: gold)),
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
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This usually takes a few seconds',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Color(0xFF92C9A4)),
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

// ============================================================================
// Result Screen
// ============================================================================

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final String analysis;
  final String type;

  const ResultScreen({super.key, required this.imageFile, required this.analysis, this.type = 'coin'});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isFavorite = false;

  String get _title {
    switch (widget.type.toLowerCase()) {
      case 'coin':
        return 'Coin details';
      case 'banknote':
        return 'Banknote details';
      case 'medal':
        return 'Medal details';
      case 'token':
        return 'Token / Artifact details';
      default:
        return 'Item details';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved to My Collection!'),
        backgroundColor: const Color(0xFF13EC5B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF102216),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: Colors.white,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                child: IconButton(
                  onPressed: () => setState(() => _isFavorite = !_isFavorite),
                  icon: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 22,
                  ),
                  color: _isFavorite ? Colors.red : Colors.white,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF23482F),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.analysis,
                      style: const TextStyle(color: Color(0xFF92C9A4), height: 1.6, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF102216).withValues(alpha: 0.0),
              const Color(0xFF102216).withValues(alpha: 0.95),
              const Color(0xFF102216),
            ],
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _saveToCollection,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13EC5B),
              foregroundColor: const Color(0xFF102216),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text(
              'Save to My Collection',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// My Collection Screen
// ============================================================================

class MyCollectionScreen extends StatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  State<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

class _MyCollectionScreenState extends State<MyCollectionScreen> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];
    setState(() {
      items = list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];
    if (index < list.length) {
      list.removeAt(index);
      await prefs.setStringList('collection', list);
    }
    _load();
  }

  Future<void> _toggleFavorite(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];
    if (index < list.length) {
      final map = jsonDecode(list[index]) as Map<String, dynamic>;
      final current = map['favorite'] as bool? ?? false;
      map['favorite'] = !current;
      list[index] = jsonEncode(map);
      await prefs.setStringList('collection', list);
    }
    _load();
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF193322),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this item from your collection?',
          style: TextStyle(color: Color(0xFF92C9A4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF92C9A4))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = items.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('My Collection')),
      body: empty
          ? const _EmptyCollection()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final it = items[i];
          final path = it['imagePath'] as String?;
          final isFav = it['favorite'] as bool? ?? false;

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF193322),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: path != null && File(path).existsSync()
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover),
              )
                  : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF13EC5B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.toll, size: 32, color: Color(0xFF13EC5B)),
              ),
              title: Text(
                (it['type'] as String?)?.toUpperCase() ?? 'ITEM',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                (it['analysis'] as String?)?.split('\n').take(2).join('\n') ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.white70,
                    ),
                    onPressed: () => _toggleFavorite(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    onPressed: () => _showDeleteConfirmation(i),
                  ),
                ],
              ),
              onTap: () {
                if (path != null && File(path).existsSync()) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        imageFile: File(path),
                        analysis: it['analysis'] as String? ?? '',
                        type: it['type'] as String? ?? 'coin',
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF13EC5B).withValues(alpha: 0.2), const Color(0xFF23482F)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.toll, size: 100, color: Color(0xFF13EC5B)),
            ),
            const SizedBox(height: 24),
            const Text(
              'You have no items yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first item and start\nbuilding your collection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF92C9A4), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Learn Screen
// ============================================================================

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: '1. Detecting Counterfeit Coins',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Start with these fundamentals:', style: TextStyle(color: Color(0xFF92C9A4), height: 1.5)),
                SizedBox(height: 12),
                _Bullet(label: 'Visual inspection:', text: 'Look for sharp details and clean edges.'),
                _Bullet(label: 'Weight & size:', text: 'Use a digital scale and calipers.'),
                _Bullet(label: 'Magnet test:', text: 'Most precious-metal coins are not magnetic.'),
                _Bullet(label: 'Edge & sound:', text: 'Check for clean, even reeding.'),
              ],
            ),
          ),
          _SectionCard(
            title: '2. The 1909 Lincoln Penny',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('The first regular U.S. coin to feature a real historical figure.', style: TextStyle(color: Color(0xFF92C9A4), height: 1.5)),
                SizedBox(height: 12),
                _Bullet(label: 'Designer:', text: 'Victor David Brenner created the design.'),
                _Bullet(label: 'Key variety:', text: '1909-S VDB is highly sought after.'),
              ],
            ),
          ),
          _SectionCard(
            title: '3. Silver vs. Gold Coins',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet(label: 'Silver coins:', text: 'More affordable, ideal for beginners.'),
                _Bullet(label: 'Gold coins:', text: 'High value in a small space.'),
                _Bullet(label: 'Balanced approach:', text: 'Many collectors hold both metals.'),
              ],
            ),
          ),
          _SectionCard(
            title: '4. How Coin Grading Works',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('The standard U.S. scale runs from Poor (P-1) to Mint State (MS-70).', style: TextStyle(color: Color(0xFF92C9A4), height: 1.5)),
                SizedBox(height: 12),
                _Bullet(label: 'Circulated grades:', text: 'Poor to About Uncirculated.'),
                _Bullet(label: 'Uncirculated:', text: 'MS-60 to MS-70, no wear from circulation.'),
              ],
            ),
          ),
          _SectionCard(
            title: '5. Rare Coins in Everyday Change',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet(label: 'Wheat cents:', text: 'Older Lincoln cents (1909-1958).'),
                _Bullet(label: 'Pre-1965 silver:', text: 'Dimes, quarters, halves contain 90% silver.'),
                _Bullet(label: 'Error coins:', text: 'Off-center strikes, doubled designs.'),
              ],
            ),
          ),
          _SectionCard(
            title: '6. Understanding Mint Marks',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet(label: 'Common U.S. marks:', text: 'P = Philadelphia, D = Denver, S = San Francisco.'),
                _Bullet(label: 'Rarity by mint:', text: 'Some mints produced fewer coins in certain years.'),
              ],
            ),
          ),
          _SectionCard(
            title: '7. Building a Collection',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet(label: 'Choose a focus:', text: 'Pick an era, country, or denomination.'),
                _Bullet(label: 'Quality over quantity:', text: 'Well-chosen coins are more satisfying.'),
                _Bullet(label: 'Protect your coins:', text: 'Use proper holders and avoid cleaning.'),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

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
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String label;
  final String text;
  const _Bullet({required this.label, required this.text});

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

// ============================================================================
// Profile Screen
// ============================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _revenueCat = RevenueCatService();
  bool isPremium = false;
  String displayName = 'Collector';
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await _revenueCat.refreshCustomerInfo();

    setState(() {
      isPremium = _revenueCat.isPremium;
      displayName = prefs.getString('displayName') ?? 'Collector';
      _nameCtrl.text = displayName;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayName', displayName.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: Color(0xFF13EC5B)),
    );
  }

  Future<void> _showPaywall() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PaywallScreen(), fullscreenDialog: true),
    );
    if (result == true) await _load();
  }

  Future<void> _restorePurchases() async {
    final result = await _revenueCat.restorePurchases();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isPremium ? const Color(0xFF13EC5B) : Colors.orange,
      ),
    );

    if (result.isPremium) await _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _SectionCard(
            title: 'Profile',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF13EC5B),
                  child: Text(
                    (displayName.isNotEmpty ? displayName[0] : 'C').toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF102216),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: const TextStyle(color: Color(0xFF92C9A4)),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF326744)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF13EC5B)),
                      ),
                    ),
                    onChanged: (v) => displayName = v,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.save, color: Color(0xFF13EC5B)),
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),

          // Subscription Section
          _SectionCard(
            title: 'Subscription',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPremium ? const Color(0xFF13EC5B).withValues(alpha: 0.1) : const Color(0xFF23482F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPremium ? const Color(0xFF13EC5B) : const Color(0xFF326744).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPremium ? Icons.workspace_premium : Icons.lock_open,
                        color: const Color(0xFF13EC5B),
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPremium ? 'Premium Active' : 'Free Plan',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPremium ? 'Unlimited identifications' : '3 free identifications',
                              style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!isPremium)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showPaywall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13EC5B),
                            foregroundColor: const Color(0xFF102216),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (!isPremium) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _restorePurchases,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF13EC5B),
                          side: const BorderSide(color: Color(0xFF13EC5B)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (isPremium && _revenueCat.customerInfo != null) ...[
                  const SizedBox(height: 16),
                  _buildSubscriptionInfo(),
                ],
              ],
            ),
          ),

          // Help & Legal Section
          _SectionCard(
            title: 'Help & Legal',
            child: Column(
              children: [
                _HelpItem(
                  icon: Icons.help_outline,
                  text: 'FAQ',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const _StaticTextScreen(
                        title: 'FAQ',
                        body: '''
Q: How do I scan a coin or banknote?
A: Open the camera from Home, align the item in the frame, then tap the shutter button.

Q: How many free scans do I get?
A: You have 3 free scans. Upgrade to Premium for unlimited scans.

Q: How do I restore my purchase?
A: Go to Profile > Subscription > Restore to restore previous purchases.

Q: What types of items can I identify?
A: You can identify coins, banknotes, medals, tokens, and artifacts.

Q: Where is my collection stored?
A: All items are stored locally on your device.

Q: How accurate is the AI identification?
A: The AI provides detailed analysis, but we recommend verifying important valuations with professional numismatists.
''',
                      ),
                    ),
                  ),
                ),
                _HelpItem(
                  icon: Icons.privacy_tip_outlined,
                  text: 'Privacy Policy',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const _StaticTextScreen(
                        title: 'Privacy Policy',
                        body: '''
Privacy Policy for Coinium

Last updated: 2024

Your privacy is important to us. This policy explains how we handle your data.

DATA COLLECTION:
• We store your collection data locally on your device
• Images are only sent to Google's Gemini AI when you request analysis
• We do not collect personal information

DATA USAGE:
• Scan images are processed by AI for identification
• Collection data remains on your device
• No data is sold to third parties

DATA STORAGE:
• All data is stored locally using secure device storage
• Subscription status is managed by RevenueCat

THIRD-PARTY SERVICES:
• Google Gemini AI for image analysis
• RevenueCat for subscription management
• Apple App Store / Google Play for payments

CONTACT:
For privacy questions, contact us at support@coinium.app
''',
                      ),
                    ),
                  ),
                ),
                _HelpItem(
                  icon: Icons.gavel_outlined,
                  text: 'Terms of Use',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const _StaticTextScreen(
                        title: 'Terms of Use',
                        body: '''
Terms of Use for Coinium

Last updated: 2024

By using Coinium, you agree to these terms.

SERVICE DESCRIPTION:
• Coinium provides AI-powered coin and collectible identification
• Results are estimates and may not be 100% accurate
• Do not rely solely on the app for financial decisions

USER RESPONSIBILITIES:
• Use the app lawfully and responsibly
• Do not attempt to reverse engineer the app
• Report any bugs or issues to our support team

SUBSCRIPTION TERMS:
• Payment will be charged to your App Store or Google Play account
• Subscriptions automatically renew unless cancelled 24 hours before the end of the current period
• You can manage and cancel subscriptions in your account settings

DISCLAIMERS:
• The app is provided "as is" without warranty
• We are not responsible for decisions made based on AI analysis
• Always verify valuations with professional numismatists

CHANGES TO TERMS:
We may update these terms at any time. Continued use constitutes acceptance.

CONTACT:
For questions, contact support@coinium.app
''',
                      ),
                    ),
                  ),
                ),
                _HelpItem(
                  icon: Icons.mail_outline,
                  text: 'Contact Support',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email: support@coinium.app'),
                        backgroundColor: Color(0xFF13EC5B),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // App Info
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                const Text('Coinium', style: TextStyle(color: Color(0xFF92C9A4), fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: const Color(0xFF92C9A4).withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSubscriptionInfo() {
    final customerInfo = _revenueCat.customerInfo;
    if (customerInfo == null) return const SizedBox.shrink();

    // Check both possible entitlement names
    var entitlement = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId];
    entitlement ??= customerInfo.entitlements.active.values.firstOrNull;

    if (entitlement == null) return const SizedBox.shrink();

    String statusText = 'Active';
    IconData statusIcon = Icons.check_circle;
    Color statusColor = const Color(0xFF13EC5B);

    if (entitlement.expirationDate != null) {
      final expiry = DateTime.parse(entitlement.expirationDate!);
      final daysLeft = expiry.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        statusText = 'Renews in $daysLeft days';
        statusIcon = Icons.autorenew;
      } else if (daysLeft == 0) {
        statusText = 'Renews today';
        statusIcon = Icons.autorenew;
      } else {
        statusText = 'Expires soon';
        statusIcon = Icons.warning;
        statusColor = Colors.orange;
      }
    } else {
      statusText = 'Lifetime access';
      statusIcon = Icons.all_inclusive;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF23482F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 8),
          Expanded(child: Text(statusText, style: TextStyle(color: statusColor))),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _HelpItem({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF13EC5B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF13EC5B), size: 20),
      ),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF92C9A4)),
      onTap: onTap,
    );
  }
}

class _StaticTextScreen extends StatelessWidget {
  final String title;
  final String body;

  const _StaticTextScreen({required this.title, required this.body});

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