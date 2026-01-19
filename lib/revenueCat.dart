import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RevenueCatConfig {
  // 1. YOUR API KEY (Make sure this matches RevenueCat -> Project Settings -> Apps)
  static const String googleApiKey = 'goog_flCGgdFuhrmSAVeSVWkvamYzVqG';

  // 2. YOUR ENTITLEMENT ID (Must match RevenueCat -> Entitlements -> Identifier)
  // WARNING: Check your dashboard! It might be "pro_access" or "premium" or "Coin Identifier Premium"
  static const String premiumEntitlementId = 'pro_access';
}

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;
  bool _isPremium = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  bool get isPremium => _isPremium;
  Offerings? get offerings => _offerings;

  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      String apiKey = RevenueCatConfig.googleApiKey;

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      // Listen for changes (e.g. subscription expired outside the app)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      // Get initial data
      await refreshCustomerInfo();
      await fetchOfferings();

      _isInitialized = true;
      debugPrint('✅ RevenueCat initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing RevenueCat: $e');
      await _loadLocalPremiumStatus();
    }
  }

  /// Refresh customer info from RevenueCat
  Future<void> refreshCustomerInfo() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      if (_customerInfo != null) {
        _updatePremiumStatus(_customerInfo!);
      }
    } catch (e) {
      debugPrint('Error fetching customer info: $e');
    }
  }

  /// Fetch available offerings/products
  Future<void> fetchOfferings() async {
    try {
      _offerings = await Purchases.getOfferings();
      debugPrint("📦 Offerings fetched: ${_offerings?.current?.availablePackages.length ?? 0} packages found.");
    } catch (e) {
      debugPrint('❌ Error fetching offerings: $e');
    }
  }

  /// Update premium status based on customer info
  void _updatePremiumStatus(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;

    // Check specific entitlement
    final entitlement = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId];
    _isPremium = entitlement?.isActive ?? false;

    // Fallback: If ANY entitlement is active, grant access (safeguard)
    if (!_isPremium && customerInfo.entitlements.active.isNotEmpty) {
      _isPremium = true;
    }

    _saveLocalPremiumStatus(_isPremium);
    debugPrint("👑 Premium Status: $_isPremium");
  }

  /// Purchase a package
  Future<AppPurchaseResult> purchasePackage(Package package) async {
    try {
      // FIXED: Purchases.purchasePackage returns CustomerInfo directly
      PurchaseResult customerInfo = await Purchases.purchasePackage(package);

      _updatePremiumStatus(customerInfo as CustomerInfo);

      return AppPurchaseResult(
        success: _isPremium,
        isPremium: _isPremium,
        message: _isPremium ? 'Welcome to Premium!' : 'Purchase completed.',
      );
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      String message = 'An error occurred';

      switch (errorCode) {
        case PurchasesErrorCode.purchaseCancelledError:
          message = 'Purchase cancelled';
          break;
        case PurchasesErrorCode.purchaseNotAllowedError:
          message = 'Purchases not allowed on this device';
          break;
        case PurchasesErrorCode.productAlreadyPurchasedError:
          message = 'You already own this!';
          await restorePurchases(); // Auto restore if they already own it
          break;
        default:
          message = e.message ?? 'Unknown error';
      }

      return AppPurchaseResult(
        success: false,
        isPremium: _isPremium,
        message: message,
      );
    } catch (e) {
      return AppPurchaseResult(
        success: false,
        isPremium: _isPremium,
        message: 'Error: $e',
      );
    }
  }

  /// Restore purchases
  Future<AppRestoreResult> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);

      return AppRestoreResult(
        success: true,
        isPremium: _isPremium,
        message: _isPremium ? 'Purchases restored!' : 'No active subscriptions found.',
      );
    } catch (e) {
      return AppRestoreResult(
        success: false,
        isPremium: _isPremium,
        message: 'Restore failed: $e',
      );
    }
  }

  // --- Helpers ---
  List<Package> getPackages() {
    return _offerings?.current?.availablePackages ?? [];
  }

  Package? getMonthlyPackage() => _offerings?.current?.monthly;
  Package? getYearlyPackage() => _offerings?.current?.annual;
  Package? getLifetimePackage() => _offerings?.current?.lifetime;

  // --- Local Storage ---
  Future<void> _loadLocalPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('isPremium') ?? false;
  }

  Future<void> _saveLocalPremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', isPremium);
  }
}

// --- Result Classes ---
class AppPurchaseResult {
  final bool success;
  final bool isPremium;
  final String message;

  AppPurchaseResult({required this.success, required this.isPremium, required this.message});
}

class AppRestoreResult {
  final bool success;
  final bool isPremium;
  final String message;

  AppRestoreResult({required this.success, required this.isPremium, required this.message});
}