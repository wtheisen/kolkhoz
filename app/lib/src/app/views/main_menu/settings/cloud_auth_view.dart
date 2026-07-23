part of 'settings_view.dart';

class CloudAuthView extends StatefulWidget {
  const CloudAuthView({
    super.key,
    required this.tokens,
    required this.language,
    required this.configured,
    required this.ready,
    required this.busy,
    required this.message,
    required this.messageIsError,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool configured;
  final bool ready;
  final bool busy;
  final String? message;
  final bool messageIsError;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onResetPassword;

  @override
  State<CloudAuthView> createState() => _CloudAuthPanelState();
}

class _CloudAuthPanelState extends State<CloudAuthView> {
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
        localMessage = widget.language.strings.kolkhozappPasswordsDoNotMatch;
      });
      return;
    }
    clearLocalMessage();
    widget.onSignUp?.call(emailController.text, password);
  }

  @override
  Widget build(BuildContext context) {
    final status = !widget.configured
        ? widget
              .language
              .strings
              .kolkhozappCloudProfilesAreNotConfiguredForThisBuild
        : !widget.ready
        ? widget.language.strings.kolkhozappCloudProfilesAreStarting
        : widget.language.strings.kolkhozappSignInToSyncProfileAndOnlineSeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          widget.language.strings.kolkhozappAccount,
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        VariantRowBackground(
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
        if (widget.message != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: widget.message!,
            isError: widget.messageIsError,
          ),
        if (widget.configured && widget.ready && localMessage != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: localMessage!,
            isError: true,
          ),
        if (widget.configured && widget.ready) ...[
          _ProfileTextField(
            tokens: widget.tokens,
            controller: emailController,
            label: widget.language.strings.kolkhozappEmail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: maxAccountEmailLength,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: passwordController,
            label: widget.language.strings.kolkhozappPassword,
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: confirmPasswordController,
            label: widget.language.strings.kolkhozappConfirmPassword,
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
                      ? widget.language.strings.kolkhozappWorking
                      : widget.language.strings.kolkhozappSignIn,
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
                  label: widget.language.strings.kolkhozappReset,
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
                  label: widget.language.strings.kolkhozappCreate,
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
