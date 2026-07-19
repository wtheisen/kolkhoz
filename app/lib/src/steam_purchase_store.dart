import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:steamworks/steamworks.dart';

import 'commerce.dart';

const _steamAppID = int.fromEnvironment('KOLKHOZ_STEAM_APP_ID');
const _ticketIdentity = 'kolkhoz-commerce';

class SteamworksPurchaseStore implements KolkhozSteamPurchaseStore {
  final _authorizations =
      StreamController<SteamPurchaseAuthorization>.broadcast();
  final _ticketRequests = <int, Completer<SteamAuthenticationTicket>>{};

  SteamClient? _client;
  Callback<GetTicketForWebApiResponse>? _ticketCallback;
  Callback<MicroTxnAuthorizationResponse>? _authorizationCallback;
  Timer? _callbackTimer;

  @override
  Stream<SteamPurchaseAuthorization> get authorizationStream =>
      _authorizations.stream;

  @override
  Future<bool> initialize() async {
    if (_client != null) return true;
    if (_steamAppID <= 0) return false;
    try {
      if (SteamApi.restartAppIfNecessary(_steamAppID)) {
        exit(0);
      }
      SteamClient.init();
      final client = SteamClient.instance;
      _client = client;
      _ticketCallback = client.registerCallback<GetTicketForWebApiResponse>(
        cb: _handleTicket,
      );
      _authorizationCallback = client
          .registerCallback<MicroTxnAuthorizationResponse>(
            cb: _handleAuthorization,
          );
      _callbackTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => client.runFrame(),
      );
      return true;
    } catch (_) {
      _client = null;
      return false;
    }
  }

  @override
  Future<SteamAuthenticationTicket> authenticationTicket() async {
    final client = _client;
    if (client == null && !await initialize()) {
      throw StateError('Steam is not available');
    }
    final identity = _ticketIdentity.toNativeUtf8();
    try {
      final handle = _client!.steamUser.getAuthTicketForWebApi(identity);
      final completer = Completer<SteamAuthenticationTicket>();
      _ticketRequests[handle] = completer;
      try {
        return await completer.future.timeout(const Duration(seconds: 10));
      } catch (_) {
        _ticketRequests.remove(handle);
        _client?.steamUser.cancelAuthTicket(handle);
        rethrow;
      }
    } finally {
      malloc.free(identity);
    }
  }

  void _handleTicket(Pointer<GetTicketForWebApiResponse> response) {
    final completer = _ticketRequests.remove(response.authTicket);
    if (completer == null) return;
    if (response.result != EResult.eResultOK) {
      completer.completeError(StateError('Steam ticket request failed'));
      return;
    }
    final length = response.ticket;
    if (length <= 0 || length > 2560) {
      completer.completeError(StateError('Steam returned an invalid ticket'));
      return;
    }
    final ticket = StringBuffer();
    for (var index = 0; index < length; index += 1) {
      ticket.write(
        response.ticketAsArray[index].toRadixString(16).padLeft(2, '0'),
      );
    }
    completer.complete(
      SteamAuthenticationTicket(
        value: ticket.toString(),
        handle: response.authTicket,
      ),
    );
  }

  void _handleAuthorization(Pointer<MicroTxnAuthorizationResponse> response) {
    if (response.appId != _steamAppID) return;
    _authorizations.add(
      SteamPurchaseAuthorization(
        orderID: response.orderId.toString(),
        authorized: response.authorized == 1,
      ),
    );
  }

  @override
  void cancelAuthenticationTicket(int handle) {
    _ticketRequests.remove(handle);
    _client?.steamUser.cancelAuthTicket(handle);
  }

  @override
  void dispose() {
    _callbackTimer?.cancel();
    final client = _client;
    final ticketCallback = _ticketCallback;
    if (client != null && ticketCallback != null) {
      client.unregisterCallback(callback: ticketCallback);
    }
    final authorizationCallback = _authorizationCallback;
    if (client != null && authorizationCallback != null) {
      client.unregisterCallback(callback: authorizationCallback);
    }
    for (final completer in _ticketRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Steam purchase store was closed'));
      }
    }
    _ticketRequests.clear();
    unawaited(_authorizations.close());
  }
}
