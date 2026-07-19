import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'online_game_client.dart';

const fullGameEntitlementID = 'full_game';
const appleFullGameProductID = 'com.williamtheisen.kolkhoz.fullgame';
const googleFullGameProductID = 'com.williamtheisen.kolkhoz.fullgame';
const kolkhozBetaBuild = bool.fromEnvironment('KOLKHOZ_BETA');

class SteamAuthenticationTicket {
  const SteamAuthenticationTicket({required this.value, required this.handle});

  final String value;
  final int handle;
}

class SteamPurchaseAuthorization {
  const SteamPurchaseAuthorization({
    required this.orderID,
    required this.authorized,
  });

  final String orderID;
  final bool authorized;
}

abstract interface class KolkhozSteamPurchaseStore {
  Stream<SteamPurchaseAuthorization> get authorizationStream;

  Future<bool> initialize();
  Future<SteamAuthenticationTicket> authenticationTicket();
  void cancelAuthenticationTicket(int handle);
  void dispose();
}

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
    required this.clientFactory,
    required this.onFullGameChanged,
    this.purchaseStore = const FlutterPurchaseStore(),
    this.steamPurchaseStore,
    String? productID,
    String? provider,
    this.betaBuild = kolkhozBetaBuild,
  }) : _productID = productID ?? _defaultProductID,
       _provider = provider ?? _defaultProvider;

  final KolkhozOnlineClient Function() clientFactory;
  final void Function(String userID, bool unlocked) onFullGameChanged;
  final KolkhozPurchaseStore purchaseStore;
  final KolkhozSteamPurchaseStore? steamPurchaseStore;
  final bool betaBuild;
  final String? _productID;
  final String? _provider;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  StreamSubscription<SteamPurchaseAuthorization>? _steamSubscription;
  String? _userID;
  ProductDetails? _product;
  bool _fullGameUnlocked = false;
  bool _busy = false;
  bool _storeAvailable = false;
  String? _message;

  bool get fullGameUnlocked => betaBuild || _fullGameUnlocked;
  bool get busy => _busy;
  bool get storeAvailable => steamPurchaseStore != null
      ? _storeAvailable
      : _storeAvailable && _product != null;
  String? get message => _message;
  String? get price => steamPurchaseStore != null ? r'$4.99' : _product?.price;

  static String? get _defaultProvider {
    if (Platform.isIOS || Platform.isMacOS) return 'apple';
    if (Platform.isAndroid) return 'google';
    return null;
  }

  static String? get _defaultProductID {
    if (Platform.isIOS || Platform.isMacOS) return appleFullGameProductID;
    if (Platform.isAndroid) return googleFullGameProductID;
    return null;
  }

  void initialize() {
    final steamStore = steamPurchaseStore;
    if (steamStore != null) {
      _steamSubscription ??= steamStore.authorizationStream.listen(
        _handleSteamAuthorization,
        onError: (Object error) {
          _busy = false;
          _message = 'Steam reported an error. Please try again.';
          notifyListeners();
        },
      );
      return;
    }
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
      final unlocked = await clientFactory().fetchFullGameEntitlement();
      if (_userID != userID) return;
      _setUnlocked(userID, unlocked);
    } catch (_) {
      // Preserve the cached entitlement so purchased offline play keeps working.
    }
  }

  Future<void> purchase() async {
    final userID = _userID;
    if (userID == null) {
      _message = 'Sign in before purchasing the full game.';
      notifyListeners();
      return;
    }
    if (steamPurchaseStore != null) {
      await _purchaseWithSteam(userID);
      return;
    }
    if (_product == null) {
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
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      if (steamPurchaseStore != null) {
        final unlocked = await _syncSteam();
        _setUnlocked(userID, unlocked);
        if (!unlocked) {
          _message = 'No full-game purchase was found for this account.';
        }
        return;
      }
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
    final steamStore = steamPurchaseStore;
    if (steamStore != null) {
      if (_storeAvailable) return;
      try {
        _storeAvailable = await steamStore.initialize();
      } catch (_) {
        _storeAvailable = false;
      }
      notifyListeners();
      return;
    }
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

  Future<void> _purchaseWithSteam(String userID) async {
    await _loadProduct();
    final steamStore = steamPurchaseStore;
    if (!_storeAvailable || steamStore == null) {
      _message = 'Steam is not available. Launch Kolkhoz from Steam and retry.';
      notifyListeners();
      return;
    }
    _busy = true;
    _message = null;
    notifyListeners();
    SteamAuthenticationTicket? ticket;
    try {
      ticket = await steamStore.authenticationTicket();
      final orderID = await clientFactory().startSteamFullGamePurchase(
        authenticationTicket: ticket.value,
      );
      if (_userID != userID) return;
      if (orderID == null) {
        await refresh();
        _busy = false;
        return;
      }
      _message = 'Complete the purchase in the Steam overlay.';
    } catch (_) {
      _busy = false;
      _message = 'Steam could not start the purchase.';
    } finally {
      if (ticket != null) {
        steamStore.cancelAuthenticationTicket(ticket.handle);
      }
      notifyListeners();
    }
  }

  Future<void> _handleSteamAuthorization(
    SteamPurchaseAuthorization authorization,
  ) async {
    final userID = _userID;
    if (userID == null) return;
    _busy = true;
    notifyListeners();
    try {
      final unlocked = await clientFactory().authorizeSteamFullGamePurchase(
        orderID: authorization.orderID,
        authorized: authorization.authorized,
      );
      if (_userID != userID) return;
      _setUnlocked(userID, unlocked);
      _message = authorization.authorized && unlocked
          ? 'The full game is unlocked on your account.'
          : null;
    } catch (_) {
      _message = 'The Steam purchase could not be verified.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _syncSteam() async {
    final steamStore = steamPurchaseStore!;
    SteamAuthenticationTicket? ticket;
    try {
      ticket = await steamStore.authenticationTicket();
      return await clientFactory().syncSteamFullGamePurchase(
        authenticationTicket: ticket.value,
      );
    } finally {
      if (ticket != null) {
        steamStore.cancelAuthenticationTicket(ticket.handle);
      }
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
      final unlocked = await clientFactory().claimFullGamePurchase(
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
    unawaited(_steamSubscription?.cancel());
    steamPurchaseStore?.dispose();
    super.dispose();
  }
}
