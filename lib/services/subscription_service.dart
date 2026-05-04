import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final subscriptionProvider = NotifierProvider<SubscriptionNotifier, bool>(() {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends Notifier<bool> {
  @override
  bool build() {
    _init();
    return false;
  }

  Future<void> _init() async {
    try {
      await Purchases.setLogLevel(LogLevel.info);
      
      String? apiKey;
      if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_ANDROID_KEY'];
      } else if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_IOS_KEY'];
      }

      if (apiKey != null && apiKey.isNotEmpty) {
        PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
        await Purchases.configure(configuration);
        
        CustomerInfo customerInfo = await Purchases.getCustomerInfo();
        _updateState(customerInfo);
        
        Purchases.addCustomerInfoUpdateListener((customerInfo) {
          _updateState(customerInfo);
        });
      }
    } catch (e) {
      print('Failed to initialize RevenueCat: $e');
    }
  }

  void _updateState(CustomerInfo customerInfo) {
    // We consider the user "Pro" if they have an active entitlement called "pro"
    if (customerInfo.entitlements.all['pro']?.isActive == true) {
      state = true;
    } else {
      state = false;
    }
  }

  Future<bool> purchasePro() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        final package = offerings.current!.availablePackages.first;
        final customerInfo = await Purchases.purchasePackage(package);
        _updateState(customerInfo);
        return state;
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print(e);
      }
    }
    return false;
  }

  Future<void> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _updateState(customerInfo);
    } catch (e) {
      print('Failed to restore purchases: $e');
    }
  }
}
