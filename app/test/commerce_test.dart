import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/commerce.dart';
import 'package:kolkhoz_app/src/online_game_client.dart';
import 'package:kolkhoz_app/src/progression/progression.dart';

class _FakeClient extends KolkhozOnlineClient {
  _FakeClient() : super(Uri.parse('https://example.invalid'));

  bool entitlement = false;
  bool failStatus = false;
  String? claimedProvider;
  String? claimedVerificationData;
  String? steamTicket;
  String? authorizedOrderID;
  bool? steamAuthorized;

  @override
  Future<bool> fetchFullGameEntitlement() async {
    if (failStatus) throw StateError('offline');
    return entitlement;
  }

  @override
  Future<bool> claimFullGamePurchase({
    required String provider,
    required String verificationData,
  }) async {
    claimedProvider = provider;
    claimedVerificationData = verificationData;
    entitlement = true;
    return true;
  }

  @override
  Future<String?> startSteamFullGamePurchase({
    required String authenticationTicket,
    String language = 'en',
  }) async {
    steamTicket = authenticationTicket;
    return '42';
  }

  @override
  Future<bool> authorizeSteamFullGamePurchase({
    required String orderID,
    required bool authorized,
  }) async {
    authorizedOrderID = orderID;
    steamAuthorized = authorized;
    entitlement = authorized;
    return entitlement;
  }

  @override
  Future<bool> syncSteamFullGamePurchase({
    required String authenticationTicket,
  }) async {
    steamTicket = authenticationTicket;
    return entitlement;
  }
}

class _FakeStore implements KolkhozPurchaseStore {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  PurchaseParam? purchaseParam;
  String? restoredUserID;
  final List<PurchaseDetails> completed = [];

  final product = ProductDetails(
    id: appleFullGameProductID,
    title: 'Full Game Unlock',
    description: 'Unlock Kolkhoz.',
    price: r'$4.99',
    rawPrice: 4.99,
    currencyCode: 'USD',
  );

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async =>
      ProductDetailsResponse(productDetails: [product], notFoundIDs: const []);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    this.purchaseParam = purchaseParam;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoredUserID = applicationUserName;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  Future<void> close() => controller.close();
}

class _FakeSteamStore implements KolkhozSteamPurchaseStore {
  final controller = StreamController<SteamPurchaseAuthorization>.broadcast();
  final canceledTickets = <int>[];
  bool initialized = false;
  bool disposed = false;

  @override
  Stream<SteamPurchaseAuthorization> get authorizationStream =>
      controller.stream;

  @override
  Future<bool> initialize() async {
    initialized = true;
    return true;
  }

  @override
  Future<SteamAuthenticationTicket> authenticationTicket() async =>
      const SteamAuthenticationTicket(value: 'aabb', handle: 7);

  @override
  void cancelAuthenticationTicket(int handle) {
    canceledTickets.add(handle);
  }

  @override
  void dispose() {
    disposed = true;
  }

  Future<void> close() => controller.close();
}

void main() {
  late _FakeClient client;
  late _FakeStore store;
  late List<(String, bool)> changes;
  late KolkhozCommerceController commerce;

  setUp(() {
    client = _FakeClient();
    store = _FakeStore();
    changes = [];
    commerce = KolkhozCommerceController(
      clientFactory: () => client,
      onFullGameChanged: (userID, unlocked) {
        changes.add((userID, unlocked));
      },
      purchaseStore: store,
      productID: appleFullGameProductID,
      provider: 'apple',
    );
  });

  tearDown(() async {
    commerce.dispose();
    await store.close();
  });

  test('default full-game access follows the compile-time beta flag', () {
    expect(commerce.fullGameUnlocked, kolkhozBetaBuild);
  });

  test('verified purchase is linked before it is completed', () async {
    await commerce.attachUser('account-1', cachedFullGame: false);
    await commerce.purchase();
    expect(store.purchaseParam?.applicationUserName, 'account-1');

    final purchase = PurchaseDetails(
      purchaseID: 'purchase-1',
      productID: appleFullGameProductID,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'signed-jws',
        source: 'app_store',
      ),
      transactionDate: '1',
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;
    store.controller.add([purchase]);
    await Future<void>.delayed(Duration.zero);

    expect(client.claimedProvider, 'apple');
    expect(client.claimedVerificationData, 'signed-jws');
    expect(commerce.fullGameUnlocked, isTrue);
    expect(changes.last, ('account-1', true));
    expect(store.completed, [purchase]);
  });

  test('cached ownership survives an unavailable server', () async {
    client.failStatus = true;
    await commerce.attachUser('account-1', cachedFullGame: true);
    expect(commerce.fullGameUnlocked, isTrue);
  });

  test('signing out clears ownership but preserves beta access', () async {
    client.entitlement = true;
    await commerce.attachUser('account-1', cachedFullGame: true);
    await commerce.attachUser(null, cachedFullGame: false);
    expect(commerce.fullGameUnlocked, kolkhozBetaBuild);
  });

  test('beta builds unlock the full game without an entitlement', () async {
    final betaCommerce = KolkhozCommerceController(
      clientFactory: () => client,
      onFullGameChanged: (_, _) {},
      purchaseStore: store,
      productID: appleFullGameProductID,
      provider: 'apple',
      betaBuild: true,
    );
    addTearDown(betaCommerce.dispose);

    expect(betaCommerce.fullGameUnlocked, isTrue);
    await betaCommerce.attachUser('playtester', cachedFullGame: false);
    expect(client.entitlement, isFalse);
    expect(betaCommerce.fullGameUnlocked, isTrue);
    await betaCommerce.attachUser(null, cachedFullGame: false);
    expect(betaCommerce.fullGameUnlocked, isTrue);
  });

  test('restore is scoped to the signed-in Kolkhoz account', () async {
    await commerce.attachUser('account-1', cachedFullGame: false);
    await commerce.restore();
    expect(store.restoredUserID, 'account-1');
  });

  test('Steam authorization finalizes and unlocks the same account', () async {
    final steamStore = _FakeSteamStore();
    final steamCommerce = KolkhozCommerceController(
      clientFactory: () => client,
      onFullGameChanged: (userID, unlocked) {
        changes.add((userID, unlocked));
      },
      steamPurchaseStore: steamStore,
    );
    addTearDown(() async {
      steamCommerce.dispose();
      await steamStore.close();
    });

    await steamCommerce.attachUser('account-1', cachedFullGame: false);
    await steamCommerce.purchase();
    expect(steamStore.initialized, isTrue);
    expect(client.steamTicket, 'aabb');
    expect(steamStore.canceledTickets, [7]);
    expect(steamCommerce.message, contains('Steam overlay'));

    steamStore.controller.add(
      const SteamPurchaseAuthorization(orderID: '42', authorized: true),
    );
    await Future<void>.delayed(Duration.zero);

    expect(client.authorizedOrderID, '42');
    expect(client.steamAuthorized, isTrue);
    expect(steamCommerce.fullGameUnlocked, isTrue);
    expect(changes.last, ('account-1', true));
  });

  test('Steam restore reconciles refunds and clears cached access', () async {
    final steamStore = _FakeSteamStore();
    final steamCommerce = KolkhozCommerceController(
      clientFactory: () => client,
      onFullGameChanged: (userID, unlocked) {
        changes.add((userID, unlocked));
      },
      steamPurchaseStore: steamStore,
    );
    addTearDown(() async {
      steamCommerce.dispose();
      await steamStore.close();
    });

    client.entitlement = false;
    await steamCommerce.attachUser('account-1', cachedFullGame: true);
    await steamCommerce.restore();

    expect(client.steamTicket, 'aabb');
    expect(steamCommerce.fullGameUnlocked, isFalse);
    expect(changes.last, ('account-1', false));
  });

  test('offline entitlement cache is user-scoped and can be revoked', () {
    final restored = KolkhozAppSettings.fromJson(
      const KolkhozAppSettings(fullGameEntitlementUserID: 'account-1').toJson(),
    );
    expect(restored.fullGameEntitlementUserID, 'account-1');
    expect(
      restored
          .copyWith(clearFullGameEntitlement: true)
          .fullGameEntitlementUserID,
      isNull,
    );
    final deleted = const KolkhozAppSettings(
      onlineProgression: ProgressionState(progress: {'games': 4}),
      onlineProgressionUserID: 'account-1',
      fullGameEntitlementUserID: 'account-1',
    ).copyWith(clearOnlineProgression: true, clearFullGameEntitlement: true);
    expect(deleted.onlineProgression.progress, isEmpty);
    expect(deleted.onlineProgression.completed, isEmpty);
    expect(deleted.onlineProgression.unlocks, isEmpty);
    expect(deleted.onlineProgressionUserID, isNull);
    expect(deleted.fullGameEntitlementUserID, isNull);
  });
}
