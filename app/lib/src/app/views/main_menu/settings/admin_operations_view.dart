part of 'settings_view.dart';

class AdminOperationsView extends StatefulWidget {
  const AdminOperationsView({
    super.key,
    required this.tokens,
    required this.remoteConnection,
  });

  final DesignTokens tokens;
  final MenuRemoteConnection? remoteConnection;

  @override
  State<AdminOperationsView> createState() => _AdminOperationsPanelState();
}

class _AdminOperationsPanelState extends State<AdminOperationsView> {
  Map<String, Object?>? value;
  Object? error;
  bool loading = true;
  bool restarting = false;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final connection = widget.remoteConnection;
    if (connection == null) {
      setState(() {
        loading = false;
        error = 'Sign in to view operations.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await connection.fetchAdminOperations();
      if (mounted) setState(() => value = next);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> restart() async {
    final connection = widget.remoteConnection;
    if (connection == null || restarting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart production server?'),
        content: const Text(
          'This restarts only kolkhoz-server.service. Active clients may '
          'briefly reconnect. A five-minute cooldown applies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESTART'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => restarting = true);
    try {
      await connection.restartProductionServer();
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => restarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && value == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADMIN ACCESS REQUIRED',
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
              ),
            ),
            TextButton(onPressed: load, child: const Text('RETRY')),
          ],
        ),
      );
    }
    final operations = value ?? const <String, Object?>{};
    final games = jsonList(operations['games'] ?? const []);
    final suspicious = jsonList(operations['suspiciousGames'] ?? const []);
    final outbox = jsonObject(
      operations['notificationOutbox'] ?? const <String, Object?>{},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PRODUCTION • ${operations['deploymentVersion'] ?? 'unknown'}',
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.goldBright,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(onPressed: load, child: const Text('REFRESH')),
            TextButton(
              onPressed: restarting ? null : restart,
              child: Text(restarting ? 'RESTARTING…' : 'RESTART SERVER'),
            ),
          ],
        ),
        Text(
          'ACTIVE ${games.length}   SUSPICIOUS ${suspicious.length}   '
          'OUTBOX PENDING ${outbox['pending'] ?? 0}   FAILED ${outbox['failed'] ?? 0}',
          style: kolkhozFontStyle.copyWith(color: widget.tokens.colors.cream),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final raw in games)
                Builder(
                  builder: (_) {
                    final game = jsonObject(raw);
                    return ListTile(
                      dense: true,
                      title: Text('${game['sessionID']}'),
                      subtitle: Text(
                        'PHASE ${game['phase']} • ACTOR ${game['currentActor'] ?? '—'} • '
                        '${game['expectedActor'] ?? '—'} • '
                        '${(game['lastActionAgeSeconds'] as num?)?.round() ?? 0}s',
                      ),
                      trailing: game['suspicious'] == true
                          ? const Text('STUCK?')
                          : null,
                    );
                  },
                ),
              const Divider(),
              Text('AI CANARY  ${operations['aiCanary']}'),
              Text('BACKUP  ${operations['backup']}'),
              Text('WATCHDOG  ${operations['watchdog']}'),
              Text('RECENT ERRORS  ${operations['recentServerErrors']}'),
              Text('OUTBOX FAILURES  ${outbox['failures']}'),
            ],
          ),
        ),
      ],
    );
  }
}
