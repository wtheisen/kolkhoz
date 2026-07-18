import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'chrome_button.dart';
import 'design_tokens.dart';

enum PlayerIdentityLinkState {
  idle,
  pending,
  targetConfirmed,
  approved,
  expired,
  cancelled,
  conflict,
  error,
}

@visibleForTesting
String? playerIdentityBootstrapToken({
  required String? storedIdentityToken,
  required String? legacyAccessToken,
}) => legacyAccessToken ?? storedIdentityToken;

@visibleForTesting
bool shouldRetryPlatformAuthentication(int completedAttempts) =>
    completedAttempts < 3;

@immutable
class KolkhozPlayerIdentity {
  const KolkhozPlayerIdentity({
    required this.id,
    required this.displayName,
    required this.guest,
    this.provider,
  });

  final String id;
  final String displayName;
  final bool guest;
  final String? provider;
}

class KolkhozIdentityRuntime extends ChangeNotifier {
  KolkhozIdentityRuntime._();

  static final instance = KolkhozIdentityRuntime._();
  static const _channel = MethodChannel('com.williamtheisen.kolkhoz/identity');
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'kolkhoz.player.session';

  Uri? _baseURL;
  String? _installationID;
  bool _usingLegacySession = false;
  int _platformAuthenticationAttempts = 0;
  bool _platformRetryScheduled = false;
  String? accessToken;
  KolkhozPlayerIdentity? player;
  bool busy = false;
  String? message;
  PlayerIdentityLinkState linkState = PlayerIdentityLinkState.idle;
  Map<String, Object?>? linkRequest;

  bool get connected => player?.provider != null;
  bool get guest => player?.guest ?? true;

  @visibleForTesting
  void setTestState({
    KolkhozPlayerIdentity? identity,
    PlayerIdentityLinkState state = PlayerIdentityLinkState.idle,
    String? statusMessage,
  }) {
    player = identity;
    linkState = state;
    message = statusMessage;
    notifyListeners();
  }

  Future<void> start({
    required Uri baseURL,
    required String installationID,
    required String displayName,
    String? legacyAccessToken,
  }) async {
    _baseURL = baseURL;
    _installationID = installationID;
    final storedIdentityToken = await _storage.read(key: _tokenKey);
    accessToken = playerIdentityBootstrapToken(
      storedIdentityToken: storedIdentityToken,
      legacyAccessToken: legacyAccessToken,
    );
    _usingLegacySession = legacyAccessToken != null;
    notifyListeners();
    await authenticate(displayName: displayName);
  }

  Future<void> authenticate({required String displayName}) async {
    if (_baseURL == null || _installationID == null || busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      Map<String, Object?>? credential;
      String? provider;
      if (Platform.isIOS || Platform.isMacOS) {
        provider = 'game_center';
        _platformAuthenticationAttempts += 1;
        credential = (await _channel.invokeMapMethod<String, Object?>(
          'authenticateGameCenter',
        ));
      } else if (Platform.isAndroid) {
        provider = 'play_games';
        _platformAuthenticationAttempts += 1;
        credential = (await _channel.invokeMapMethod<String, Object?>(
          'authenticatePlayGames',
        ));
      }
      if (credential == null || provider == null) {
        if (provider != null && _schedulePlatformRetry(displayName)) {
          message =
              'Your existing Kolkhoz account remains active. Retrying platform authentication…';
          return;
        }
        if (_usingLegacySession) {
          message =
              'Your existing Kolkhoz account remains active. Platform authentication is unavailable.';
          return;
        }
      }
      final response = credential == null || provider == null
          ? await _post('identity/guest', {
              'installationID': _installationID,
              'displayName': displayName,
            })
          : await _post('identity/platform/$provider', {
              'credential': credential,
              'displayName': displayName,
            });
      await _acceptSession(response);
      message = player!.guest
          ? 'Guest progress may be lost if this app is deleted or this device is replaced.'
          : 'Progress is synchronized through ${provider == 'game_center' ? 'Game Center' : 'Google Play Games'}.';
    } on PlatformException catch (error) {
      message = error.message ?? 'Platform authentication is unavailable.';
      if (_schedulePlatformRetry(displayName)) return;
      if (_usingLegacySession) return;
      final response = await _post('identity/guest', {
        'installationID': _installationID,
        'displayName': displayName,
      });
      await _acceptSession(response);
    } catch (error) {
      message = '$error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> createLink() async {
    linkRequest = await _post('identity/device-links', const {});
    linkState = PlayerIdentityLinkState.pending;
    notifyListeners();
  }

  Future<void> pollLink() async {
    final requestID = linkRequest?['requestID'];
    if (requestID == null) return;
    try {
      linkRequest = await _get('identity/device-links/$requestID');
      if (linkRequest!['accessToken'] is String) {
        await _acceptSession(linkRequest!);
      }
      linkState = _state('${linkRequest!['status']}');
    } catch (error) {
      message = '$error';
      linkState = PlayerIdentityLinkState.error;
    }
    notifyListeners();
  }

  Future<void> cancelLink() async {
    final requestID = linkRequest?['requestID'];
    if (requestID == null) return;
    linkRequest = await _delete('identity/device-links/$requestID');
    linkState = PlayerIdentityLinkState.cancelled;
    notifyListeners();
  }

  Future<Map<String, Object?>> redeem(String raw) async {
    final code = Uri.tryParse(raw)?.queryParameters['code'] ?? raw;
    final result = await _post('identity/device-links/redeem', {'code': code});
    linkRequest = result;
    linkState = PlayerIdentityLinkState.targetConfirmed;
    notifyListeners();
    return result;
  }

  Future<void> approveLink() async {
    final requestID = linkRequest?['requestID'];
    if (requestID == null) return;
    final result = await _post(
      'identity/device-links/$requestID/approve',
      const {},
    );
    if (result['accessToken'] is String) await _acceptSession(result);
    linkRequest = result;
    linkState = PlayerIdentityLinkState.approved;
    notifyListeners();
  }

  Future<void> clear() async {
    accessToken = null;
    player = null;
    _usingLegacySession = false;
    _platformAuthenticationAttempts = 0;
    _platformRetryScheduled = false;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<void> _acceptSession(Map<String, Object?> response) async {
    final token = response['accessToken'] as String;
    final raw = Map<String, Object?>.from(response['player'] as Map);
    accessToken = token;
    _usingLegacySession = false;
    _platformAuthenticationAttempts = 0;
    _platformRetryScheduled = false;
    player = KolkhozPlayerIdentity(
      id: raw['id'] as String,
      displayName: raw['displayName'] as String? ?? 'Comrade',
      guest: raw['guest'] as bool? ?? false,
      provider: raw['provider'] as String?,
    );
    await _storage.write(key: _tokenKey, value: token);
  }

  bool _schedulePlatformRetry(String displayName) {
    if (_platformRetryScheduled ||
        !shouldRetryPlatformAuthentication(_platformAuthenticationAttempts)) {
      return false;
    }
    _platformRetryScheduled = true;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        _platformRetryScheduled = false;
        await authenticate(displayName: displayName);
      }),
    );
    return true;
  }

  Future<Map<String, Object?>> _get(String path) => _request('GET', path);
  Future<Map<String, Object?>> _delete(String path) => _request('DELETE', path);
  Future<Map<String, Object?>> _post(String path, Map<String, Object?> body) =>
      _request('POST', path, body: body);

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, _baseURL!.resolve(path));
      request.headers.contentType = ContentType.json;
      request.headers.set('X-Kolkhoz-Device-ID', _installationID!);
      if (accessToken != null) {
        request.headers.set('Authorization', 'Bearer $accessToken');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final decoded = jsonDecode(await utf8.decoder.bind(response).join());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          decoded is Map ? '${decoded['error']}' : 'Identity request failed',
        );
      }
      return Map<String, Object?>.from(decoded as Map);
    } finally {
      client.close(force: true);
    }
  }

  static PlayerIdentityLinkState _state(String value) => switch (value) {
    'pending' => PlayerIdentityLinkState.pending,
    'target_confirmed' => PlayerIdentityLinkState.targetConfirmed,
    'approved' => PlayerIdentityLinkState.approved,
    'expired' => PlayerIdentityLinkState.expired,
    'cancelled' => PlayerIdentityLinkState.cancelled,
    'conflict' => PlayerIdentityLinkState.conflict,
    _ => PlayerIdentityLinkState.error,
  };
}

class PlayerIdentityPanel extends StatelessWidget {
  const PlayerIdentityPanel({
    super.key,
    required this.tokens,
    required this.displayName,
    required this.onDeleteAccount,
  });

  final DesignTokens tokens;
  final String displayName;
  final Future<void> Function()? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final runtime = KolkhozIdentityRuntime.instance;
    return AnimatedBuilder(
      animation: runtime,
      builder: (context, _) {
        final player = runtime.player;
        final provider = player?.provider;
        return Column(
          key: const Key('passwordless-account-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              'ACCOUNT',
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.colors.black.withValues(alpha: 0.24),
                border: Border.all(
                  color: tokens.colors.gold.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(tokens.radius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 5,
                children: [
                  Text(
                    player?.displayName ?? displayName,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.goldBright,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    player == null ? 'CONNECTING…' : 'KOLKHOZ ID  ${player.id}',
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.creamDim,
                    ),
                  ),
                  Text(
                    provider == 'game_center'
                        ? 'GAME CENTER — CONNECTED'
                        : provider == 'play_games'
                        ? 'GOOGLE PLAY GAMES — CONNECTED'
                        : 'GUEST — LOCAL DEVICE ONLY',
                    key: Key(provider ?? 'guest-identity-state'),
                    style: kolkhozFontStyle.copyWith(
                      color: provider == null
                          ? Colors.orange.shade200
                          : tokens.colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    runtime.message ?? 'Cloud synchronization is starting.',
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.creamDim,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  key: const Key('enter-device-link-code'),
                  width: 178,
                  height: 42,
                  child: ChromeAssetButton.command(
                    label: 'ENTER LINK CODE',
                    prominent: false,
                    tokens: tokens,
                    onPressed: runtime.busy
                        ? null
                        : () => _showRedeem(context, runtime),
                  ),
                ),
                SizedBox(
                  key: const Key('link-another-device'),
                  width: 206,
                  height: 42,
                  child: ChromeAssetButton.command(
                    label: 'LINK ANOTHER DEVICE',
                    prominent: true,
                    tokens: tokens,
                    onPressed: runtime.busy || player == null
                        ? null
                        : () async {
                            await runtime.createLink();
                            if (context.mounted) {
                              await _showSource(context, runtime);
                            }
                          },
                  ),
                ),
                TextButton(
                  onPressed: runtime.busy || onDeleteAccount == null
                      ? null
                      : () => _confirmDelete(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade300,
                  ),
                  child: const Text('DELETE ACCOUNT'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.colors.panel,
        title: const Text('DELETE YOUR ACCOUNT?'),
        content: const Text(
          'This permanently removes linked identities, profile data, online history, '
          'and synchronized progress. Purchases and histories are not transferred.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
            child: const Text('DELETE ACCOUNT'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDeleteAccount?.call();
  }

  Future<void> _showSource(
    BuildContext context,
    KolkhozIdentityRuntime runtime,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.colors.panel,
        title: const Text('LINK ANOTHER DEVICE'),
        content: AnimatedBuilder(
          animation: runtime,
          builder: (context, _) {
            final value = runtime.linkRequest ?? const <String, Object?>{};
            final qr = value['qrPayload'] as String?;
            return SizedBox(
              width: 330,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  if (qr != null)
                    ColoredBox(
                      color: Colors.white,
                      child: QrImageView(data: qr, size: 190),
                    ),
                  SelectableText(
                    '${value['code'] ?? ''}',
                    key: const Key('device-link-readable-code'),
                    style: kolkhozFontStyle.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('STATUS — ${runtime.linkState.name.toUpperCase()}'),
                  if (runtime.linkState ==
                      PlayerIdentityLinkState.targetConfirmed)
                    const Text(
                      'The other device is ready. Confirm to retain this profile.',
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: runtime.pollLink, child: const Text('REFRESH')),
          TextButton(
            onPressed: runtime.cancelLink,
            child: const Text('CANCEL LINK'),
          ),
          AnimatedBuilder(
            animation: runtime,
            builder: (context, _) => TextButton(
              onPressed:
                  runtime.linkState == PlayerIdentityLinkState.targetConfirmed
                  ? runtime.approveLink
                  : null,
              child: const Text('APPROVE LINK'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRedeem(
    BuildContext context,
    KolkhozIdentityRuntime runtime,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.colors.panel,
        title: const Text('ENTER OR SCAN LINK CODE'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              TextField(
                key: const Key('device-link-code-field'),
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'ABC-123'),
              ),
              SizedBox(
                height: 180,
                child: MobileScanner(
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null) controller.text = value;
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final preview = await runtime.redeem(controller.text);
              if (!context.mounted) return;
              final source = Map<String, Object?>.from(
                preview['source'] as Map,
              );
              final target = Map<String, Object?>.from(
                preview['target'] as Map,
              );
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('CONFIRM DEVICE LINK'),
                  content: Text(
                    'Keep ${source['displayName']} (${source['id']}) and connect '
                    '${target['displayName']} (${target['provider']})? No histories are merged.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('BACK'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('CONFIRM'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                Navigator.pop(context);
                await _showTargetWait(context, runtime);
              }
            },
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showTargetWait(
    BuildContext context,
    KolkhozIdentityRuntime runtime,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.colors.panel,
        title: const Text('WAITING FOR SOURCE DEVICE'),
        content: AnimatedBuilder(
          animation: runtime,
          builder: (context, _) => Text(
            runtime.linkState == PlayerIdentityLinkState.approved
                ? 'LINK COMPLETE — THIS DEVICE NOW USES ${runtime.player?.displayName ?? 'THE SOURCE PROFILE'}.'
                : runtime.linkState == PlayerIdentityLinkState.conflict
                ? 'THE PROFILES CANNOT BE COMBINED. NO DATA WAS CHANGED.'
                : 'Approve the link on the source device, then check again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: runtime.pollLink,
            child: const Text('CHECK APPROVAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
