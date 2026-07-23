import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @lobbyCreateGame.
  ///
  /// In en, this message translates to:
  /// **'Create Game'**
  String get lobbyCreateGame;

  /// No description provided for @lobbyPlayDemo.
  ///
  /// In en, this message translates to:
  /// **'Play Demo'**
  String get lobbyPlayDemo;

  /// No description provided for @lobbyJoinGame.
  ///
  /// In en, this message translates to:
  /// **'Join Game'**
  String get lobbyJoinGame;

  /// No description provided for @lobbyHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to Play'**
  String get lobbyHowToPlay;

  /// No description provided for @lobbyAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get lobbyAccountStatus;

  /// No description provided for @lobbyLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get lobbyLanguage;

  /// No description provided for @lobbyTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get lobbyTheme;

  /// No description provided for @lobbySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get lobbySettings;

  /// No description provided for @presetKolkhoz.
  ///
  /// In en, this message translates to:
  /// **'Kolkhoz'**
  String get presetKolkhoz;

  /// No description provided for @presetLittleKolkhoz.
  ///
  /// In en, this message translates to:
  /// **'Little Kolkhoz'**
  String get presetLittleKolkhoz;

  /// No description provided for @presetCampStyle.
  ///
  /// In en, this message translates to:
  /// **'Camp Style'**
  String get presetCampStyle;

  /// No description provided for @presetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get presetCustom;

  /// No description provided for @variantDeck52Cards.
  ///
  /// In en, this message translates to:
  /// **'52 cards'**
  String get variantDeck52Cards;

  /// No description provided for @variantDeck36Cards.
  ///
  /// In en, this message translates to:
  /// **'36 cards'**
  String get variantDeck36Cards;

  /// No description provided for @variantDeckLabel.
  ///
  /// In en, this message translates to:
  /// **'DECK'**
  String get variantDeckLabel;

  /// No description provided for @variantValue1CardDeck.
  ///
  /// In en, this message translates to:
  /// **'{value1} Card Deck'**
  String variantValue1CardDeck({required Object value1});

  /// No description provided for @variantValue1YearPlan.
  ///
  /// In en, this message translates to:
  /// **'{value1} Year Plan'**
  String variantValue1YearPlan({required Object value1});

  /// No description provided for @variantNomenklaturaTitle.
  ///
  /// In en, this message translates to:
  /// **'The Party lives by its own rules'**
  String get variantNomenklaturaTitle;

  /// No description provided for @variantNomenklaturaDescription.
  ///
  /// In en, this message translates to:
  /// **'Trump face cards have special effects: Jack goes north, Queen exposes all, King doubles exile.'**
  String get variantNomenklaturaDescription;

  /// No description provided for @variantSwapTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange Soap for an Awl'**
  String get variantSwapTitle;

  /// No description provided for @variantSwapDescription.
  ///
  /// In en, this message translates to:
  /// **'Exchange cards between your hand and plot at the start of each year.'**
  String get variantSwapDescription;

  /// No description provided for @variantNorthernStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Playing the Northern Way'**
  String get variantNorthernStyleTitle;

  /// No description provided for @variantNorthernStyleDescription.
  ///
  /// In en, this message translates to:
  /// **'No rewards for completed jobs - nobody earns protection.'**
  String get variantNorthernStyleDescription;

  /// No description provided for @variantMiceTitle.
  ///
  /// In en, this message translates to:
  /// **'They even talked to the mice'**
  String get variantMiceTitle;

  /// No description provided for @variantMiceDescription.
  ///
  /// In en, this message translates to:
  /// **'At requisition, every hidden plot is gnawed open.'**
  String get variantMiceDescription;

  /// No description provided for @variantOrdenNachalnikuTitle.
  ///
  /// In en, this message translates to:
  /// **'Medal to the Boss, the work to us'**
  String get variantOrdenNachalnikuTitle;

  /// No description provided for @variantOrdenNachalnikuDescription.
  ///
  /// In en, this message translates to:
  /// **'Finished jobs pile their cards into bonus rewards.'**
  String get variantOrdenNachalnikuDescription;

  /// No description provided for @variantMedalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medals to fill a wardrobe but nothing to eat'**
  String get variantMedalsTitle;

  /// No description provided for @variantMedalsDescription.
  ///
  /// In en, this message translates to:
  /// **'Trick victories become medals on the final tally.'**
  String get variantMedalsDescription;

  /// No description provided for @variantHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Hero of Socialist Labor'**
  String get variantHeroTitle;

  /// No description provided for @variantHeroDescription.
  ///
  /// In en, this message translates to:
  /// **'Win every trick in a year: you are protected and every other player is vulnerable.'**
  String get variantHeroDescription;

  /// No description provided for @variantAccumulationTitle.
  ///
  /// In en, this message translates to:
  /// **'In the Common Pot'**
  String get variantAccumulationTitle;

  /// No description provided for @variantAccumulationDescription.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed job rewards stay in the pot for next year.'**
  String get variantAccumulationDescription;

  /// No description provided for @variantWreckerTitle.
  ///
  /// In en, this message translates to:
  /// **'Enemy of the People'**
  String get variantWreckerTitle;

  /// No description provided for @variantWreckerDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a 0-value all-suit joker that wrecks its job at requisition.'**
  String get variantWreckerDescription;

  /// No description provided for @variantFinalYearTrumpTitle.
  ///
  /// In en, this message translates to:
  /// **'Final Year Trump'**
  String get variantFinalYearTrumpTitle;

  /// No description provided for @variantFinalYearTrumpDescription.
  ///
  /// In en, this message translates to:
  /// **'Reveal the leftover fifth-year card for trump; Saboteur means no trump.'**
  String get variantFinalYearTrumpDescription;

  /// No description provided for @variantPassCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get variantPassCardsTitle;

  /// No description provided for @variantPassCardsDescription.
  ///
  /// In en, this message translates to:
  /// **'Pass one hidden card left, then right, alternating from years 2 through 5.'**
  String get variantPassCardsDescription;

  /// No description provided for @variantHighestCardsRequisitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Highest Cards Requisition'**
  String get variantHighestCardsRequisitionTitle;

  /// No description provided for @variantHighestCardsRequisitionDescription.
  ///
  /// In en, this message translates to:
  /// **'Lose your highest cards across failed crops, one for each failed job.'**
  String get variantHighestCardsRequisitionDescription;

  /// No description provided for @variantLottoRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lotto Rewards'**
  String get variantLottoRewardsTitle;

  /// No description provided for @variantLottoRewardsDescription.
  ///
  /// In en, this message translates to:
  /// **'Each crop replaces its 5 reward with a hidden random card from 5 through King.'**
  String get variantLottoRewardsDescription;

  /// No description provided for @variantDemoModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Demo Mode'**
  String get variantDemoModeTitle;

  /// No description provided for @variantDemoModeDescription.
  ///
  /// In en, this message translates to:
  /// **'2-year Kolkhoz with easy AI'**
  String get variantDemoModeDescription;

  /// No description provided for @appsettingsDark.
  ///
  /// In en, this message translates to:
  /// **'DARK'**
  String get appsettingsDark;

  /// No description provided for @appsettingsLight.
  ///
  /// In en, this message translates to:
  /// **'LIGHT'**
  String get appsettingsLight;

  /// No description provided for @appsettingsSwitchToLightMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get appsettingsSwitchToLightMode;

  /// No description provided for @appsettingsSwitchToDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get appsettingsSwitchToDarkMode;

  /// No description provided for @appsettingsCardBacks.
  ///
  /// In en, this message translates to:
  /// **'Card backs'**
  String get appsettingsCardBacks;

  /// No description provided for @appsettingsClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get appsettingsClassic;

  /// No description provided for @appsettingsHarvest.
  ///
  /// In en, this message translates to:
  /// **'Harvest'**
  String get appsettingsHarvest;

  /// No description provided for @appsettingsGranary.
  ///
  /// In en, this message translates to:
  /// **'Granary'**
  String get appsettingsGranary;

  /// No description provided for @appsettingsWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get appsettingsWinter;

  /// No description provided for @tabledisplayYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tabledisplayYou;

  /// No description provided for @tutorialdisplayBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tutorialdisplayBack;

  /// No description provided for @tutorialdisplayDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tutorialdisplayDone;

  /// No description provided for @tutorialdisplayNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorialdisplayNext;

  /// No description provided for @tutorialdisplayForemanMisha.
  ///
  /// In en, this message translates to:
  /// **'FOREMAN MISHA'**
  String get tutorialdisplayForemanMisha;

  /// No description provided for @tutorialdisplayTip.
  ///
  /// In en, this message translates to:
  /// **'TIP'**
  String get tutorialdisplayTip;

  /// No description provided for @tutorialdisplayDoneWellWorkedComrade.
  ///
  /// In en, this message translates to:
  /// **'Done. Well worked, comrade.'**
  String get tutorialdisplayDoneWellWorkedComrade;

  /// No description provided for @boardviewPassDevice.
  ///
  /// In en, this message translates to:
  /// **'Pass Device'**
  String get boardviewPassDevice;

  /// No description provided for @boardviewSeatValue1IsUp.
  ///
  /// In en, this message translates to:
  /// **'Seat {value1} is up.'**
  String boardviewSeatValue1IsUp({required Object value1});

  /// No description provided for @boardviewReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get boardviewReady;

  /// No description provided for @boardviewYourTurn.
  ///
  /// In en, this message translates to:
  /// **'YOUR TURN'**
  String get boardviewYourTurn;

  /// No description provided for @boardviewWait.
  ///
  /// In en, this message translates to:
  /// **'WAIT'**
  String get boardviewWait;

  /// No description provided for @boardviewFamineYear.
  ///
  /// In en, this message translates to:
  /// **'Famine year'**
  String get boardviewFamineYear;

  /// No description provided for @boardviewChooseTrump.
  ///
  /// In en, this message translates to:
  /// **'Choose Trump'**
  String get boardviewChooseTrump;

  /// No description provided for @lowerbaractionsSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get lowerbaractionsSwap;

  /// No description provided for @lowerbaractionsUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get lowerbaractionsUndo;

  /// No description provided for @lowerbaractionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get lowerbaractionsConfirm;

  /// No description provided for @lowerbaractionsFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get lowerbaractionsFinish;

  /// No description provided for @lowerbaractionsYearValue1.
  ///
  /// In en, this message translates to:
  /// **'Year {value1}'**
  String lowerbaractionsYearValue1({required Object value1});

  /// No description provided for @phasedisplayYearValue1Phasename.
  ///
  /// In en, this message translates to:
  /// **'Year {value1} - {phaseName}'**
  String phasedisplayYearValue1Phasename({
    required Object value1,
    required Object phaseName,
  });

  /// No description provided for @kolkhozappCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get kolkhozappCancel;

  /// No description provided for @kolkhozappNewGame.
  ///
  /// In en, this message translates to:
  /// **'New game?'**
  String get kolkhozappNewGame;

  /// No description provided for @kolkhozappThisWillReplaceTheCurrentGame.
  ///
  /// In en, this message translates to:
  /// **'This will replace the current game.'**
  String get kolkhozappThisWillReplaceTheCurrentGame;

  /// No description provided for @kolkhozappNewGame2.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get kolkhozappNewGame2;

  /// No description provided for @kolkhozappMainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main menu?'**
  String get kolkhozappMainMenu;

  /// No description provided for @kolkhozappLeaveTheCurrentGameAndReturnToSetup.
  ///
  /// In en, this message translates to:
  /// **'Leave the current game and return to setup.'**
  String get kolkhozappLeaveTheCurrentGameAndReturnToSetup;

  /// No description provided for @kolkhozappMainMenu2.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get kolkhozappMainMenu2;

  /// No description provided for @kolkhozappRememberYouMustFollowSuitIfAble.
  ///
  /// In en, this message translates to:
  /// **'Remember, you must follow suit if able.'**
  String get kolkhozappRememberYouMustFollowSuitIfAble;

  /// No description provided for @kolkhozappSignedInProfileLoaded.
  ///
  /// In en, this message translates to:
  /// **'Signed in. Profile loaded.'**
  String get kolkhozappSignedInProfileLoaded;

  /// No description provided for @kolkhozappAccountCreatedCheckYourEmailToConfirmItThe.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to confirm it, then sign in.'**
  String get kolkhozappAccountCreatedCheckYourEmailToConfirmItThe;

  /// No description provided for @kolkhozappAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get kolkhozappAccountCreated;

  /// No description provided for @kolkhozappAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get kolkhozappAccountDeleted;

  /// No description provided for @kolkhozappPasswordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent.'**
  String get kolkhozappPasswordResetEmailSent;

  /// No description provided for @kolkhozappSyncingProfile.
  ///
  /// In en, this message translates to:
  /// **'Syncing profile...'**
  String get kolkhozappSyncingProfile;

  /// No description provided for @kolkhozappProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get kolkhozappProfileSaved;

  /// No description provided for @kolkhozappProfileLoaded.
  ///
  /// In en, this message translates to:
  /// **'Profile loaded.'**
  String get kolkhozappProfileLoaded;

  /// No description provided for @kolkhozappAccountRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Account request failed. Try again in a moment.'**
  String get kolkhozappAccountRequestFailed;

  /// No description provided for @kolkhozappAccountInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address, including any + tag.'**
  String get kolkhozappAccountInvalidEmail;

  /// No description provided for @kolkhozappAccountAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Sign in or reset the password.'**
  String get kolkhozappAccountAlreadyExists;

  /// No description provided for @kolkhozappAccountRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many account attempts. Wait a few minutes and try again.'**
  String get kolkhozappAccountRateLimited;

  /// No description provided for @kolkhozappAccountCreationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account creation is temporarily unavailable. Try again later.'**
  String get kolkhozappAccountCreationUnavailable;

  /// No description provided for @kolkhozappAccountWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password and try again.'**
  String get kolkhozappAccountWeakPassword;

  /// No description provided for @kolkhozappAccountServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the account service. Check your connection and try again.'**
  String get kolkhozappAccountServiceUnavailable;

  /// No description provided for @kolkhozappAccountInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect. Try again or reset the password.'**
  String get kolkhozappAccountInvalidCredentials;

  /// No description provided for @kolkhozappProfileSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile sync failed.'**
  String get kolkhozappProfileSyncFailed;

  /// No description provided for @kolkhozappSignInBeforeJoiningOnlinePlay.
  ///
  /// In en, this message translates to:
  /// **'Sign in before joining online play.'**
  String get kolkhozappSignInBeforeJoiningOnlinePlay;

  /// No description provided for @kolkhozappOnlineSignInExpiredSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Online sign-in expired. Sign in again.'**
  String get kolkhozappOnlineSignInExpiredSignInAgain;

  /// No description provided for @kolkhozappCouldNotVerifyOnlineAccountTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your online account. Try again.'**
  String get kolkhozappCouldNotVerifyOnlineAccountTryAgain;

  /// No description provided for @kolkhozappCloudAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cloud account unavailable'**
  String get kolkhozappCloudAccountUnavailable;

  /// No description provided for @kolkhozappConnectingAccount.
  ///
  /// In en, this message translates to:
  /// **'Connecting account...'**
  String get kolkhozappConnectingAccount;

  /// No description provided for @kolkhozappSignedInEmail.
  ///
  /// In en, this message translates to:
  /// **'Signed in: {email}'**
  String kolkhozappSignedInEmail({required Object email});

  /// No description provided for @kolkhozappSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get kolkhozappSignedIn;

  /// No description provided for @kolkhozappSignedOut2.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get kolkhozappSignedOut2;

  /// No description provided for @kolkhozappGameBy.
  ///
  /// In en, this message translates to:
  /// **'GAME BY'**
  String get kolkhozappGameBy;

  /// No description provided for @kolkhozappWilliamTheisen.
  ///
  /// In en, this message translates to:
  /// **'WILLIAM THEISEN'**
  String get kolkhozappWilliamTheisen;

  /// No description provided for @kolkhozappProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get kolkhozappProfile;

  /// No description provided for @kolkhozappLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'LEADERBOARD'**
  String get kolkhozappLeaderboard;

  /// No description provided for @kolkhozappSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get kolkhozappSettings;

  /// No description provided for @kolkhozappProgress.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get kolkhozappProgress;

  /// No description provided for @kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the online server. Try again in a moment.'**
  String get kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom;

  /// No description provided for @kolkhozappOnlineRequestFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Online request failed. Try again.'**
  String get kolkhozappOnlineRequestFailedTryAgain;

  /// No description provided for @kolkhozappDemoMode2YearKolkhozWithEasyAi.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: 2-year Kolkhoz with easy AI.'**
  String get kolkhozappDemoMode2YearKolkhozWithEasyAi;

  /// No description provided for @kolkhozappWorking.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get kolkhozappWorking;

  /// No description provided for @kolkhozappStartDemo.
  ///
  /// In en, this message translates to:
  /// **'Start Demo'**
  String get kolkhozappStartDemo;

  /// No description provided for @kolkhozappStartOnlineGame.
  ///
  /// In en, this message translates to:
  /// **'Start Online Game'**
  String get kolkhozappStartOnlineGame;

  /// No description provided for @kolkhozappStartOfflineGame.
  ///
  /// In en, this message translates to:
  /// **'Start Offline Game'**
  String get kolkhozappStartOfflineGame;

  /// No description provided for @kolkhozappContinueToLobby.
  ///
  /// In en, this message translates to:
  /// **'Add Players'**
  String get kolkhozappContinueToLobby;

  /// No description provided for @kolkhozappBackToSetup.
  ///
  /// In en, this message translates to:
  /// **'Back to Setup'**
  String get kolkhozappBackToSetup;

  /// No description provided for @kolkhozappSaveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Save Favorite'**
  String get kolkhozappSaveFavorite;

  /// No description provided for @kolkhozappUseFavorite.
  ///
  /// In en, this message translates to:
  /// **'Use Favorite'**
  String get kolkhozappUseFavorite;

  /// No description provided for @kolkhozappFavoriteSaved.
  ///
  /// In en, this message translates to:
  /// **'Favorite setup saved'**
  String get kolkhozappFavoriteSaved;

  /// No description provided for @kolkhozappRanked.
  ///
  /// In en, this message translates to:
  /// **'Ranked'**
  String get kolkhozappRanked;

  /// No description provided for @kolkhozappLocked.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get kolkhozappLocked;

  /// No description provided for @kolkhozappBrowser.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get kolkhozappBrowser;

  /// No description provided for @kolkhozappAccess.
  ///
  /// In en, this message translates to:
  /// **'VISIBILITY'**
  String get kolkhozappAccess;

  /// No description provided for @kolkhozappComrades.
  ///
  /// In en, this message translates to:
  /// **'Comrades'**
  String get kolkhozappComrades;

  /// No description provided for @kolkhozappYourComradeCode.
  ///
  /// In en, this message translates to:
  /// **'YOUR COMRADE CODE'**
  String get kolkhozappYourComradeCode;

  /// No description provided for @kolkhozappComradeCode.
  ///
  /// In en, this message translates to:
  /// **'COMRADE CODE'**
  String get kolkhozappComradeCode;

  /// No description provided for @kolkhozappAddComrade.
  ///
  /// In en, this message translates to:
  /// **'Add Comrade'**
  String get kolkhozappAddComrade;

  /// No description provided for @kolkhozappRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get kolkhozappRemove;

  /// No description provided for @kolkhozappNoComrades.
  ///
  /// In en, this message translates to:
  /// **'No comrades yet'**
  String get kolkhozappNoComrades;

  /// No description provided for @kolkhozappComradeAdded.
  ///
  /// In en, this message translates to:
  /// **'Comrade added'**
  String get kolkhozappComradeAdded;

  /// No description provided for @kolkhozappComradeRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Comrade request sent'**
  String get kolkhozappComradeRequestSent;

  /// No description provided for @kolkhozappComrade.
  ///
  /// In en, this message translates to:
  /// **'Comrade'**
  String get kolkhozappComrade;

  /// No description provided for @kolkhozappNotComrade.
  ///
  /// In en, this message translates to:
  /// **'Not a comrade'**
  String get kolkhozappNotComrade;

  /// No description provided for @kolkhozappPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get kolkhozappPending;

  /// No description provided for @kolkhozappIncomingRequests.
  ///
  /// In en, this message translates to:
  /// **'Incoming Requests'**
  String get kolkhozappIncomingRequests;

  /// No description provided for @kolkhozappOutgoingRequests.
  ///
  /// In en, this message translates to:
  /// **'Sent Requests'**
  String get kolkhozappOutgoingRequests;

  /// No description provided for @kolkhozappNoComradeRequests.
  ///
  /// In en, this message translates to:
  /// **'No comrade requests'**
  String get kolkhozappNoComradeRequests;

  /// No description provided for @kolkhozappAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get kolkhozappAccept;

  /// No description provided for @kolkhozappDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get kolkhozappDecline;

  /// No description provided for @kolkhozappComradeRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Comrade request accepted'**
  String get kolkhozappComradeRequestAccepted;

  /// No description provided for @kolkhozappComradeRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Comrade request declined'**
  String get kolkhozappComradeRequestDeclined;

  /// No description provided for @kolkhozappComradeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Comrade removed'**
  String get kolkhozappComradeRemoved;

  /// No description provided for @kolkhozappGameInvite.
  ///
  /// In en, this message translates to:
  /// **'Game Invite'**
  String get kolkhozappGameInvite;

  /// No description provided for @kolkhozappValue1InvitedYouToAGame.
  ///
  /// In en, this message translates to:
  /// **'{value1} invited you to a game.'**
  String kolkhozappValue1InvitedYouToAGame({required Object value1});

  /// No description provided for @kolkhozappOfflineStatus.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get kolkhozappOfflineStatus;

  /// No description provided for @kolkhozappInGame.
  ///
  /// In en, this message translates to:
  /// **'In game'**
  String get kolkhozappInGame;

  /// No description provided for @kolkhozappInLobby.
  ///
  /// In en, this message translates to:
  /// **'In lobby'**
  String get kolkhozappInLobby;

  /// No description provided for @kolkhozappCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get kolkhozappCasual;

  /// No description provided for @kolkhozappGameType.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get kolkhozappGameType;

  /// No description provided for @kolkhozappPValue1.
  ///
  /// In en, this message translates to:
  /// **'P{value1}'**
  String kolkhozappPValue1({required Object value1});

  /// No description provided for @kolkhozappHotseat.
  ///
  /// In en, this message translates to:
  /// **'Hotseat'**
  String get kolkhozappHotseat;

  /// No description provided for @kolkhozappOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get kolkhozappOnline;

  /// No description provided for @kolkhozappDecktypeCardsMaxyearsYears.
  ///
  /// In en, this message translates to:
  /// **'{deckType} CARDS / {maxYears} YEARS'**
  String kolkhozappDecktypeCardsMaxyearsYears({
    required Object deckType,
    required Object maxYears,
  });

  /// No description provided for @kolkhozappHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'HOW TO PLAY'**
  String get kolkhozappHowToPlay;

  /// No description provided for @kolkhozappTutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get kolkhozappTutorial;

  /// No description provided for @kolkhozappProfile2.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get kolkhozappProfile2;

  /// No description provided for @kolkhozappDisplayName.
  ///
  /// In en, this message translates to:
  /// **'DISPLAY NAME'**
  String get kolkhozappDisplayName;

  /// No description provided for @kolkhozappPortrait.
  ///
  /// In en, this message translates to:
  /// **'PORTRAIT'**
  String get kolkhozappPortrait;

  /// No description provided for @kolkhozappPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get kolkhozappPasswordsDoNotMatch;

  /// No description provided for @kolkhozappCloudProfilesAreNotConfiguredForThisBuild.
  ///
  /// In en, this message translates to:
  /// **'Cloud profiles are not configured for this build.'**
  String get kolkhozappCloudProfilesAreNotConfiguredForThisBuild;

  /// No description provided for @kolkhozappCloudProfilesAreStarting.
  ///
  /// In en, this message translates to:
  /// **'Cloud profiles are starting.'**
  String get kolkhozappCloudProfilesAreStarting;

  /// No description provided for @kolkhozappSignInToSyncProfileAndOnlineSeats.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync profile and online seats.'**
  String get kolkhozappSignInToSyncProfileAndOnlineSeats;

  /// No description provided for @kolkhozappAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get kolkhozappAccount;

  /// No description provided for @kolkhozappEmail.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get kolkhozappEmail;

  /// No description provided for @kolkhozappPassword.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get kolkhozappPassword;

  /// No description provided for @kolkhozappConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get kolkhozappConfirmPassword;

  /// No description provided for @kolkhozappSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get kolkhozappSignIn;

  /// No description provided for @kolkhozappReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get kolkhozappReset;

  /// No description provided for @kolkhozappCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get kolkhozappCreate;

  /// No description provided for @kolkhozappOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get kolkhozappOffline;

  /// No description provided for @kolkhozappGames.
  ///
  /// In en, this message translates to:
  /// **'games'**
  String get kolkhozappGames;

  /// No description provided for @kolkhozappOffWins.
  ///
  /// In en, this message translates to:
  /// **'OFF WINS'**
  String get kolkhozappOffWins;

  /// No description provided for @kolkhozappWins.
  ///
  /// In en, this message translates to:
  /// **'wins'**
  String get kolkhozappWins;

  /// No description provided for @kolkhozappOnline2.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get kolkhozappOnline2;

  /// No description provided for @kolkhozappOnWins.
  ///
  /// In en, this message translates to:
  /// **'ON WINS'**
  String get kolkhozappOnWins;

  /// No description provided for @kolkhozappCasualRating.
  ///
  /// In en, this message translates to:
  /// **'CASUAL RATING'**
  String get kolkhozappCasualRating;

  /// No description provided for @kolkhozappRankedRating.
  ///
  /// In en, this message translates to:
  /// **'RANKED RATING'**
  String get kolkhozappRankedRating;

  /// No description provided for @kolkhozappRating.
  ///
  /// In en, this message translates to:
  /// **'RATING'**
  String get kolkhozappRating;

  /// No description provided for @kolkhozappCurrent.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get kolkhozappCurrent;

  /// No description provided for @kolkhozappWins2.
  ///
  /// In en, this message translates to:
  /// **'WINS'**
  String get kolkhozappWins2;

  /// No description provided for @kolkhozappTotal.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get kolkhozappTotal;

  /// No description provided for @kolkhozappLosses.
  ///
  /// In en, this message translates to:
  /// **'LOSSES'**
  String get kolkhozappLosses;

  /// No description provided for @kolkhozappStats.
  ///
  /// In en, this message translates to:
  /// **'STATS'**
  String get kolkhozappStats;

  /// No description provided for @kolkhozappNoOpenGames.
  ///
  /// In en, this message translates to:
  /// **'No open games'**
  String get kolkhozappNoOpenGames;

  /// No description provided for @kolkhozappValue1Open.
  ///
  /// In en, this message translates to:
  /// **'{value1} open'**
  String kolkhozappValue1Open({required Object value1});

  /// No description provided for @kolkhozappValue1CitizensOnline.
  ///
  /// In en, this message translates to:
  /// **'{value1} Citizens Online'**
  String kolkhozappValue1CitizensOnline({required Object value1});

  /// No description provided for @kolkhozappRefreshInValue1s.
  ///
  /// In en, this message translates to:
  /// **'Refresh in {value1}s'**
  String kolkhozappRefreshInValue1s({required Object value1});

  /// No description provided for @kolkhozappJoinedValue1.
  ///
  /// In en, this message translates to:
  /// **'Joined {value1}'**
  String kolkhozappJoinedValue1({required Object value1});

  /// No description provided for @kolkhozappSentNorthOnlinePlayIsLockedForThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Sent north: online play is locked for this account.'**
  String get kolkhozappSentNorthOnlinePlayIsLockedForThisAccount;

  /// No description provided for @kolkhozappTheOnlineServerRejectedTheRequest.
  ///
  /// In en, this message translates to:
  /// **'The online server rejected the request.'**
  String get kolkhozappTheOnlineServerRejectedTheRequest;

  /// No description provided for @kolkhozappOnlinePlay.
  ///
  /// In en, this message translates to:
  /// **'ONLINE PLAY'**
  String get kolkhozappOnlinePlay;

  /// No description provided for @kolkhozappJoinAnOpenGameOrEnterAnInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Join an open game or enter an invite code.'**
  String get kolkhozappJoinAnOpenGameOrEnterAnInviteCode;

  /// No description provided for @kolkhozappInviteCode.
  ///
  /// In en, this message translates to:
  /// **'INVITE CODE'**
  String get kolkhozappInviteCode;

  /// No description provided for @kolkhozappYourInviteCode.
  ///
  /// In en, this message translates to:
  /// **'YOUR INVITE CODE'**
  String get kolkhozappYourInviteCode;

  /// No description provided for @kolkhozappWaitingForPlayers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for players'**
  String get kolkhozappWaitingForPlayers;

  /// No description provided for @kolkhozappGameStartsInValue1s.
  ///
  /// In en, this message translates to:
  /// **'Game starts in {value1}s'**
  String kolkhozappGameStartsInValue1s({required Object value1});

  /// No description provided for @kolkhozappSearchingForPlayer.
  ///
  /// In en, this message translates to:
  /// **'Searching for Player'**
  String get kolkhozappSearchingForPlayer;

  /// No description provided for @kolkhozappCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get kolkhozappCopyCode;

  /// No description provided for @kolkhozappCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy Result'**
  String get kolkhozappCopyResult;

  /// No description provided for @kolkhozappCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get kolkhozappCopied;

  /// No description provided for @kolkhozappJoinGame.
  ///
  /// In en, this message translates to:
  /// **'Join Game'**
  String get kolkhozappJoinGame;

  /// No description provided for @kolkhozappAssignGame.
  ///
  /// In en, this message translates to:
  /// **'Assign Game'**
  String get kolkhozappAssignGame;

  /// No description provided for @kolkhozappKick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kolkhozappKick;

  /// No description provided for @kolkhozappOpenGames.
  ///
  /// In en, this message translates to:
  /// **'OPEN GAMES'**
  String get kolkhozappOpenGames;

  /// No description provided for @kolkhozappRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get kolkhozappRefresh;

  /// No description provided for @kolkhozappOpenOpenseats.
  ///
  /// In en, this message translates to:
  /// **'Open {openSeats}'**
  String kolkhozappOpenOpenseats({required Object openSeats});

  /// No description provided for @kolkhozappHost.
  ///
  /// In en, this message translates to:
  /// **'HOST'**
  String get kolkhozappHost;

  /// No description provided for @kolkhozappSeats.
  ///
  /// In en, this message translates to:
  /// **'SEATS'**
  String get kolkhozappSeats;

  /// No description provided for @kolkhozappTurn.
  ///
  /// In en, this message translates to:
  /// **'TURN'**
  String get kolkhozappTurn;

  /// No description provided for @kolkhozappMoves.
  ///
  /// In en, this message translates to:
  /// **'MOVES'**
  String get kolkhozappMoves;

  /// No description provided for @kolkhozappWaiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get kolkhozappWaiting;

  /// No description provided for @kolkhozappOpen.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get kolkhozappOpen;

  /// No description provided for @kolkhozappAverageRating.
  ///
  /// In en, this message translates to:
  /// **'AVG RATING'**
  String get kolkhozappAverageRating;

  /// No description provided for @kolkhozappPlayer.
  ///
  /// In en, this message translates to:
  /// **'PLAYER'**
  String get kolkhozappPlayer;

  /// No description provided for @kolkhozappScore.
  ///
  /// In en, this message translates to:
  /// **'SCORE'**
  String get kolkhozappScore;

  /// No description provided for @kolkhozappMedals.
  ///
  /// In en, this message translates to:
  /// **'MEDALS'**
  String get kolkhozappMedals;

  /// No description provided for @kolkhozappHand.
  ///
  /// In en, this message translates to:
  /// **'HAND'**
  String get kolkhozappHand;

  /// No description provided for @kolkhozappCellar.
  ///
  /// In en, this message translates to:
  /// **'CELLAR'**
  String get kolkhozappCellar;

  /// No description provided for @kolkhozappPlot.
  ///
  /// In en, this message translates to:
  /// **'PLOT'**
  String get kolkhozappPlot;

  /// No description provided for @kolkhozappController.
  ///
  /// In en, this message translates to:
  /// **'CONTROL'**
  String get kolkhozappController;

  /// No description provided for @kolkhozappBrigadeLeader.
  ///
  /// In en, this message translates to:
  /// **'BRIGADE LEADER'**
  String get kolkhozappBrigadeLeader;

  /// No description provided for @kolkhozappCurrentTurn.
  ///
  /// In en, this message translates to:
  /// **'CURRENT TURN'**
  String get kolkhozappCurrentTurn;

  /// No description provided for @kolkhozappAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get kolkhozappAny;

  /// No description provided for @kolkhozappHuman.
  ///
  /// In en, this message translates to:
  /// **'Human'**
  String get kolkhozappHuman;

  /// No description provided for @kolkhozappEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get kolkhozappEasy;

  /// No description provided for @kolkhozappMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get kolkhozappMedium;

  /// No description provided for @kolkhozappHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get kolkhozappHard;

  /// No description provided for @plotdisplayOtherStoresAboveActivePlayerSCellarBelow.
  ///
  /// In en, this message translates to:
  /// **'Other stores above, active player\'s cellar below.'**
  String get plotdisplayOtherStoresAboveActivePlayerSCellarBelow;

  /// No description provided for @plotdisplayAllJobsComplete.
  ///
  /// In en, this message translates to:
  /// **'All jobs complete.'**
  String get plotdisplayAllJobsComplete;

  /// No description provided for @plotdisplayAuditComplete.
  ///
  /// In en, this message translates to:
  /// **'Audit complete.'**
  String get plotdisplayAuditComplete;

  /// No description provided for @boardOptionspanelInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get boardOptionspanelInstant;

  /// No description provided for @boardOptionspanelFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get boardOptionspanelFast;

  /// No description provided for @boardOptionspanelNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get boardOptionspanelNormal;

  /// No description provided for @boardOptionspanelSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get boardOptionspanelSlow;

  /// No description provided for @boardOptionspanelSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get boardOptionspanelSession;

  /// No description provided for @boardOptionspanelAssist.
  ///
  /// In en, this message translates to:
  /// **'Assist'**
  String get boardOptionspanelAssist;

  /// No description provided for @boardOptionspanelDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get boardOptionspanelDisplay;

  /// No description provided for @boardOptionspanelRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get boardOptionspanelRules;

  /// No description provided for @boardOptionspanelMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get boardOptionspanelMenu;

  /// No description provided for @boardOptionspanelGameControls.
  ///
  /// In en, this message translates to:
  /// **'Game controls'**
  String get boardOptionspanelGameControls;

  /// No description provided for @boardOptionspanelHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get boardOptionspanelHowToPlay;

  /// No description provided for @boardOptionspanelSafeguards.
  ///
  /// In en, this message translates to:
  /// **'Safeguards'**
  String get boardOptionspanelSafeguards;

  /// No description provided for @boardOptionspanelConfirmNewGame.
  ///
  /// In en, this message translates to:
  /// **'Confirm new game'**
  String get boardOptionspanelConfirmNewGame;

  /// No description provided for @boardOptionspanelAskBeforeReplacingTheCurrentGame.
  ///
  /// In en, this message translates to:
  /// **'Ask before replacing the current game.'**
  String get boardOptionspanelAskBeforeReplacingTheCurrentGame;

  /// No description provided for @boardOptionspanelConfirmMainMenu.
  ///
  /// In en, this message translates to:
  /// **'Confirm main menu'**
  String get boardOptionspanelConfirmMainMenu;

  /// No description provided for @boardOptionspanelAskBeforeLeavingTheCurrentGame.
  ///
  /// In en, this message translates to:
  /// **'Ask before leaving the current game.'**
  String get boardOptionspanelAskBeforeLeavingTheCurrentGame;

  /// No description provided for @boardOptionspanelMoveHelp.
  ///
  /// In en, this message translates to:
  /// **'Move help'**
  String get boardOptionspanelMoveHelp;

  /// No description provided for @boardOptionspanelInvalidTapHints.
  ///
  /// In en, this message translates to:
  /// **'Invalid-tap hints'**
  String get boardOptionspanelInvalidTapHints;

  /// No description provided for @boardOptionspanelShowTheForemanReminderWhenYouTapAnIllegalC.
  ///
  /// In en, this message translates to:
  /// **'Show the Foreman reminder when you tap an illegal card.'**
  String get boardOptionspanelShowTheForemanReminderWhenYouTapAnIllegalC;

  /// No description provided for @boardOptionspanelAnimationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Animation speed'**
  String get boardOptionspanelAnimationSpeed;

  /// No description provided for @boardPlotpanelRequisition.
  ///
  /// In en, this message translates to:
  /// **'Requisition'**
  String get boardPlotpanelRequisition;

  /// No description provided for @boardPlotpanelPrivatePlot.
  ///
  /// In en, this message translates to:
  /// **'Private plot'**
  String get boardPlotpanelPrivatePlot;

  /// No description provided for @boardPlotpanelGameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get boardPlotpanelGameOver;

  /// No description provided for @boardPlotpanelWinnerWinnernameWinnerscore.
  ///
  /// In en, this message translates to:
  /// **'Winner: {winnerName} - {winnerScore}'**
  String boardPlotpanelWinnerWinnernameWinnerscore({
    required Object winnerName,
    required Object winnerScore,
  });

  /// No description provided for @boardHandtrayUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get boardHandtrayUndo;

  /// No description provided for @boardHandtrayPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get boardHandtrayPlay;

  /// No description provided for @handConsoleYourTurnToPlay.
  ///
  /// In en, this message translates to:
  /// **'Your turn to play'**
  String get handConsoleYourTurnToPlay;

  /// No description provided for @handConsoleChooseSwap.
  ///
  /// In en, this message translates to:
  /// **'Choose a swap'**
  String get handConsoleChooseSwap;

  /// No description provided for @handConsoleAssignTrick.
  ///
  /// In en, this message translates to:
  /// **'Assign the trick'**
  String get handConsoleAssignTrick;

  /// No description provided for @handConsoleReviewRequisition.
  ///
  /// In en, this message translates to:
  /// **'Review requisition'**
  String get handConsoleReviewRequisition;

  /// No description provided for @handConsoleWaitingForValue1.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {value1}'**
  String handConsoleWaitingForValue1({required Object value1});

  /// No description provided for @handConsoleWaitingForValue1ToPlay.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {value1} to play'**
  String handConsoleWaitingForValue1ToPlay({required Object value1});

  /// No description provided for @handConsoleWaitingForValue1ToSwap.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {value1} to swap'**
  String handConsoleWaitingForValue1ToSwap({required Object value1});

  /// No description provided for @handConsoleWaitingForValue1ToAssign.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {value1} to assign'**
  String handConsoleWaitingForValue1ToAssign({required Object value1});

  /// No description provided for @handConsoleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get handConsoleContinue;

  /// No description provided for @boardJobspanelDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get boardJobspanelDone;

  /// No description provided for @boardJobspanelTapToAssign.
  ///
  /// In en, this message translates to:
  /// **'TAP TO ASSIGN'**
  String get boardJobspanelTapToAssign;

  /// No description provided for @boardBoardrailBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardBoardrailBoard;

  /// No description provided for @boardBoardrailJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get boardBoardrailJobs;

  /// No description provided for @boardBoardrailNorth.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get boardBoardrailNorth;

  /// No description provided for @boardBoardrailCellar.
  ///
  /// In en, this message translates to:
  /// **'Cellar'**
  String get boardBoardrailCellar;

  /// No description provided for @boardBoardrailLang.
  ///
  /// In en, this message translates to:
  /// **'Lang'**
  String get boardBoardrailLang;

  /// No description provided for @boardBoardrailBrigade.
  ///
  /// In en, this message translates to:
  /// **'Brigade'**
  String get boardBoardrailBrigade;

  /// No description provided for @boardBoardrailTheNorth.
  ///
  /// In en, this message translates to:
  /// **'The North'**
  String get boardBoardrailTheNorth;

  /// No description provided for @ruleSummary1Title.
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get ruleSummary1Title;

  /// No description provided for @ruleSummary1Body.
  ///
  /// In en, this message translates to:
  /// **'Complete collective farm jobs while protecting your private plot. Highest score wins!'**
  String get ruleSummary1Body;

  /// No description provided for @ruleSummary2Title.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get ruleSummary2Title;

  /// No description provided for @ruleSummary2Body.
  ///
  /// In en, this message translates to:
  /// **'Play cards to tricks - must follow lead suit if able.'**
  String get ruleSummary2Body;

  /// No description provided for @ruleSummary3Title.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get ruleSummary3Title;

  /// No description provided for @ruleSummary3Body.
  ///
  /// In en, this message translates to:
  /// **'Jobs need 40 work hours to complete.'**
  String get ruleSummary3Body;

  /// No description provided for @ruleSummary4Title.
  ///
  /// In en, this message translates to:
  /// **'Trump Face Cards'**
  String get ruleSummary4Title;

  /// No description provided for @ruleSummary4Body.
  ///
  /// In en, this message translates to:
  /// **'Jack, Queen, and King have special powers in nomenclature games.'**
  String get ruleSummary4Body;

  /// No description provided for @ruleSummary5Title.
  ///
  /// In en, this message translates to:
  /// **'Scoring'**
  String get ruleSummary5Title;

  /// No description provided for @ruleSummary5Body.
  ///
  /// In en, this message translates to:
  /// **'Cards in your plot equal your score. Highest score wins.'**
  String get ruleSummary5Body;

  /// No description provided for @ruleSummary6Title.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get ruleSummary6Title;

  /// No description provided for @ruleSummary6Body.
  ///
  /// In en, this message translates to:
  /// **'Win tricks, then assign captured cards to matching jobs.'**
  String get ruleSummary6Body;

  /// No description provided for @ruleSummary7Title.
  ///
  /// In en, this message translates to:
  /// **'Protect'**
  String get ruleSummary7Title;

  /// No description provided for @ruleSummary7Body.
  ///
  /// In en, this message translates to:
  /// **'Keep plot cards safe from failed-job requisition.'**
  String get ruleSummary7Body;

  /// No description provided for @ruleSummary8Title.
  ///
  /// In en, this message translates to:
  /// **'Trump faces'**
  String get ruleSummary8Title;

  /// No description provided for @ruleSummary8Body.
  ///
  /// In en, this message translates to:
  /// **'Jack goes north, Queen exposes, King doubles exile.'**
  String get ruleSummary8Body;

  /// No description provided for @tutorialStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the collective'**
  String get tutorialStep1Title;

  /// No description provided for @tutorialStep1Body.
  ///
  /// In en, this message translates to:
  /// **'This is a real game, comrade — play while we talk. Your goal: end the Five-Year Plan with the most points hidden in your cellar.'**
  String get tutorialStep1Body;

  /// No description provided for @tutorialStep1Tip.
  ///
  /// In en, this message translates to:
  /// **'High hidden cards are your bank. Losing one to the North can swing the final score.'**
  String get tutorialStep1Tip;

  /// No description provided for @tutorialStep1Callout.
  ///
  /// In en, this message translates to:
  /// **'The buttons below turn my lessons. The board stays yours.'**
  String get tutorialStep1Callout;

  /// No description provided for @tutorialStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Read the work board'**
  String get tutorialStep2Title;

  /// No description provided for @tutorialStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Four jobs each year, one per crop. Each reward pile has ranks 1–4 plus one hidden lotto rank from 5–K; the counter is work hours — 40 completes the job.'**
  String get tutorialStep2Body;

  /// No description provided for @tutorialStep2Tip.
  ///
  /// In en, this message translates to:
  /// **'Failed jobs summon requisition at year\'s end. Remember which crops look doomed.'**
  String get tutorialStep2Tip;

  /// No description provided for @tutorialStep2Callout.
  ///
  /// In en, this message translates to:
  /// **'Find the four job counters along the top of the table.'**
  String get tutorialStep2Callout;

  /// No description provided for @tutorialStep3Title.
  ///
  /// In en, this message translates to:
  /// **'The trump crop'**
  String get tutorialStep3Title;

  /// No description provided for @tutorialStep3Body.
  ///
  /// In en, this message translates to:
  /// **'In planning, one crop is declared the State\'s main task — trump. In year five, the leftover deal card is revealed to set trump; Saboteur means no trump.'**
  String get tutorialStep3Body;

  /// No description provided for @tutorialStep3Tip.
  ///
  /// In en, this message translates to:
  /// **'Pick trump for the hand you expect to play, not only for the biggest card you see.'**
  String get tutorialStep3Tip;

  /// No description provided for @tutorialStep3Callout.
  ///
  /// In en, this message translates to:
  /// **'Waiting for trump to be declared…'**
  String get tutorialStep3Callout;

  /// No description provided for @tutorialStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Play a card'**
  String get tutorialStep4Title;

  /// No description provided for @tutorialStep4Body.
  ///
  /// In en, this message translates to:
  /// **'Follow the led crop if you can — legal cards glow. Out of that crop? Play anything, even trump.'**
  String get tutorialStep4Body;

  /// No description provided for @tutorialStep4Tip.
  ///
  /// In en, this message translates to:
  /// **'Ducking a trick is allowed — and often wise. Winners attract attention.'**
  String get tutorialStep4Tip;

  /// No description provided for @tutorialStep4Callout.
  ///
  /// In en, this message translates to:
  /// **'Play a card from your hand when your turn comes.'**
  String get tutorialStep4Callout;

  /// No description provided for @tutorialStep5Title.
  ///
  /// In en, this message translates to:
  /// **'Taking the trick'**
  String get tutorialStep5Title;

  /// No description provided for @tutorialStep5Body.
  ///
  /// In en, this message translates to:
  /// **'Highest card of the led crop wins — unless trump lands; then the highest trump. The winner takes a medal and becomes brigade leader.'**
  String get tutorialStep5Body;

  /// No description provided for @tutorialStep5Tip.
  ///
  /// In en, this message translates to:
  /// **'Medals break ties at the end — but every win paints a target on your cellar.'**
  String get tutorialStep5Tip;

  /// No description provided for @tutorialStep5Callout.
  ///
  /// In en, this message translates to:
  /// **'Watch who takes this trick.'**
  String get tutorialStep5Callout;

  /// No description provided for @tutorialStep6Title.
  ///
  /// In en, this message translates to:
  /// **'Assign the labor'**
  String get tutorialStep6Title;

  /// No description provided for @tutorialStep6Body.
  ///
  /// In en, this message translates to:
  /// **'The brigade leader sends the trick\'s cards to jobs — only crops present in the trick are legal targets. A card\'s rank is its hours.'**
  String get tutorialStep6Body;

  /// No description provided for @tutorialStep6Tip.
  ///
  /// In en, this message translates to:
  /// **'Assign work to protect the crops that match your best cellar cards.'**
  String get tutorialStep6Tip;

  /// No description provided for @tutorialStep6Callout.
  ///
  /// In en, this message translates to:
  /// **'When you win a trick, tap its cards onto jobs.'**
  String get tutorialStep6Callout;

  /// No description provided for @tutorialStep7Title.
  ///
  /// In en, this message translates to:
  /// **'Meet the quota'**
  String get tutorialStep7Title;

  /// No description provided for @tutorialStep7Body.
  ///
  /// In en, this message translates to:
  /// **'A job that reaches 40 hours is complete: its reward drops into the closer\'s cellar, and that crop is safe from requisition this year.'**
  String get tutorialStep7Body;

  /// No description provided for @tutorialStep7Tip.
  ///
  /// In en, this message translates to:
  /// **'A finished job pays you and protects you. Two birds, one quota.'**
  String get tutorialStep7Tip;

  /// No description provided for @tutorialStep7Callout.
  ///
  /// In en, this message translates to:
  /// **'Push a job to 40 hours to claim its reward.'**
  String get tutorialStep7Callout;

  /// No description provided for @tutorialStep8Title.
  ///
  /// In en, this message translates to:
  /// **'The leftover card'**
  String get tutorialStep8Title;

  /// No description provided for @tutorialStep8Body.
  ///
  /// In en, this message translates to:
  /// **'Only four tricks are played. Your fifth card slips face-down into your cellar at year\'s end — its rank becomes points.'**
  String get tutorialStep8Body;

  /// No description provided for @tutorialStep8Tip.
  ///
  /// In en, this message translates to:
  /// **'Steer the year so your best card is the one that survives.'**
  String get tutorialStep8Tip;

  /// No description provided for @tutorialStep8Callout.
  ///
  /// In en, this message translates to:
  /// **'Your unplayed card banks itself when the year ends.'**
  String get tutorialStep8Callout;

  /// No description provided for @tutorialStep9Title.
  ///
  /// In en, this message translates to:
  /// **'This is requisition'**
  String get tutorialStep9Title;

  /// No description provided for @tutorialStep9Body.
  ///
  /// In en, this message translates to:
  /// **'If N crop suits fail, each vulnerable player loses their N highest cellar cards across those suits. Party Official adds one; Drunkard removes its suit from the quota.'**
  String get tutorialStep9Body;

  /// No description provided for @tutorialStep9Tip.
  ///
  /// In en, this message translates to:
  /// **'Never won a trick? Nothing to confess. Cowardice has its rewards.'**
  String get tutorialStep9Tip;

  /// No description provided for @tutorialStep9Callout.
  ///
  /// In en, this message translates to:
  /// **'Read the requisition report carefully.'**
  String get tutorialStep9Callout;

  /// No description provided for @tutorialStep10Title.
  ///
  /// In en, this message translates to:
  /// **'The yearly swap'**
  String get tutorialStep10Title;

  /// No description provided for @tutorialStep10Body.
  ///
  /// In en, this message translates to:
  /// **'From year two, you may trade one hand card for one cellar card before the trick begins.'**
  String get tutorialStep10Body;

  /// No description provided for @tutorialStep10Tip.
  ///
  /// In en, this message translates to:
  /// **'Bury high cards while they are safe; pull out crops that look doomed.'**
  String get tutorialStep10Tip;

  /// No description provided for @tutorialStep10Callout.
  ///
  /// In en, this message translates to:
  /// **'Consider your swap before the trick begins.'**
  String get tutorialStep10Callout;

  /// No description provided for @tutorialStep11Title.
  ///
  /// In en, this message translates to:
  /// **'Beware the Wrecker'**
  String get tutorialStep11Title;

  /// No description provided for @tutorialStep11Body.
  ///
  /// In en, this message translates to:
  /// **'One joker hides among the workers: he follows any suit and brings 0 hours — and any job holding him fails inspection.'**
  String get tutorialStep11Body;

  /// No description provided for @tutorialStep11Tip.
  ///
  /// In en, this message translates to:
  /// **'Win him boldly, bury him bitterly — or make him someone else\'s problem.'**
  String get tutorialStep11Tip;

  /// No description provided for @tutorialStep11Callout.
  ///
  /// In en, this message translates to:
  /// **'He plays by Kolkhoz rules — watch for the wild card.'**
  String get tutorialStep11Callout;

  /// No description provided for @tutorialStep12Title.
  ///
  /// In en, this message translates to:
  /// **'Year five is famine'**
  String get tutorialStep12Title;

  /// No description provided for @tutorialStep12Body.
  ///
  /// In en, this message translates to:
  /// **'The last year is lean: four cards, three tricks, no trump at all. Short, and usually decisive.'**
  String get tutorialStep12Body;

  /// No description provided for @tutorialStep12Tip.
  ///
  /// In en, this message translates to:
  /// **'Save flexible high cards for famine; without trump a bad lead is hard to escape.'**
  String get tutorialStep12Tip;

  /// No description provided for @tutorialStep12Callout.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the famine year…'**
  String get tutorialStep12Callout;

  /// No description provided for @tutorialStep13Title.
  ///
  /// In en, this message translates to:
  /// **'Highest final cellar wins'**
  String get tutorialStep13Title;

  /// No description provided for @tutorialStep13Body.
  ///
  /// In en, this message translates to:
  /// **'After year five, every cellar card counts its rank. Highest total wins the Plan; medals break ties. Make me proud, comrade.'**
  String get tutorialStep13Body;

  /// No description provided for @tutorialStep13Tip.
  ///
  /// In en, this message translates to:
  /// **'One protected King is worth a year of caution.'**
  String get tutorialStep13Tip;

  /// No description provided for @tutorialStep13Callout.
  ///
  /// In en, this message translates to:
  /// **'Finish the Plan — Misha is watching.'**
  String get tutorialStep13Callout;

  /// No description provided for @suitWheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get suitWheat;

  /// No description provided for @suitSunflower.
  ///
  /// In en, this message translates to:
  /// **'Sunflower'**
  String get suitSunflower;

  /// No description provided for @suitPotatoes.
  ///
  /// In en, this message translates to:
  /// **'Potatoes'**
  String get suitPotatoes;

  /// No description provided for @suitBeets.
  ///
  /// In en, this message translates to:
  /// **'Beets'**
  String get suitBeets;

  /// No description provided for @phasePlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get phasePlanning;

  /// No description provided for @phaseSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get phaseSwap;

  /// No description provided for @phaseTrick.
  ///
  /// In en, this message translates to:
  /// **'Trick'**
  String get phaseTrick;

  /// No description provided for @phaseAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get phaseAssignment;

  /// No description provided for @phaseRequisition.
  ///
  /// In en, this message translates to:
  /// **'Requisition'**
  String get phaseRequisition;

  /// No description provided for @phaseGameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get phaseGameOver;

  /// No description provided for @languageSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Russian'**
  String get languageSwitchTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
