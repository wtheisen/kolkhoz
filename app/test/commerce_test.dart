import 'dart:async';

import 'package:flutter/foundation.dart';
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
}

class _FakeStore implements KolkhozPurchaseStore {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  int purchaseStreamReads = 0;
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
  Stream<List<PurchaseDetails>> get purchaseStream {
    purchaseStreamReads += 1;
    return controller.stream;
  }

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

  test('release build receives the expected beta entitlement flag', () {
    const expected = String.fromEnvironment('KOLKHOZ_EXPECTED_BETA');
    if (expected.isEmpty) return;
    expect(expected, anyOf('true', 'false'));
    expect(kolkhozBetaBuild, expected == 'true');
  });

  test('Windows startup does not initialize an unsupported purchase store', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final windowsCommerce = KolkhozCommerceController(
      clientFactory: () => client,
      onFullGameChanged: (_, _) {},
      purchaseStore: store,
    );
    addTearDown(windowsCommerce.dispose);

    windowsCommerce.initialize();

    expect(store.purchaseStreamReads, 0);
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
