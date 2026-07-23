// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get lobbyCreateGame => 'Create Game';

  @override
  String get lobbyPlayDemo => 'Play Demo';

  @override
  String get lobbyJoinGame => 'Join Game';

  @override
  String get lobbyHowToPlay => 'How to Play';

  @override
  String get lobbyAccountStatus => 'Account status';

  @override
  String get lobbyLanguage => 'Language';

  @override
  String get lobbyTheme => 'Theme';

  @override
  String get lobbySettings => 'Settings';

  @override
  String get presetKolkhoz => 'Kolkhoz';

  @override
  String get presetLittleKolkhoz => 'Little Kolkhoz';

  @override
  String get presetCampStyle => 'Camp Style';

  @override
  String get presetCustom => 'Custom';

  @override
  String get variantDeck52Cards => '52 cards';

  @override
  String get variantDeck36Cards => '36 cards';

  @override
  String get variantDeckLabel => 'DECK';

  @override
  String variantValue1CardDeck({required Object value1}) {
    return '$value1 Card Deck';
  }

  @override
  String variantValue1YearPlan({required Object value1}) {
    return '$value1 Year Plan';
  }

  @override
  String get variantNomenklaturaTitle => 'The Party lives by its own rules';

  @override
  String get variantNomenklaturaDescription =>
      'Trump face cards have special effects: Jack goes north, Queen exposes all, King doubles exile.';

  @override
  String get variantSwapTitle => 'Exchange Soap for an Awl';

  @override
  String get variantSwapDescription =>
      'Exchange cards between your hand and plot at the start of each year.';

  @override
  String get variantNorthernStyleTitle => 'Playing the Northern Way';

  @override
  String get variantNorthernStyleDescription =>
      'No rewards for completed jobs - nobody earns protection.';

  @override
  String get variantMiceTitle => 'They even talked to the mice';

  @override
  String get variantMiceDescription =>
      'At requisition, every hidden plot is gnawed open.';

  @override
  String get variantOrdenNachalnikuTitle => 'Medal to the Boss, the work to us';

  @override
  String get variantOrdenNachalnikuDescription =>
      'Finished jobs pile their cards into bonus rewards.';

  @override
  String get variantMedalsTitle =>
      'Medals to fill a wardrobe but nothing to eat';

  @override
  String get variantMedalsDescription =>
      'Trick victories become medals on the final tally.';

  @override
  String get variantHeroTitle => 'Hero of Socialist Labor';

  @override
  String get variantHeroDescription =>
      'Win every trick in a year: you are protected and every other player is vulnerable.';

  @override
  String get variantAccumulationTitle => 'In the Common Pot';

  @override
  String get variantAccumulationDescription =>
      'Unclaimed job rewards stay in the pot for next year.';

  @override
  String get variantWreckerTitle => 'Enemy of the People';

  @override
  String get variantWreckerDescription =>
      'Add a 0-value all-suit joker that wrecks its job at requisition.';

  @override
  String get variantFinalYearTrumpTitle => 'Final Year Trump';

  @override
  String get variantFinalYearTrumpDescription =>
      'Reveal the leftover fifth-year card for trump; Saboteur means no trump.';

  @override
  String get variantPassCardsTitle => 'Pass';

  @override
  String get variantPassCardsDescription =>
      'Pass one hidden card left, then right, alternating from years 2 through 5.';

  @override
  String get variantHighestCardsRequisitionTitle => 'Highest Cards Requisition';

  @override
  String get variantHighestCardsRequisitionDescription =>
      'Lose your highest cards across failed crops, one for each failed job.';

  @override
  String get variantLottoRewardsTitle => 'Lotto Rewards';

  @override
  String get variantLottoRewardsDescription =>
      'Each crop replaces its 5 reward with a hidden random card from 5 through King.';

  @override
  String get variantDemoModeTitle => 'Demo Mode';

  @override
  String get variantDemoModeDescription => '2-year Kolkhoz with easy AI';

  @override
  String get appsettingsDark => 'DARK';

  @override
  String get appsettingsLight => 'LIGHT';

  @override
  String get appsettingsSwitchToLightMode => 'Switch to light mode';

  @override
  String get appsettingsSwitchToDarkMode => 'Switch to dark mode';

  @override
  String get appsettingsCardBacks => 'Card backs';

  @override
  String get appsettingsClassic => 'Classic';

  @override
  String get appsettingsHarvest => 'Harvest';

  @override
  String get appsettingsGranary => 'Granary';

  @override
  String get appsettingsWinter => 'Winter';

  @override
  String get tabledisplayYou => 'You';

  @override
  String get tutorialdisplayBack => 'Back';

  @override
  String get tutorialdisplayDone => 'Done';

  @override
  String get tutorialdisplayNext => 'Next';

  @override
  String get tutorialdisplayForemanMisha => 'FOREMAN MISHA';

  @override
  String get tutorialdisplayTip => 'TIP';

  @override
  String get tutorialdisplayDoneWellWorkedComrade =>
      'Done. Well worked, comrade.';

  @override
  String get boardviewPassDevice => 'Pass Device';

  @override
  String boardviewSeatValue1IsUp({required Object value1}) {
    return 'Seat $value1 is up.';
  }

  @override
  String get boardviewReady => 'Ready';

  @override
  String get boardviewYourTurn => 'YOUR TURN';

  @override
  String get boardviewWait => 'WAIT';

  @override
  String get boardviewFamineYear => 'Famine year';

  @override
  String get boardviewChooseTrump => 'Choose Trump';

  @override
  String get lowerbaractionsSwap => 'Swap';

  @override
  String get lowerbaractionsUndo => 'Undo';

  @override
  String get lowerbaractionsConfirm => 'Confirm';

  @override
  String get lowerbaractionsFinish => 'Finish';

  @override
  String lowerbaractionsYearValue1({required Object value1}) {
    return 'Year $value1';
  }

  @override
  String phasedisplayYearValue1Phasename({
    required Object value1,
    required Object phaseName,
  }) {
    return 'Year $value1 - $phaseName';
  }

  @override
  String get kolkhozappCancel => 'Cancel';

  @override
  String get kolkhozappNewGame => 'New game?';

  @override
  String get kolkhozappThisWillReplaceTheCurrentGame =>
      'This will replace the current game.';

  @override
  String get kolkhozappNewGame2 => 'New game';

  @override
  String get kolkhozappMainMenu => 'Main menu?';

  @override
  String get kolkhozappLeaveTheCurrentGameAndReturnToSetup =>
      'Leave the current game and return to setup.';

  @override
  String get kolkhozappMainMenu2 => 'Main menu';

  @override
  String get kolkhozappRememberYouMustFollowSuitIfAble =>
      'Remember, you must follow suit if able.';

  @override
  String get kolkhozappSignedInProfileLoaded => 'Signed in. Profile loaded.';

  @override
  String get kolkhozappAccountCreatedCheckYourEmailToConfirmItThe =>
      'Account created. Check your email to confirm it, then sign in.';

  @override
  String get kolkhozappAccountCreated => 'Account created.';

  @override
  String get kolkhozappAccountDeleted => 'Account deleted.';

  @override
  String get kolkhozappPasswordResetEmailSent => 'Password reset email sent.';

  @override
  String get kolkhozappSyncingProfile => 'Syncing profile...';

  @override
  String get kolkhozappProfileSaved => 'Profile saved.';

  @override
  String get kolkhozappProfileLoaded => 'Profile loaded.';

  @override
  String get kolkhozappAccountRequestFailed =>
      'Account request failed. Try again in a moment.';

  @override
  String get kolkhozappAccountInvalidEmail =>
      'Enter a valid email address, including any + tag.';

  @override
  String get kolkhozappAccountAlreadyExists =>
      'An account already exists for this email. Sign in or reset the password.';

  @override
  String get kolkhozappAccountRateLimited =>
      'Too many account attempts. Wait a few minutes and try again.';

  @override
  String get kolkhozappAccountCreationUnavailable =>
      'Account creation is temporarily unavailable. Try again later.';

  @override
  String get kolkhozappAccountWeakPassword =>
      'Choose a stronger password and try again.';

  @override
  String get kolkhozappAccountServiceUnavailable =>
      'Could not reach the account service. Check your connection and try again.';

  @override
  String get kolkhozappAccountInvalidCredentials =>
      'Email or password is incorrect. Try again or reset the password.';

  @override
  String get kolkhozappProfileSyncFailed => 'Profile sync failed.';

  @override
  String get kolkhozappSignInBeforeJoiningOnlinePlay =>
      'Sign in before joining online play.';

  @override
  String get kolkhozappOnlineSignInExpiredSignInAgain =>
      'Online sign-in expired. Sign in again.';

  @override
  String get kolkhozappCouldNotVerifyOnlineAccountTryAgain =>
      'Could not verify your online account. Try again.';

  @override
  String get kolkhozappCloudAccountUnavailable => 'Cloud account unavailable';

  @override
  String get kolkhozappConnectingAccount => 'Connecting account...';

  @override
  String kolkhozappSignedInEmail({required Object email}) {
    return 'Signed in: $email';
  }

  @override
  String get kolkhozappSignedIn => 'Signed in';

  @override
  String get kolkhozappSignedOut2 => 'Signed out';

  @override
  String get kolkhozappGameBy => 'GAME BY';

  @override
  String get kolkhozappWilliamTheisen => 'WILLIAM THEISEN';

  @override
  String get kolkhozappProfile => 'Profile';

  @override
  String get kolkhozappLeaderboard => 'LEADERBOARD';

  @override
  String get kolkhozappSettings => 'SETTINGS';

  @override
  String get kolkhozappProgress => 'PROGRESS';

  @override
  String get kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom =>
      'Could not reach the online server. Try again in a moment.';

  @override
  String get kolkhozappOnlineRequestFailedTryAgain =>
      'Online request failed. Try again.';

  @override
  String get kolkhozappDemoMode2YearKolkhozWithEasyAi =>
      'Demo mode: 2-year Kolkhoz with easy AI.';

  @override
  String get kolkhozappWorking => 'Working...';

  @override
  String get kolkhozappStartDemo => 'Start Demo';

  @override
  String get kolkhozappStartOnlineGame => 'Start Online Game';

  @override
  String get kolkhozappStartOfflineGame => 'Start Offline Game';

  @override
  String get kolkhozappContinueToLobby => 'Add Players';

  @override
  String get kolkhozappBackToSetup => 'Back to Setup';

  @override
  String get kolkhozappSaveFavorite => 'Save Favorite';

  @override
  String get kolkhozappUseFavorite => 'Use Favorite';

  @override
  String get kolkhozappFavoriteSaved => 'Favorite setup saved';

  @override
  String get kolkhozappRanked => 'Ranked';

  @override
  String get kolkhozappLocked => 'Private';

  @override
  String get kolkhozappBrowser => 'Public';

  @override
  String get kolkhozappAccess => 'VISIBILITY';

  @override
  String get kolkhozappComrades => 'Comrades';

  @override
  String get kolkhozappYourComradeCode => 'YOUR COMRADE CODE';

  @override
  String get kolkhozappComradeCode => 'COMRADE CODE';

  @override
  String get kolkhozappAddComrade => 'Add Comrade';

  @override
  String get kolkhozappRemove => 'Remove';

  @override
  String get kolkhozappNoComrades => 'No comrades yet';

  @override
  String get kolkhozappComradeAdded => 'Comrade added';

  @override
  String get kolkhozappComradeRequestSent => 'Comrade request sent';

  @override
  String get kolkhozappComrade => 'Comrade';

  @override
  String get kolkhozappNotComrade => 'Not a comrade';

  @override
  String get kolkhozappPending => 'Pending';

  @override
  String get kolkhozappIncomingRequests => 'Incoming Requests';

  @override
  String get kolkhozappOutgoingRequests => 'Sent Requests';

  @override
  String get kolkhozappNoComradeRequests => 'No comrade requests';

  @override
  String get kolkhozappAccept => 'Accept';

  @override
  String get kolkhozappDecline => 'Decline';

  @override
  String get kolkhozappComradeRequestAccepted => 'Comrade request accepted';

  @override
  String get kolkhozappComradeRequestDeclined => 'Comrade request declined';

  @override
  String get kolkhozappComradeRemoved => 'Comrade removed';

  @override
  String get kolkhozappGameInvite => 'Game Invite';

  @override
  String kolkhozappValue1InvitedYouToAGame({required Object value1}) {
    return '$value1 invited you to a game.';
  }

  @override
  String get kolkhozappOfflineStatus => 'Offline';

  @override
  String get kolkhozappInGame => 'In game';

  @override
  String get kolkhozappInLobby => 'In lobby';

  @override
  String get kolkhozappCasual => 'Casual';

  @override
  String get kolkhozappGameType => 'TYPE';

  @override
  String kolkhozappPValue1({required Object value1}) {
    return 'P$value1';
  }

  @override
  String get kolkhozappHotseat => 'Hotseat';

  @override
  String get kolkhozappOnline => 'Online';

  @override
  String kolkhozappDecktypeCardsMaxyearsYears({
    required Object deckType,
    required Object maxYears,
  }) {
    return '$deckType CARDS / $maxYears YEARS';
  }

  @override
  String get kolkhozappHowToPlay => 'HOW TO PLAY';

  @override
  String get kolkhozappTutorial => 'Tutorial';

  @override
  String get kolkhozappProfile2 => 'PROFILE';

  @override
  String get kolkhozappDisplayName => 'DISPLAY NAME';

  @override
  String get kolkhozappPortrait => 'PORTRAIT';

  @override
  String get kolkhozappPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get kolkhozappCloudProfilesAreNotConfiguredForThisBuild =>
      'Cloud profiles are not configured for this build.';

  @override
  String get kolkhozappCloudProfilesAreStarting =>
      'Cloud profiles are starting.';

  @override
  String get kolkhozappSignInToSyncProfileAndOnlineSeats =>
      'Sign in to sync profile and online seats.';

  @override
  String get kolkhozappAccount => 'ACCOUNT';

  @override
  String get kolkhozappEmail => 'EMAIL';

  @override
  String get kolkhozappPassword => 'PASSWORD';

  @override
  String get kolkhozappConfirmPassword => 'CONFIRM PASSWORD';

  @override
  String get kolkhozappSignIn => 'Sign In';

  @override
  String get kolkhozappReset => 'Reset';

  @override
  String get kolkhozappCreate => 'Create';

  @override
  String get kolkhozappOffline => 'OFFLINE';

  @override
  String get kolkhozappGames => 'games';

  @override
  String get kolkhozappOffWins => 'OFF WINS';

  @override
  String get kolkhozappWins => 'wins';

  @override
  String get kolkhozappOnline2 => 'ONLINE';

  @override
  String get kolkhozappOnWins => 'ON WINS';

  @override
  String get kolkhozappCasualRating => 'CASUAL RATING';

  @override
  String get kolkhozappRankedRating => 'RANKED RATING';

  @override
  String get kolkhozappRating => 'RATING';

  @override
  String get kolkhozappCurrent => 'current';

  @override
  String get kolkhozappWins2 => 'WINS';

  @override
  String get kolkhozappTotal => 'total';

  @override
  String get kolkhozappLosses => 'LOSSES';

  @override
  String get kolkhozappStats => 'STATS';

  @override
  String get kolkhozappNoOpenGames => 'No open games';

  @override
  String kolkhozappValue1Open({required Object value1}) {
    return '$value1 open';
  }

  @override
  String kolkhozappValue1CitizensOnline({required Object value1}) {
    return '$value1 Citizens Online';
  }

  @override
  String kolkhozappRefreshInValue1s({required Object value1}) {
    return 'Refresh in ${value1}s';
  }

  @override
  String kolkhozappJoinedValue1({required Object value1}) {
    return 'Joined $value1';
  }

  @override
  String get kolkhozappSentNorthOnlinePlayIsLockedForThisAccount =>
      'Sent north: online play is locked for this account.';

  @override
  String get kolkhozappTheOnlineServerRejectedTheRequest =>
      'The online server rejected the request.';

  @override
  String get kolkhozappOnlinePlay => 'ONLINE PLAY';

  @override
  String get kolkhozappJoinAnOpenGameOrEnterAnInviteCode =>
      'Join an open game or enter an invite code.';

  @override
  String get kolkhozappInviteCode => 'INVITE CODE';

  @override
  String get kolkhozappYourInviteCode => 'YOUR INVITE CODE';

  @override
  String get kolkhozappWaitingForPlayers => 'Waiting for players';

  @override
  String kolkhozappGameStartsInValue1s({required Object value1}) {
    return 'Game starts in ${value1}s';
  }

  @override
  String get kolkhozappSearchingForPlayer => 'Searching for Player';

  @override
  String get kolkhozappCopyCode => 'Copy Code';

  @override
  String get kolkhozappCopyResult => 'Copy Result';

  @override
  String get kolkhozappCopied => 'Copied';

  @override
  String get kolkhozappJoinGame => 'Join Game';

  @override
  String get kolkhozappAssignGame => 'Assign Game';

  @override
  String get kolkhozappKick => 'Kick';

  @override
  String get kolkhozappOpenGames => 'OPEN GAMES';

  @override
  String get kolkhozappRefresh => 'Refresh';

  @override
  String kolkhozappOpenOpenseats({required Object openSeats}) {
    return 'Open $openSeats';
  }

  @override
  String get kolkhozappHost => 'HOST';

  @override
  String get kolkhozappSeats => 'SEATS';

  @override
  String get kolkhozappTurn => 'TURN';

  @override
  String get kolkhozappMoves => 'MOVES';

  @override
  String get kolkhozappWaiting => 'WAITING';

  @override
  String get kolkhozappOpen => 'OPEN';

  @override
  String get kolkhozappAverageRating => 'AVG RATING';

  @override
  String get kolkhozappPlayer => 'PLAYER';

  @override
  String get kolkhozappScore => 'SCORE';

  @override
  String get kolkhozappMedals => 'MEDALS';

  @override
  String get kolkhozappHand => 'HAND';

  @override
  String get kolkhozappCellar => 'CELLAR';

  @override
  String get kolkhozappPlot => 'PLOT';

  @override
  String get kolkhozappController => 'CONTROL';

  @override
  String get kolkhozappBrigadeLeader => 'BRIGADE LEADER';

  @override
  String get kolkhozappCurrentTurn => 'CURRENT TURN';

  @override
  String get kolkhozappAny => 'Any';

  @override
  String get kolkhozappHuman => 'Human';

  @override
  String get kolkhozappEasy => 'Easy';

  @override
  String get kolkhozappMedium => 'Medium';

  @override
  String get kolkhozappHard => 'Hard';

  @override
  String get plotdisplayOtherStoresAboveActivePlayerSCellarBelow =>
      'Other stores above, active player\'s cellar below.';

  @override
  String get plotdisplayAllJobsComplete => 'All jobs complete.';

  @override
  String get plotdisplayAuditComplete => 'Audit complete.';

  @override
  String get boardOptionspanelInstant => 'Instant';

  @override
  String get boardOptionspanelFast => 'Fast';

  @override
  String get boardOptionspanelNormal => 'Normal';

  @override
  String get boardOptionspanelSlow => 'Slow';

  @override
  String get boardOptionspanelSession => 'Session';

  @override
  String get boardOptionspanelAssist => 'Assist';

  @override
  String get boardOptionspanelDisplay => 'Display';

  @override
  String get boardOptionspanelRules => 'Rules';

  @override
  String get boardOptionspanelMenu => 'Menu';

  @override
  String get boardOptionspanelGameControls => 'Game controls';

  @override
  String get boardOptionspanelHowToPlay => 'How to play';

  @override
  String get boardOptionspanelSafeguards => 'Safeguards';

  @override
  String get boardOptionspanelConfirmNewGame => 'Confirm new game';

  @override
  String get boardOptionspanelAskBeforeReplacingTheCurrentGame =>
      'Ask before replacing the current game.';

  @override
  String get boardOptionspanelConfirmMainMenu => 'Confirm main menu';

  @override
  String get boardOptionspanelAskBeforeLeavingTheCurrentGame =>
      'Ask before leaving the current game.';

  @override
  String get boardOptionspanelMoveHelp => 'Move help';

  @override
  String get boardOptionspanelInvalidTapHints => 'Invalid-tap hints';

  @override
  String get boardOptionspanelShowTheForemanReminderWhenYouTapAnIllegalC =>
      'Show the Foreman reminder when you tap an illegal card.';

  @override
  String get boardOptionspanelAnimationSpeed => 'Animation speed';

  @override
  String get boardPlotpanelRequisition => 'Requisition';

  @override
  String get boardPlotpanelPrivatePlot => 'Private plot';

  @override
  String get boardPlotpanelGameOver => 'Game Over';

  @override
  String boardPlotpanelWinnerWinnernameWinnerscore({
    required Object winnerName,
    required Object winnerScore,
  }) {
    return 'Winner: $winnerName - $winnerScore';
  }

  @override
  String get boardHandtrayUndo => 'Undo';

  @override
  String get boardHandtrayPlay => 'Play';

  @override
  String get handConsoleYourTurnToPlay => 'Your turn to play';

  @override
  String get handConsoleChooseSwap => 'Choose a swap';

  @override
  String get handConsoleAssignTrick => 'Assign the trick';

  @override
  String get handConsoleReviewRequisition => 'Review requisition';

  @override
  String handConsoleWaitingForValue1({required Object value1}) {
    return 'Waiting for $value1';
  }

  @override
  String handConsoleWaitingForValue1ToPlay({required Object value1}) {
    return 'Waiting for $value1 to play';
  }

  @override
  String handConsoleWaitingForValue1ToSwap({required Object value1}) {
    return 'Waiting for $value1 to swap';
  }

  @override
  String handConsoleWaitingForValue1ToAssign({required Object value1}) {
    return 'Waiting for $value1 to assign';
  }

  @override
  String get handConsoleContinue => 'Continue';

  @override
  String get boardJobspanelDone => 'DONE';

  @override
  String get boardJobspanelTapToAssign => 'TAP TO ASSIGN';

  @override
  String get boardBoardrailBoard => 'Board';

  @override
  String get boardBoardrailJobs => 'Jobs';

  @override
  String get boardBoardrailNorth => 'North';

  @override
  String get boardBoardrailCellar => 'Cellar';

  @override
  String get boardBoardrailLang => 'Lang';

  @override
  String get boardBoardrailBrigade => 'Brigade';

  @override
  String get boardBoardrailTheNorth => 'The North';

  @override
  String get ruleSummary1Title => 'Objective';

  @override
  String get ruleSummary1Body =>
      'Complete collective farm jobs while protecting your private plot. Highest score wins!';

  @override
  String get ruleSummary2Title => 'Gameplay';

  @override
  String get ruleSummary2Body =>
      'Play cards to tricks - must follow lead suit if able.';

  @override
  String get ruleSummary3Title => 'Jobs';

  @override
  String get ruleSummary3Body => 'Jobs need 40 work hours to complete.';

  @override
  String get ruleSummary4Title => 'Trump Face Cards';

  @override
  String get ruleSummary4Body =>
      'Jack, Queen, and King have special powers in nomenclature games.';

  @override
  String get ruleSummary5Title => 'Scoring';

  @override
  String get ruleSummary5Body =>
      'Cards in your plot equal your score. Highest score wins.';

  @override
  String get ruleSummary6Title => 'Work';

  @override
  String get ruleSummary6Body =>
      'Win tricks, then assign captured cards to matching jobs.';

  @override
  String get ruleSummary7Title => 'Protect';

  @override
  String get ruleSummary7Body =>
      'Keep plot cards safe from failed-job requisition.';

  @override
  String get ruleSummary8Title => 'Trump faces';

  @override
  String get ruleSummary8Body =>
      'Jack goes north, Queen exposes, King doubles exile.';

  @override
  String get tutorialStep1Title => 'Welcome to the collective';

  @override
  String get tutorialStep1Body =>
      'This is a real game, comrade — play while we talk. Your goal: end the Five-Year Plan with the most points hidden in your cellar.';

  @override
  String get tutorialStep1Tip =>
      'High hidden cards are your bank. Losing one to the North can swing the final score.';

  @override
  String get tutorialStep1Callout =>
      'The buttons below turn my lessons. The board stays yours.';

  @override
  String get tutorialStep2Title => 'Read the work board';

  @override
  String get tutorialStep2Body =>
      'Four jobs each year, one per crop. Each reward pile has ranks 1–4 plus one hidden lotto rank from 5–K; the counter is work hours — 40 completes the job.';

  @override
  String get tutorialStep2Tip =>
      'Failed jobs summon requisition at year\'s end. Remember which crops look doomed.';

  @override
  String get tutorialStep2Callout =>
      'Find the four job counters along the top of the table.';

  @override
  String get tutorialStep3Title => 'The trump crop';

  @override
  String get tutorialStep3Body =>
      'In planning, one crop is declared the State\'s main task — trump. In year five, the leftover deal card is revealed to set trump; Saboteur means no trump.';

  @override
  String get tutorialStep3Tip =>
      'Pick trump for the hand you expect to play, not only for the biggest card you see.';

  @override
  String get tutorialStep3Callout => 'Waiting for trump to be declared…';

  @override
  String get tutorialStep4Title => 'Play a card';

  @override
  String get tutorialStep4Body =>
      'Follow the led crop if you can — legal cards glow. Out of that crop? Play anything, even trump.';

  @override
  String get tutorialStep4Tip =>
      'Ducking a trick is allowed — and often wise. Winners attract attention.';

  @override
  String get tutorialStep4Callout =>
      'Play a card from your hand when your turn comes.';

  @override
  String get tutorialStep5Title => 'Taking the trick';

  @override
  String get tutorialStep5Body =>
      'Highest card of the led crop wins — unless trump lands; then the highest trump. The winner takes a medal and becomes brigade leader.';

  @override
  String get tutorialStep5Tip =>
      'Medals break ties at the end — but every win paints a target on your cellar.';

  @override
  String get tutorialStep5Callout => 'Watch who takes this trick.';

  @override
  String get tutorialStep6Title => 'Assign the labor';

  @override
  String get tutorialStep6Body =>
      'The brigade leader sends the trick\'s cards to jobs — only crops present in the trick are legal targets. A card\'s rank is its hours.';

  @override
  String get tutorialStep6Tip =>
      'Assign work to protect the crops that match your best cellar cards.';

  @override
  String get tutorialStep6Callout =>
      'When you win a trick, tap its cards onto jobs.';

  @override
  String get tutorialStep7Title => 'Meet the quota';

  @override
  String get tutorialStep7Body =>
      'A job that reaches 40 hours is complete: its reward drops into the closer\'s cellar, and that crop is safe from requisition this year.';

  @override
  String get tutorialStep7Tip =>
      'A finished job pays you and protects you. Two birds, one quota.';

  @override
  String get tutorialStep7Callout =>
      'Push a job to 40 hours to claim its reward.';

  @override
  String get tutorialStep8Title => 'The leftover card';

  @override
  String get tutorialStep8Body =>
      'Only four tricks are played. Your fifth card slips face-down into your cellar at year\'s end — its rank becomes points.';

  @override
  String get tutorialStep8Tip =>
      'Steer the year so your best card is the one that survives.';

  @override
  String get tutorialStep8Callout =>
      'Your unplayed card banks itself when the year ends.';

  @override
  String get tutorialStep9Title => 'This is requisition';

  @override
  String get tutorialStep9Body =>
      'If N crop suits fail, each vulnerable player loses their N highest cellar cards across those suits. Party Official adds one; Drunkard removes its suit from the quota.';

  @override
  String get tutorialStep9Tip =>
      'Never won a trick? Nothing to confess. Cowardice has its rewards.';

  @override
  String get tutorialStep9Callout => 'Read the requisition report carefully.';

  @override
  String get tutorialStep10Title => 'The yearly swap';

  @override
  String get tutorialStep10Body =>
      'From year two, you may trade one hand card for one cellar card before the trick begins.';

  @override
  String get tutorialStep10Tip =>
      'Bury high cards while they are safe; pull out crops that look doomed.';

  @override
  String get tutorialStep10Callout =>
      'Consider your swap before the trick begins.';

  @override
  String get tutorialStep11Title => 'Beware the Wrecker';

  @override
  String get tutorialStep11Body =>
      'One joker hides among the workers: he follows any suit and brings 0 hours — and any job holding him fails inspection.';

  @override
  String get tutorialStep11Tip =>
      'Win him boldly, bury him bitterly — or make him someone else\'s problem.';

  @override
  String get tutorialStep11Callout =>
      'He plays by Kolkhoz rules — watch for the wild card.';

  @override
  String get tutorialStep12Title => 'Year five is famine';

  @override
  String get tutorialStep12Body =>
      'The last year is lean: four cards, three tricks, no trump at all. Short, and usually decisive.';

  @override
  String get tutorialStep12Tip =>
      'Save flexible high cards for famine; without trump a bad lead is hard to escape.';

  @override
  String get tutorialStep12Callout => 'Waiting for the famine year…';

  @override
  String get tutorialStep13Title => 'Highest final cellar wins';

  @override
  String get tutorialStep13Body =>
      'After year five, every cellar card counts its rank. Highest total wins the Plan; medals break ties. Make me proud, comrade.';

  @override
  String get tutorialStep13Tip =>
      'One protected King is worth a year of caution.';

  @override
  String get tutorialStep13Callout => 'Finish the Plan — Misha is watching.';

  @override
  String get suitWheat => 'Wheat';

  @override
  String get suitSunflower => 'Sunflower';

  @override
  String get suitPotatoes => 'Potatoes';

  @override
  String get suitBeets => 'Beets';

  @override
  String get phasePlanning => 'Planning';

  @override
  String get phaseSwap => 'Swap';

  @override
  String get phaseTrick => 'Trick';

  @override
  String get phaseAssignment => 'Assignment';

  @override
  String get phaseRequisition => 'Requisition';

  @override
  String get phaseGameOver => 'Game Over';

  @override
  String get languageSwitchTitle => 'Switch to Russian';
}
