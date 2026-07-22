import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import '../../remote_connection/remote_connection.dart';
import '../../remote_connection/remote_error.dart';

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
bool shouldMigrateLegacySession({
  required String? storedIdentityToken,
  required String? legacyAccessToken,
  required bool migrationCompleted,
}) =>
    legacyAccessToken != null &&
    legacyAccessToken.isNotEmpty &&
    (!migrationCompleted || storedIdentityToken == null);

@visibleForTesting
bool shouldRetryPlatformAuthentication(int completedAttempts) =>
    completedAttempts < 3;

@visibleForTesting
bool shouldRetryPlatformAuthenticationError(
  int completedAttempts,
  String errorCode,
) =>
    errorCode != 'game_center_timeout' &&
    shouldRetryPlatformAuthentication(completedAttempts);

@immutable
class KolkhozPlayerIdentity {
  const KolkhozPlayerIdentity({
    required this.id,
    required this.displayName,
    required this.guest,
    required this.portable,
    this.provider,
    this.recoveryEmail,
  });

  final String id;
  final String displayName;
  final bool guest;
  final bool portable;
  final String? provider;
  final String? recoveryEmail;
}

class KolkhozIdentityRuntime extends ChangeNotifier {
  KolkhozIdentityRuntime._();

  static final instance = KolkhozIdentityRuntime._();
  static const _channel = MethodChannel('com.williamtheisen.kolkhoz/identity');
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'kolkhoz.player.session';
  static const _legacyMigrationKey = 'kolkhoz.player.legacy-migrated';

  RemoteConnection? _remoteConnection;
  String? _installationID;
  int _platformAuthenticationAttempts = 0;
  bool _platformRetryScheduled = false;
  String? accessToken;
  KolkhozPlayerIdentity? player;
  bool busy = false;
  String? message;
  PlayerIdentityLinkState linkState = PlayerIdentityLinkState.idle;
  Map<String, Object?>? linkRequest;

  @visibleForTesting
  void setTestState({
    KolkhozPlayerIdentity? identity,
    PlayerIdentityLinkState state = PlayerIdentityLinkState.idle,
    String? statusMessage,
    bool? busyState,
  }) {
    player = identity;
    linkState = state;
    message = statusMessage;
    if (busyState != null) busy = busyState;
    notifyListeners();
  }

  void updateDisplayName(String displayName) {
    final current = player;
    if (current == null || current.displayName == displayName) return;
    player = KolkhozPlayerIdentity(
      id: current.id,
      displayName: displayName,
      guest: current.guest,
      portable: current.portable,
      provider: current.provider,
      recoveryEmail: current.recoveryEmail,
    );
    notifyListeners();
  }

  Future<void> start({
    required RemoteConnection remoteConnection,
    required String installationID,
    required String displayName,
    String? legacyAccessToken,
  }) async {
    _installationID = installationID;
    _remoteConnection = remoteConnection;
    final storedIdentityToken = await _storage.read(key: _tokenKey);
    final migrationCompleted =
        await _storage.read(key: _legacyMigrationKey) == 'true';
    final migrateLegacy = shouldMigrateLegacySession(
      storedIdentityToken: storedIdentityToken,
      legacyAccessToken: legacyAccessToken,
      migrationCompleted: migrationCompleted,
    );
    accessToken = migrateLegacy ? legacyAccessToken : storedIdentityToken;
    notifyListeners();
    if (migrateLegacy) {
      await migrateLegacySession();
      return;
    }
    await authenticate(displayName: displayName);
  }

  Future<void> migrateLegacySession() async {
    if (_remoteConnection == null || _installationID == null || busy) return;
    busy = true;
    message = 'Moving your existing Kolkhoz account to the new login system…';
    notifyListeners();
    try {
      final response = await _remoteConnection!.requestJson(
        method: 'POST',
        path: 'identity/legacy',
        body: {'installationID': _installationID},
      );
      await _acceptSession(response);
      await _storage.write(key: _legacyMigrationKey, value: 'true');
      message = 'Your existing Kolkhoz account is ready on this device.';
    } on RemoteRequestException catch (error) {
      message =
          'Your existing account is safe, but could not be moved yet. ${error.message}';
    } catch (_) {
      message = 'Your existing account is safe, but could not be moved yet.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> authenticate({required String displayName}) async {
    if (_remoteConnection == null || _installationID == null || busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      Map<String, Object?>? credential;
      String? provider;
      if (Platform.isIOS || Platform.isMacOS) {
        provider = 'game_center';
        _platformAuthenticationAttempts += 1;
        credential = await _channel
            .invokeMapMethod<String, Object?>('authenticateGameCenter')
            .timeout(const Duration(seconds: 35));
      } else if (Platform.isAndroid) {
        provider = 'play_games';
        _platformAuthenticationAttempts += 1;
        credential = await _channel
            .invokeMapMethod<String, Object?>('authenticatePlayGames')
            .timeout(const Duration(seconds: 35));
      }
      if (credential == null || provider == null) {
        if (provider != null && _schedulePlatformRetry(displayName)) {
          message =
              'Your existing Kolkhoz account remains active. Retrying platform authentication…';
          return;
        }
      }
      final response = credential == null || provider == null
          ? await _remoteConnection!.requestJson(
              method: 'POST',
              path: 'identity/guest',
              body: {
                'installationID': _installationID,
                'displayName': displayName,
              },
            )
          : await _remoteConnection!.requestJson(
              method: 'POST',
              path: 'identity/platform/$provider',
              body: {'credential': credential, 'displayName': displayName},
            );
      await _acceptSession(response);
      message = player!.guest
          ? 'Guest progress may be lost if this app is deleted or this device is replaced.'
          : 'Progress is synchronized through ${provider == 'game_center' ? 'Game Center' : 'Google Play Games'}.';
    } on PlatformException catch (error) {
      message = error.message ?? 'Platform authentication is unavailable.';
      if (shouldRetryPlatformAuthenticationError(
            _platformAuthenticationAttempts,
            error.code,
          ) &&
          _schedulePlatformRetry(displayName)) {
        return;
      }
      final response = await _remoteConnection!.requestJson(
        method: 'POST',
        path: 'identity/guest',
        body: {'installationID': _installationID, 'displayName': displayName},
      );
      await _acceptSession(response);
    } on TimeoutException {
      message = 'Platform authentication timed out.';
      final response = await _remoteConnection!.requestJson(
        method: 'POST',
        path: 'identity/guest',
        body: {'installationID': _installationID, 'displayName': displayName},
      );
      await _acceptSession(response);
    } on RemoteRequestException catch (error) {
      message = error.message;
    } catch (error) {
      message = '$error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> createLink() async {
    linkRequest = await _remoteConnection!.requestJson(
      method: 'POST',
      path: 'identity/device-links',
      body: const {},
    );
    linkState = PlayerIdentityLinkState.pending;
    notifyListeners();
  }

  Future<void> pollLink() async {
    final requestID = linkRequest?['requestID'];
    if (requestID == null) return;
    try {
      linkRequest = await _remoteConnection!.requestJson(
        method: 'GET',
        path: 'identity/device-links/$requestID',
      );
      if (linkRequest!['accessToken'] is String) {
        await _acceptSession(linkRequest!);
      }
      linkState = _state('${linkRequest!['status']}');
    } on RemoteRequestException catch (error) {
      message = error.message;
      linkState = PlayerIdentityLinkState.error;
    } catch (error) {
      message = '$error';
      linkState = PlayerIdentityLinkState.error;
    }
    notifyListeners();
  }

  Future<void> cancelLink() async {
    final requestID = linkRequest?['requestID'];
    if (requestID == null) return;
    linkRequest = await _remoteConnection!.requestJson(
      method: 'DELETE',
      path: 'identity/device-links/$requestID',
    );
    linkState = PlayerIdentityLinkState.cancelled;
    notifyListeners();
  }

  Future<Map<String, Object?>> redeem(String raw) async {
    final code = Uri.tryParse(raw)?.queryParameters['code'] ?? raw;
    final result = await _remoteConnection!.requestJson(
      method: 'POST',
      path: 'identity/device-links/redeem',
      body: {'code': code},
    );
    linkRequest = result;
    linkState = PlayerIdentityLinkState.targetConfirmed;
    notifyListeners();
    return result;
  }

  Future<void> approveLink() async {
    final requestID = linkRequest?['requestID'];
    if (requestID == null) return;
    final result = await _remoteConnection!.requestJson(
      method: 'POST',
      path: 'identity/device-links/$requestID/approve',
      body: const {},
    );
    if (result['accessToken'] is String) await _acceptSession(result);
    linkRequest = result;
    linkState = PlayerIdentityLinkState.approved;
    notifyListeners();
  }

  Future<bool> requestEmailCode(String email) async {
    if (_remoteConnection == null || busy) return false;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await _remoteConnection!.requestJson(
        method: 'POST',
        path: 'identity/email/code',
        body: {'email': email.trim()},
      );
      message = 'A six-digit Kolkhoz verification code was sent to your email.';
      return true;
    } on RemoteRequestException catch (error) {
      message = error.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmailCode(String email, String code) async {
    if (_remoteConnection == null || busy) return false;
    busy = true;
    message = null;
    notifyListeners();
    try {
      final response = await _remoteConnection!.requestJson(
        method: 'POST',
        path: 'identity/email/verify',
        body: {'email': email.trim(), 'code': code.trim()},
      );
      await _acceptSession(response);
      message = response['emailAction'] == 'existing_account_linked'
          ? 'Existing Kolkhoz account linked. The temporary guest profile was discarded.'
          : 'This account can now be used on another device.';
      return true;
    } on RemoteRequestException catch (error) {
      message = error.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    accessToken = null;
    player = null;
    _platformAuthenticationAttempts = 0;
    _platformRetryScheduled = false;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<void> _acceptSession(Map<String, Object?> response) async {
    final token = response['accessToken'] as String;
    final raw = jsonObject(response['player']);
    accessToken = token;
    _platformAuthenticationAttempts = 0;
    _platformRetryScheduled = false;
    player = KolkhozPlayerIdentity(
      id: raw['id'] as String,
      displayName: raw['displayName'] as String? ?? 'Comrade',
      guest: raw['guest'] as bool? ?? false,
      portable: raw['portable'] as bool? ?? !(raw['guest'] as bool? ?? false),
      provider: raw['provider'] as String?,
      recoveryEmail: raw['recoveryEmail'] as String?,
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
                        : player?.recoveryEmail != null
                        ? 'RECOVERY EMAIL — VERIFIED'
                        : 'DEVICE-ONLY GUEST',
                    key: Key(provider ?? 'guest-identity-state'),
                    style: kolkhozFontStyle.copyWith(
                      color: provider == null
                          ? Colors.orange.shade200
                          : tokens.colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    runtime.message ??
                        (player?.portable == false
                            ? 'This account cannot be recovered and is tied to this device. Add a recovery email to protect it.'
                            : 'Your Kolkhoz account can be used on another device.'),
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.creamDim,
                    ),
                  ),
                ],
              ),
            ),
            if (player != null)
              _RecoveryEmailControls(tokens: tokens, runtime: runtime),
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
                    onPressed: () => _showRedeem(context, runtime),
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
                decoration: const InputDecoration(labelText: 'ABCD-EFGH-JKLM'),
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
              final source = jsonObject(preview['source']);
              final target = jsonObject(preview['target']);
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

class _RecoveryEmailControls extends StatefulWidget {
  const _RecoveryEmailControls({required this.tokens, required this.runtime});

  final DesignTokens tokens;
  final KolkhozIdentityRuntime runtime;

  @override
  State<_RecoveryEmailControls> createState() => _RecoveryEmailControlsState();
}

class _RecoveryEmailControlsState extends State<_RecoveryEmailControls> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  bool codeSent = false;

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.runtime.player?.recoveryEmail;
    if (verified != null) {
      return Text(
        'RECOVERY EMAIL  $verified',
        key: const Key('verified-recovery-email'),
        style: kolkhozFontStyle.copyWith(color: widget.tokens.colors.creamDim),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        TextField(
          key: const Key('recovery-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'RECOVERY EMAIL'),
        ),
        if (codeSent)
          TextField(
            key: const Key('recovery-code-field'),
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'SIX-DIGIT LOGIN CODE',
              counterText: '',
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            height: 42,
            child: ChromeAssetButton.command(
              label: codeSent ? 'VERIFY EMAIL' : 'ADD RECOVERY EMAIL',
              prominent: true,
              tokens: widget.tokens,
              onPressed: widget.runtime.busy
                  ? null
                  : () async {
                      if (!codeSent) {
                        final sent = await widget.runtime.requestEmailCode(
                          emailController.text,
                        );
                        if (mounted && sent) setState(() => codeSent = true);
                        return;
                      }
                      await widget.runtime.verifyEmailCode(
                        emailController.text,
                        codeController.text,
                      );
                    },
            ),
          ),
        ),
      ],
    );
  }
}
