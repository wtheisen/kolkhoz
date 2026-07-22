part of 'settings_view.dart';

class ComradesView extends StatefulWidget {
  const ComradesView({
    super.key,
    required this.tokens,
    required this.language,
    required this.profileController,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ProfileController? profileController;

  @override
  State<ComradesView> createState() => _ComradesPanelState();
}

class _ComradesPanelState extends State<ComradesView> {
  late final TextEditingController codeController;
  bool actionBusy = false;
  String? message;
  bool messageIsError = false;

  OnlineComradesResponse get comrades =>
      widget.profileController?.comrades ?? const OnlineComradesResponse();
  bool get busy =>
      actionBusy || (widget.profileController?.comradesBusy ?? false);

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
    widget.profileController?.addListener(_handleProfileChanged);
    unawaited(loadComrades());
  }

  @override
  void didUpdateWidget(covariant ComradesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileController == oldWidget.profileController) return;
    oldWidget.profileController?.removeListener(_handleProfileChanged);
    widget.profileController?.addListener(_handleProfileChanged);
    unawaited(loadComrades());
  }

  @override
  void dispose() {
    widget.profileController?.removeListener(_handleProfileChanged);
    codeController.dispose();
    super.dispose();
  }

  void _handleProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> loadComrades() async {
    final connection = widget.profileController;
    if (connection == null) return;
    await runComradeAction(connection.refreshComrades, showWorking: false);
  }

  Future<void> addComrade() async {
    final connection = widget.profileController;
    if (connection == null) return;
    final code = codeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    await runComradeAction(() async {
      await connection.sendComradeRequest(code);
      codeController.clear();
      message = widget.language.t(KolkhozText.kolkhozappComradeRequestSent);
      messageIsError = false;
    });
  }

  Future<void> respondToComradeRequest(String userID, bool accept) async {
    final connection = widget.profileController;
    if (connection == null) return;
    await runComradeAction(() async {
      await connection.respondToComradeRequest(userID: userID, accept: accept);
      message = widget.language.t(
        accept
            ? KolkhozText.kolkhozappComradeRequestAccepted
            : KolkhozText.kolkhozappComradeRequestDeclined,
      );
      messageIsError = false;
    });
  }

  Future<void> removeComrade(String userID) async {
    final connection = widget.profileController;
    if (connection == null) return;
    await runComradeAction(() async {
      await connection.removeComrade(userID);
      message = widget.language.t(KolkhozText.kolkhozappComradeRemoved);
      messageIsError = false;
    });
  }

  Future<void> copyComradeCode() async {
    final code = comrades.comradeCode;
    if (code == null || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    setState(() {
      message = widget.language.t(KolkhozText.kolkhozappCopied);
      messageIsError = false;
    });
  }

  Future<void> runComradeAction(
    Future<void> Function() action, {
    bool showWorking = true,
  }) async {
    if (busy) {
      return;
    }
    if (mounted) {
      setState(() {
        actionBusy = showWorking;
        if (showWorking) {
          message = null;
          messageIsError = false;
        }
      });
    }
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() {
          message = _comradeSyncErrorMessage(exception);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => actionBusy = false);
      }
    }
  }

  String _comradeSyncErrorMessage(Object exception) {
    if (exception is RemoteRequestException || exception is SocketException) {
      return onlineFailureStatusMessage(exception, widget.language);
    }
    return widget.language.t(KolkhozText.kolkhozappProfileSyncFailed);
  }

  @override
  Widget build(BuildContext context) {
    final code = comrades.comradeCode ?? '-----';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                _ComradeSectionTitle(
                  tokens: widget.tokens,
                  label: widget.language.t(KolkhozText.kolkhozappComrades),
                  iconAsset: 'assets/ui/Icons/icon-friends-list.png',
                ),
                if (comrades.comrades.isEmpty)
                  _ComradeEmptyRow(
                    tokens: widget.tokens,
                    label: widget.language.t(KolkhozText.kolkhozappNoComrades),
                  )
                else
                  for (final comrade in comrades.comrades)
                    _ComradeRow(
                      tokens: widget.tokens,
                      language: widget.language,
                      comrade: comrade,
                      busy: busy,
                      onRemove: () => removeComrade(comrade.userID),
                    ),
                const SizedBox(height: 2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final requestColumns = <Widget>[
                      _ComradeRequestColumn(
                        tokens: widget.tokens,
                        language: widget.language,
                        label: widget.language.t(
                          KolkhozText.kolkhozappIncomingRequests,
                        ),
                        iconAsset: 'assets/ui/Icons/icon-add-friend.png',
                        requests: comrades.incomingRequests,
                        busy: busy,
                        incoming: true,
                        onAccept: (request) =>
                            respondToComradeRequest(request.userID, true),
                        onDecline: (request) =>
                            respondToComradeRequest(request.userID, false),
                      ),
                      _ComradeRequestColumn(
                        tokens: widget.tokens,
                        language: widget.language,
                        label: widget.language.t(
                          KolkhozText.kolkhozappOutgoingRequests,
                        ),
                        iconAsset: 'assets/ui/Icons/icon-friends-list.png',
                        requests: comrades.outgoingRequests,
                        busy: busy,
                        incoming: false,
                        onAccept: null,
                        onDecline: null,
                      ),
                    ];
                    if (constraints.maxWidth < 620) {
                      return Column(spacing: 8, children: requestColumns);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        for (final column in requestColumns)
                          Expanded(child: column),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (message != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: message!,
            isError: messageIsError,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            const footerControlHeight = 38.0;
            final codeBox = Container(
              height: footerControlHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: _comradeFooterBoxDecoration(widget.tokens),
              child: SelectableText(
                code,
                maxLines: 1,
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.cardInk,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            );
            final copyButton = SizedBox(
              width: 126,
              height: footerControlHeight,
              child: ChromeAssetButton.command(
                label: widget.language.t(KolkhozText.kolkhozappCopyCode),
                prominent: false,
                tokens: widget.tokens,
                iconAsset: 'assets/ui/Icons/icon-comrade.png',
                expandLabel: false,
                onPressed: comrades.comradeCode == null
                    ? null
                    : copyComradeCode,
              ),
            );
            final inputBox = Container(
              height: footerControlHeight,
              alignment: Alignment.center,
              decoration: _comradeFooterBoxDecoration(widget.tokens),
              child: TextField(
                controller: codeController,
                maxLength: 12,
                minLines: 1,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.cardInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
                cursorColor: widget.tokens.colors.redDark,
                decoration: InputDecoration(
                  hintText: widget.language
                      .t(KolkhozText.kolkhozappComradeCode)
                      .toUpperCase(),
                  counterText: '',
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  hintStyle: kolkhozFontStyle.copyWith(
                    color: widget.tokens.colors.cardInk.withValues(alpha: 0.44),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            );
            final addButton = SizedBox(
              width: 142,
              height: footerControlHeight,
              child: ChromeAssetButton.command(
                label: busy
                    ? widget.language.t(KolkhozText.kolkhozappWorking)
                    : widget.language.t(KolkhozText.kolkhozappAddComrade),
                prominent: true,
                tokens: widget.tokens,
                iconAsset: 'assets/ui/Icons/icon-add-friend.png',
                onPressed: busy ? null : addComrade,
              ),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: codeBox),
                      copyButton,
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: inputBox),
                      addButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              spacing: 8,
              children: [
                Expanded(flex: 2, child: codeBox),
                copyButton,
                Expanded(flex: 3, child: inputBox),
                addButton,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComradeRequestColumn extends StatelessWidget {
  const _ComradeRequestColumn({
    required this.tokens,
    required this.language,
    required this.label,
    required this.iconAsset,
    required this.requests,
    required this.busy,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String label;
  final String iconAsset;
  final List<OnlineComradeProfile> requests;
  final bool busy;
  final bool incoming;
  final ValueChanged<OnlineComradeProfile>? onAccept;
  final ValueChanged<OnlineComradeProfile>? onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _ComradeSectionTitle(
          tokens: tokens,
          label: label,
          iconAsset: iconAsset,
        ),
        if (requests.isEmpty)
          _ComradeEmptyRow(
            tokens: tokens,
            label: language.t(KolkhozText.kolkhozappNoComradeRequests),
          )
        else
          for (final request in requests)
            _ComradeRequestRow(
              tokens: tokens,
              language: language,
              request: request,
              busy: busy,
              incoming: incoming,
              onAccept: onAccept == null ? null : () => onAccept!(request),
              onDecline: onDecline == null ? null : () => onDecline!(request),
            ),
      ],
    );
  }
}

class _ComradeSectionTitle extends StatelessWidget {
  const _ComradeSectionTitle({
    required this.tokens,
    required this.label,
    required this.iconAsset,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        spacing: 6,
        children: [
          Image.asset(
            iconAsset,
            width: 18,
            height: 18,
            filterQuality: FilterQuality.none,
          ),
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComradeEmptyRow extends StatelessWidget {
  const _ComradeEmptyRow({required this.tokens, required this.label});

  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Text(
        label,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.creamDim,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ComradeRequestRow extends StatelessWidget {
  const _ComradeRequestRow({
    required this.tokens,
    required this.language,
    required this.request,
    required this.busy,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradeProfile request;
  final bool busy;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return VariantRowBackground(
      tokens: tokens,
      active: incoming,
      child: Row(
        spacing: 8,
        children: [
          PlayerProfilePortraitImage(
            tokens: tokens,
            asset: request.portraitAsset ?? defaultProfilePortraitAsset,
            size: 42,
            selected: incoming,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  request.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: incoming
                        ? tokens.colors.onAccent
                        : tokens.colors.cardInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  profileRatingSummary(language, request.stats),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color:
                        (incoming
                                ? tokens.colors.onAccent
                                : tokens.colors.cardInk)
                            .withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (incoming) ...[
            _ComradeIconButton(
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-check.png',
              label: language.t(KolkhozText.kolkhozappAccept),
              onPressed: busy ? null : onAccept,
            ),
            _ComradeIconButton(
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-warning.png',
              label: language.t(KolkhozText.kolkhozappDecline),
              onPressed: busy ? null : onDecline,
            ),
          ] else
            Image.asset(
              'assets/ui/Icons/icon-status-connecting.png',
              width: 30,
              height: 30,
              filterQuality: FilterQuality.none,
            ),
        ],
      ),
    );
  }
}

class _ComradeIconButton extends StatelessWidget {
  const _ComradeIconButton({
    required this.tokens,
    required this.iconAsset,
    required this.label,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String iconAsset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 36,
        height: 32,
        child: ChromeAssetButton.command(
          label: '',
          prominent: false,
          tokens: tokens,
          iconAsset: iconAsset,
          iconSize: 22,
          expandLabel: false,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ComradeRow extends StatelessWidget {
  const _ComradeRow({
    required this.tokens,
    required this.language,
    required this.comrade,
    required this.busy,
    required this.onRemove,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradeProfile comrade;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final status = comradePresenceSummary(language, comrade);
    final statusColor = (comrade.isOnline || comrade.inGame || comrade.inLobby)
        ? tokens.colors.green
        : tokens.colors.cardInk.withValues(alpha: 0.62);
    return VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Row(
        spacing: 8,
        children: [
          PlayerProfilePortraitImage(
            tokens: tokens,
            asset: comrade.portraitAsset ?? defaultProfilePortraitAsset,
            size: 42,
            selected: false,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  comrade.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cardInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  '$status / ${profileRatingSummary(language, comrade.stats)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 32,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappRemove),
              prominent: false,
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-warning.png',
              onPressed: busy ? null : onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

String comradePresenceSummary(
  KolkhozLanguage language,
  OnlineComradeProfile comrade,
) {
  if (comrade.inGame) {
    return language.t(KolkhozText.kolkhozappInGame);
  }
  if (comrade.inLobby) {
    return language.t(KolkhozText.kolkhozappInLobby);
  }
  if (comrade.isOnline) {
    return language.t(KolkhozText.kolkhozappOnline);
  }
  return language.t(KolkhozText.kolkhozappOfflineStatus);
}

String profileRatingSummary(
  KolkhozLanguage language,
  KolkhozProfileStats stats,
) {
  return '${language.t(KolkhozText.kolkhozappRanked)} ${stats.rating}  '
      '${language.t(KolkhozText.kolkhozappCasual)} ${stats.casualRating}';
}

BoxDecoration _comradeFooterBoxDecoration(DesignTokens tokens) {
  return BoxDecoration(
    color: tokens.colors.cardFill.withValues(alpha: 0.74),
    borderRadius: BorderRadius.circular(5),
    border: Border.all(
      color: tokens.colors.gold.withValues(alpha: 0.56),
      width: 1,
    ),
  );
}
