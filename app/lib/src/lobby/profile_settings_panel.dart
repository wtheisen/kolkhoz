part of '../kolkhoz_app.dart';

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({
    required this.tokens,
    required this.language,
    required this.onTutorialPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onTutorialPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              final twoColumn = contentWidth >= 560;
              final ruleWidth = twoColumn
                  ? (contentWidth - 12) / 2
                  : contentWidth;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        const _AssetIcon(
                          'assets/ui/Icons/icon-rules-scroll.png',
                          size: 30,
                        ),
                        Text(
                          language.t(KolkhozText.kolkhozappHowToPlay),
                          style: kolkhozFontStyle.copyWith(
                            color: tokens.colors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Image.asset(
                        'assets/ui/Embellishments/art-rules-divider.png',
                        height: 48,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final rule in lobbyRuleSummaries)
                          SizedBox(
                            width: ruleWidth,
                            child: _RuleBlock(
                              tokens: tokens,
                              title: rule.title(language),
                              body: rule.body(language),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            height: 44,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappTutorial),
              prominent: true,
              tokens: tokens,
              onPressed: onTutorialPressed,
              iconAsset: 'assets/ui/Icons/icon-foreman-misha.png',
              iconSize: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel({
    required this.tokens,
    required this.language,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  late final TextEditingController displayNameController;
  late String lastSubmittedName;

  @override
  void initState() {
    super.initState();
    lastSubmittedName = widget.displayName;
    displayNameController = TextEditingController(text: widget.displayName);
    displayNameController.addListener(notifyDisplayNameChanged);
  }

  @override
  void didUpdateWidget(covariant _ProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.displayName != lastSubmittedName &&
        widget.displayName != displayNameController.text) {
      displayNameController.text = widget.displayName;
      lastSubmittedName = widget.displayName;
    }
  }

  @override
  void dispose() {
    displayNameController.removeListener(notifyDisplayNameChanged);
    displayNameController.dispose();
    super.dispose();
  }

  void notifyDisplayNameChanged() {
    final next = displayNameController.text;
    if (next == lastSubmittedName) {
      return;
    }
    lastSubmittedName = next;
    widget.onDisplayNameChanged?.call(next);
  }

  Future<void> showPortraitPicker() async {
    if (widget.onPortraitChanged == null) {
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.tokens.colors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.tokens.colors.gold.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tokens.colors.black.withValues(alpha: 0.42),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final asset in profilePortraitAssets)
                _ProfilePortraitChoice(
                  tokens: widget.tokens,
                  asset: asset,
                  selected: widget.portraitAsset == asset,
                  unlocked: isProfilePortraitUnlocked(
                    widget.progression,
                    asset,
                  ),
                  onPressed:
                      isProfilePortraitUnlocked(widget.progression, asset)
                      ? () => Navigator.of(context).pop(asset)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != widget.portraitAsset) {
      widget.onPortraitChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (widget.cloudSignedIn) ...[
                  _ProfilePreview(
                    tokens: widget.tokens,
                    controller: displayNameController,
                    portraitAsset: widget.portraitAsset,
                    onPortraitPressed: widget.onPortraitChanged == null
                        ? null
                        : showPortraitPicker,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Text(
                        widget.language.t(KolkhozText.kolkhozappStats),
                        style: kolkhozFontStyle.copyWith(
                          color: widget.tokens.colors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnCount = constraints.maxWidth >= 520
                              ? 3
                              : 1;
                          return PlayerProfileStatsGrid(
                            tokens: widget.tokens,
                            groups: kolkhozProfileStatGroups(
                              stats: widget.profileStats,
                              language: widget.language,
                            ),
                            columnsForWidth: (_) => columnCount,
                          );
                        },
                      ),
                    ],
                  ),
                ],
                _CloudAuthPanel(
                  tokens: widget.tokens,
                  language: widget.language,
                  configured: widget.cloudConfigured,
                  ready: widget.cloudReady,
                  signedIn: widget.cloudSignedIn,
                  email: widget.cloudEmail,
                  busy: widget.cloudAuthBusy,
                  message: widget.cloudAuthMessage,
                  messageIsError: widget.cloudAuthIsError,
                  onSignIn: widget.onCloudSignIn,
                  onSignUp: widget.onCloudSignUp,
                  onResetPassword: widget.onCloudResetPassword,
                  onSignOut: widget.onCloudSignOut,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CloudAuthPanel extends StatefulWidget {
  const _CloudAuthPanel({
    required this.tokens,
    required this.language,
    required this.configured,
    required this.ready,
    required this.signedIn,
    required this.email,
    required this.busy,
    required this.message,
    required this.messageIsError,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
    required this.onSignOut,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool configured;
  final bool ready;
  final bool signedIn;
  final String? email;
  final bool busy;
  final String? message;
  final bool messageIsError;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onResetPassword;
  final Future<void> Function()? onSignOut;

  @override
  State<_CloudAuthPanel> createState() => _CloudAuthPanelState();
}

class _CloudAuthPanelState extends State<_CloudAuthPanel> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;
  String? localMessage;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void clearLocalMessage() {
    if (localMessage == null) {
      return;
    }
    setState(() => localMessage = null);
  }

  void submitSignUp() {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    if (password != confirmPassword) {
      setState(() {
        localMessage = widget.language.t(
          KolkhozText.kolkhozappPasswordsDoNotMatch,
        );
      });
      return;
    }
    clearLocalMessage();
    widget.onSignUp?.call(emailController.text, password);
  }

  @override
  Widget build(BuildContext context) {
    final status = !widget.configured
        ? widget.language.t(
            KolkhozText.kolkhozappCloudProfilesAreNotConfiguredForThisBuild,
          )
        : !widget.ready
        ? widget.language.t(KolkhozText.kolkhozappCloudProfilesAreStarting)
        : widget.signedIn
        ? widget.language.t(KolkhozText.kolkhozappSignedInAsValue1, {
            'value1': widget.email ?? 'player',
            'value2': widget.email ?? 'игрок',
          })
        : widget.language.t(
            KolkhozText.kolkhozappSignInToSyncProfileAndOnlineSeats,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          widget.language.t(KolkhozText.kolkhozappAccount),
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.configured && widget.ready && widget.signedIn)
          _SignedInAccountRow(
            tokens: widget.tokens,
            status: status,
            signOutLabel: widget.busy
                ? widget.language.t(KolkhozText.kolkhozappWorking)
                : widget.language.t(KolkhozText.kolkhozappSignOut),
            onSignOut: widget.busy || widget.onSignOut == null
                ? null
                : widget.onSignOut,
          )
        else
          _VariantRowBackground(
            tokens: widget.tokens,
            active: false,
            child: Text(
              status,
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.creamDim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (widget.message != null &&
            (!widget.signedIn || widget.messageIsError))
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: widget.message!,
            isError: widget.messageIsError,
          ),
        if (widget.configured &&
            widget.ready &&
            !widget.signedIn &&
            localMessage != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: localMessage!,
            isError: true,
          ),
        if (widget.configured && widget.ready && !widget.signedIn) ...[
          _ProfileTextField(
            tokens: widget.tokens,
            controller: emailController,
            label: widget.language.t(KolkhozText.kolkhozappEmail),
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: passwordController,
            label: widget.language.t(KolkhozText.kolkhozappPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: confirmPasswordController,
            label: widget.language.t(KolkhozText.kolkhozappConfirmPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.busy
                      ? widget.language.t(KolkhozText.kolkhozappWorking)
                      : widget.language.t(KolkhozText.kolkhozappSignIn),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignIn == null
                      ? null
                      : () {
                          clearLocalMessage();
                          widget.onSignIn!(
                            emailController.text,
                            passwordController.text,
                          );
                        },
                ),
              ),
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappReset),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onResetPassword == null
                      ? null
                      : () {
                          clearLocalMessage();
                          widget.onResetPassword!(emailController.text);
                        },
                ),
              ),
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappCreate),
                  prominent: true,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignUp == null
                      ? null
                      : submitSignUp,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SignedInAccountRow extends StatelessWidget {
  const _SignedInAccountRow({
    required this.tokens,
    required this.status,
    required this.signOutLabel,
    required this.onSignOut,
  });

  final DesignTokens tokens;
  final String status;
  final String signOutLabel;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: _VariantRowBackground(
            tokens: tokens,
            active: true,
            child: Row(
              spacing: 8,
              children: [
                const _AssetIcon(
                  'assets/ui/Icons/icon-status-connected.png',
                  size: 24,
                ),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.activeSurfaceText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 142,
          height: 42,
          child: ChromeAssetButton.command(
            label: signOutLabel,
            prominent: false,
            tokens: tokens,
            onPressed: onSignOut,
          ),
        ),
      ],
    );
  }
}

class _ComradesSettingsPanel extends StatefulWidget {
  const _ComradesSettingsPanel({
    required this.tokens,
    required this.language,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;

  @override
  State<_ComradesSettingsPanel> createState() => _ComradesSettingsPanelState();
}

class _ComradesSettingsPanelState extends State<_ComradesSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    if (widget.cloudSignedIn) {
      return _ComradesPanel(
        tokens: widget.tokens,
        language: widget.language,
        initialComrades: widget.comradesSummary,
        onComradesChanged: widget.onComradesChanged,
      );
    }

    return SingleChildScrollView(
      child: _CloudAuthPanel(
        tokens: widget.tokens,
        language: widget.language,
        configured: widget.cloudConfigured,
        ready: widget.cloudReady,
        signedIn: widget.cloudSignedIn,
        email: widget.cloudEmail,
        busy: widget.cloudAuthBusy,
        message: widget.cloudAuthMessage,
        messageIsError: widget.cloudAuthIsError,
        onSignIn: widget.onCloudSignIn,
        onSignUp: widget.onCloudSignUp,
        onResetPassword: widget.onCloudResetPassword,
        onSignOut: null,
      ),
    );
  }
}

class _ComradesPanel extends StatefulWidget {
  const _ComradesPanel({
    required this.tokens,
    required this.language,
    required this.initialComrades,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradesResponse initialComrades;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;

  @override
  State<_ComradesPanel> createState() => _ComradesPanelState();
}

class _ComradesPanelState extends State<_ComradesPanel> {
  late final TextEditingController codeController;
  bool busy = false;
  String? message;
  bool messageIsError = false;
  OnlineComradesResponse comrades = const OnlineComradesResponse();

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
    comrades = widget.initialComrades;
    unawaited(loadComrades());
  }

  @override
  void didUpdateWidget(covariant _ComradesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialComrades != oldWidget.initialComrades && !busy) {
      comrades = widget.initialComrades;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  KolkhozOnlineClient _client() {
    return KolkhozOnlineClient(
      _onlineServerURL,
      accessTokenProvider: _currentSupabaseAccessToken,
    );
  }

  Future<void> loadComrades() async {
    await runComradeAction(() async {
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
    }, showWorking: false);
  }

  Future<void> addComrade() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    await runComradeAction(() async {
      await _client().sendComradeRequest(code);
      codeController.clear();
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(KolkhozText.kolkhozappComradeRequestSent);
      messageIsError = false;
    });
  }

  Future<void> respondToComradeRequest(String userID, bool accept) async {
    await runComradeAction(() async {
      await _client().respondToComradeRequest(userID: userID, accept: accept);
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(
        accept
            ? KolkhozText.kolkhozappComradeRequestAccepted
            : KolkhozText.kolkhozappComradeRequestDeclined,
      );
      messageIsError = false;
    });
  }

  Future<void> removeComrade(String userID) async {
    await runComradeAction(() async {
      await _client().removeComrade(userID);
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
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
        busy = showWorking;
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
        setState(() => busy = false);
      }
    }
  }

  String _comradeSyncErrorMessage(Object exception) {
    if (exception is OnlineRequestException || exception is SocketException) {
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
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: message!,
            isError: messageIsError,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            const footerControlHeight = 38.0;
            final codeBox = _ComradeCodeDisplayBox(
              tokens: widget.tokens,
              code: code,
              height: footerControlHeight,
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
            final inputBox = _ComradeCodeTextField(
              tokens: widget.tokens,
              controller: codeController,
              hint: widget.language.t(KolkhozText.kolkhozappComradeCode),
              height: footerControlHeight,
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
    return _VariantRowBackground(
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
    return _VariantRowBackground(
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
                  _profileRatingSummary(language, request.stats),
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
    final status = _comradePresenceSummary(language, comrade);
    final statusColor = (comrade.isOnline || comrade.inGame || comrade.inLobby)
        ? tokens.colors.green
        : tokens.colors.cardInk.withValues(alpha: 0.62);
    return _VariantRowBackground(
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
                  '$status / ${_profileRatingSummary(language, comrade.stats)}',
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

String _comradePresenceSummary(
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

String _profileRatingSummary(
  KolkhozLanguage language,
  KolkhozProfileStats stats,
) {
  return '${language.t(KolkhozText.kolkhozappRanked)} ${stats.rating}  '
      '${language.t(KolkhozText.kolkhozappCasual)} ${stats.casualRating}';
}

class _ComradeCodeDisplayBox extends StatelessWidget {
  const _ComradeCodeDisplayBox({
    required this.tokens,
    required this.code,
    required this.height,
  });

  final DesignTokens tokens;
  final String code;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _comradeFooterBoxDecoration(tokens),
      child: SelectableText(
        code,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cardInk,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _ComradeCodeTextField extends StatelessWidget {
  const _ComradeCodeTextField({
    required this.tokens,
    required this.controller,
    required this.hint,
    required this.height,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: _comradeFooterBoxDecoration(tokens),
      child: TextField(
        controller: controller,
        maxLength: 12,
        minLines: 1,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cardInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
        cursorColor: tokens.colors.redDark,
        decoration: InputDecoration(
          hintText: hint.toUpperCase(),
          counterText: '',
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          hintStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.cardInk.withValues(alpha: 0.44),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
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

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({
    required this.tokens,
    required this.controller,
    required this.portraitAsset,
    required this.onPortraitPressed,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String portraitAsset;
  final VoidCallback? onPortraitPressed;

  @override
  Widget build(BuildContext context) {
    return PlayerProfilePanel(
      tokens: tokens,
      displayName: controller.text.trim().isEmpty
          ? defaultProfileDisplayName
          : controller.text.trim(),
      portraitAsset: portraitAsset,
      active: true,
      portraitSelected: true,
      portraitSize: 74,
      minHeight: 94,
      padding: const EdgeInsets.all(10),
      onPortraitPressed: onPortraitPressed,
      portraitSemanticsLabel: portraitAsset,
      title: TextField(
        controller: controller,
        maxLength: 24,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 28,
          height: 1.0,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: tokens.colors.goldBright,
        decoration: InputDecoration(
          counterText: '',
          hintText: defaultProfileDisplayName,
          hintStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.74),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.tokens,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.maxLength = 24,
    this.onChanged,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.34)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        maxLength: maxLength,
        onChanged: onChanged,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          labelStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _ProfilePortraitChoice extends StatelessWidget {
  const _ProfilePortraitChoice({
    required this.tokens,
    required this.asset,
    required this.selected,
    required this.unlocked,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String asset;
  final bool selected;
  final bool unlocked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        label: unlocked ? asset : '$asset (locked)',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.42,
              child: PlayerProfilePortraitImage(
                tokens: tokens,
                asset: asset,
                size: 58,
                selected: selected,
              ),
            ),
            if (!unlocked)
              Image.asset(
                'assets/ui/Icons/icon-lock.png',
                width: 22,
                height: 22,
                filterQuality: FilterQuality.none,
              ),
          ],
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.tokens,
    required this.title,
    required this.body,
  });

  final DesignTokens tokens;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            title.toUpperCase(),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            body,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 15,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: tokens.colors.gold.withValues(alpha: 0.35),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon(this.asset, {this.size = 18, this.opacity = 1});

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
