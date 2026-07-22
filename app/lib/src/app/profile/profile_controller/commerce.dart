import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const fullGameEntitlementID = 'full_game';
const appleFullGameProductID = 'com.williamtheisen.kolkhoz.fullgame';
const googleFullGameProductID = 'com.williamtheisen.kolkhoz.fullgame';
const kolkhozBetaBuild = bool.fromEnvironment('KOLKHOZ_BETA');

abstract interface class KolkhozPurchaseStore {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases({String? applicationUserName});
  Future<void> completePurchase(PurchaseDetails purchase);
}

class FlutterPurchaseStore implements KolkhozPurchaseStore {
  const FlutterPurchaseStore();

  InAppPurchase get _store => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _store.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _store.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _store.restorePurchases(applicationUserName: applicationUserName);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}

class KolkhozCommerceController extends ChangeNotifier {
  KolkhozCommerceController({
    required this.fetchFullGameEntitlement,
    required this.claimFullGamePurchase,
    required this.onFullGameChanged,
    this.purchaseStore = const FlutterPurchaseStore(),
    String? productID,
    String? provider,
    this.betaBuild = kolkhozBetaBuild,
  }) : _productID = productID ?? _defaultProductID,
       _provider = provider ?? _defaultProvider;

  final Future<bool> Function() fetchFullGameEntitlement;
  final Future<bool> Function({
    required String provider,
    required String verificationData,
  })
  claimFullGamePurchase;
  final void Function(String userID, bool unlocked) onFullGameChanged;
  final KolkhozPurchaseStore purchaseStore;
  final bool betaBuild;
  final String? _productID;
  final String? _provider;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String? _userID;
  ProductDetails? _product;
  bool _fullGameUnlocked = false;
  bool _busy = false;
  bool _storeAvailable = false;
  String? _message;

  bool get fullGameUnlocked => betaBuild || _fullGameUnlocked;
  bool get busy => _busy;
  bool get storeAvailable => _storeAvailable && _product != null;
  String? get message => _message;
  String? get price => _product?.price;

  static String? get _defaultProvider {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'apple',
      TargetPlatform.android => 'google',
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => null,
    };
  }

  static String? get _defaultProductID {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appleFullGameProductID,
      TargetPlatform.android => googleFullGameProductID,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => null,
    };
  }

  void initialize() {
    if (_provider == null) return;
    _subscription ??= purchaseStore.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _busy = false;
        _message = 'The storefront reported an error. Please try again.';
        notifyListeners();
      },
    );
  }

  Future<void> attachUser(
    String? userID, {
    required bool cachedFullGame,
  }) async {
    initialize();
    if (_userID == userID && _fullGameUnlocked == cachedFullGame) return;
    _userID = userID;
    _fullGameUnlocked = userID != null && cachedFullGame;
    _message = null;
    notifyListeners();
    if (userID == null) return;
    await refresh();
  }

  Future<void> refresh() async {
    final userID = _userID;
    if (userID == null) return;
    await _loadProduct();
    try {
      final unlocked = await fetchFullGameEntitlement();
      if (_userID != userID) return;
      _setUnlocked(userID, unlocked);
    } catch (_) {
      // Preserve the cached entitlement so purchased offline play keeps working.
    }
  }

  Future<void> purchase() async {
    final userID = _userID;
    final product = _product;
    if (userID == null) {
      _message = 'Sign in before purchasing the full game.';
      notifyListeners();
      return;
    }
    if (product == null) {
      await _loadProduct();
    }
    final loadedProduct = _product;
    if (loadedProduct == null || _provider == null) {
      _message =
          'The full-game purchase is not available on this platform yet.';
      notifyListeners();
      return;
    }
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final started = await purchaseStore.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: loadedProduct,
          applicationUserName: userID,
        ),
      );
      if (!started) {
        _busy = false;
        _message = 'The storefront could not start the purchase.';
        notifyListeners();
      }
    } catch (_) {
      _busy = false;
      _message = 'The storefront could not start the purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    final userID = _userID;
    if (userID == null) {
      _message = 'Sign in before restoring a purchase.';
      notifyListeners();
      return;
    }
    if (_provider == null) {
      _message =
          'The full-game purchase is not available on this platform yet.';
      notifyListeners();
      return;
    }
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await purchaseStore.restorePurchases(applicationUserName: userID);
      await refresh();
      if (!_fullGameUnlocked) {
        _message = 'No full-game purchase was found for this account.';
      }
    } catch (_) {
      _message = 'The storefront could not restore purchases.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadProduct() async {
    final productID = _productID;
    if (productID == null || _product != null) return;
    try {
      _storeAvailable = await purchaseStore.isAvailable();
      if (!_storeAvailable) return;
      final response = await purchaseStore.queryProductDetails({productID});
      _product = response.productDetails
          .where((product) => product.id == productID)
          .firstOrNull;
      if (response.error != null) {
        _message = 'The storefront could not load the full-game product.';
      }
    } catch (_) {
      _storeAvailable = false;
    }
    notifyListeners();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _productID) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _busy = true;
          _message = 'Waiting for the storefront to approve the purchase…';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
        case PurchaseStatus.canceled:
          _busy = false;
          _message = null;
          break;
        case PurchaseStatus.error:
          _busy = false;
          _message = purchase.error?.message ?? 'The purchase failed.';
          break;
      }
      notifyListeners();
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    final userID = _userID;
    final provider = _provider;
    if (userID == null || provider == null) {
      _busy = false;
      _message = 'Sign in to link this purchase to your Kolkhoz account.';
      return;
    }
    try {
      final unlocked = await claimFullGamePurchase(
        provider: provider,
        verificationData: purchase.verificationData.serverVerificationData,
      );
      if (_userID != userID) return;
      _setUnlocked(userID, unlocked);
      if (purchase.pendingCompletePurchase) {
        await purchaseStore.completePurchase(purchase);
      }
      _message = unlocked ? 'The full game is unlocked on your account.' : null;
    } catch (_) {
      _message = 'The purchase could not be verified. It has not been linked.';
    } finally {
      _busy = false;
    }
  }

  void _setUnlocked(String userID, bool value) {
    _fullGameUnlocked = value;
    onFullGameChanged(userID, value);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
