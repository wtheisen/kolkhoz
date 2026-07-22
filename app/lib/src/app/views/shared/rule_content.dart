import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';

class RuleSummary {
  const RuleSummary({
    required this.iconPath,
    required this.titleKey,
    required this.bodyKey,
  });

  final String iconPath;
  final KolkhozText titleKey;
  final KolkhozText bodyKey;

  String title(KolkhozLanguage language) => language.t(titleKey);

  String body(KolkhozLanguage language) => language.t(bodyKey);
}

const lobbyRuleSummaries = [
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-plot.png',
    titleKey: KolkhozText.ruleSummary1Title,
    bodyKey: KolkhozText.ruleSummary1Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-hand.png',
    titleKey: KolkhozText.ruleSummary2Title,
    bodyKey: KolkhozText.ruleSummary2Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-jobs.png',
    titleKey: KolkhozText.ruleSummary3Title,
    bodyKey: KolkhozText.ruleSummary3Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-warning.png',
    titleKey: KolkhozText.ruleSummary4Title,
    bodyKey: KolkhozText.ruleSummary4Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-medal-star.png',
    titleKey: KolkhozText.ruleSummary5Title,
    bodyKey: KolkhozText.ruleSummary5Body,
  ),
];

const optionsRuleSummaries = [
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-jobs.png',
    titleKey: KolkhozText.ruleSummary6Title,
    bodyKey: KolkhozText.ruleSummary6Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-plot.png',
    titleKey: KolkhozText.ruleSummary7Title,
    bodyKey: KolkhozText.ruleSummary7Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-warning.png',
    titleKey: KolkhozText.ruleSummary8Title,
    bodyKey: KolkhozText.ruleSummary8Body,
  ),
];

/// Board region a tutorial step points the player at.
enum TutorialFocus { none, rail, jobs, table, hand }

/// Live-game event that completes a tutorial step automatically.
enum TutorialAdvance {
  manual,
  trumpChosen,
  cardPlayed,
  trickTaken,
  workAssigned,
  jobCompleted,
  yearEnd,
  swapPhase,
  famineYear,
}

class TutorialStepContent {
  const TutorialStepContent({
    required this.titleKey,
    required this.bodyKey,
    required this.tipKey,
    required this.calloutKey,
    required this.iconPath,
    this.focus = TutorialFocus.none,
    this.advance = TutorialAdvance.manual,
  });

  final KolkhozText titleKey;
  final KolkhozText bodyKey;
  final KolkhozText tipKey;
  final KolkhozText calloutKey;
  final String iconPath;
  final TutorialFocus focus;
  final TutorialAdvance advance;

  String title(KolkhozLanguage language) => language.t(titleKey);

  String body(KolkhozLanguage language) => language.t(bodyKey);

  String tip(KolkhozLanguage language) => language.t(tipKey);

  String callout(KolkhozLanguage language) => language.t(calloutKey);
}

const tutorialStepContents = [
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep1Title,
    bodyKey: KolkhozText.tutorialStep1Body,
    tipKey: KolkhozText.tutorialStep1Tip,
    calloutKey: KolkhozText.tutorialStep1Callout,
    iconPath: 'assets/ui/Icons/icon-plot.png',
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep2Title,
    bodyKey: KolkhozText.tutorialStep2Body,
    tipKey: KolkhozText.tutorialStep2Tip,
    calloutKey: KolkhozText.tutorialStep2Callout,
    iconPath: 'assets/ui/Icons/icon-jobs.png',
    focus: TutorialFocus.jobs,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep3Title,
    bodyKey: KolkhozText.tutorialStep3Body,
    tipKey: KolkhozText.tutorialStep3Tip,
    calloutKey: KolkhozText.tutorialStep3Callout,
    iconPath: 'assets/ui/Icons/icon-crop-seal.png',
    focus: TutorialFocus.table,
    advance: TutorialAdvance.trumpChosen,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep4Title,
    bodyKey: KolkhozText.tutorialStep4Body,
    tipKey: KolkhozText.tutorialStep4Tip,
    calloutKey: KolkhozText.tutorialStep4Callout,
    iconPath: 'assets/ui/Icons/icon-hand.png',
    focus: TutorialFocus.hand,
    advance: TutorialAdvance.cardPlayed,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep5Title,
    bodyKey: KolkhozText.tutorialStep5Body,
    tipKey: KolkhozText.tutorialStep5Tip,
    calloutKey: KolkhozText.tutorialStep5Callout,
    iconPath: 'assets/ui/Icons/icon-medal-star.png',
    focus: TutorialFocus.table,
    advance: TutorialAdvance.trickTaken,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep6Title,
    bodyKey: KolkhozText.tutorialStep6Body,
    tipKey: KolkhozText.tutorialStep6Tip,
    calloutKey: KolkhozText.tutorialStep6Callout,
    iconPath: 'assets/ui/Icons/icon-jobs.png',
    focus: TutorialFocus.jobs,
    advance: TutorialAdvance.workAssigned,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep7Title,
    bodyKey: KolkhozText.tutorialStep7Body,
    tipKey: KolkhozText.tutorialStep7Tip,
    calloutKey: KolkhozText.tutorialStep7Callout,
    iconPath: 'assets/ui/Icons/icon-status-reward-claimed.png',
    focus: TutorialFocus.jobs,
    advance: TutorialAdvance.jobCompleted,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep8Title,
    bodyKey: KolkhozText.tutorialStep8Body,
    tipKey: KolkhozText.tutorialStep8Tip,
    calloutKey: KolkhozText.tutorialStep8Callout,
    iconPath: 'assets/ui/Icons/icon-cellar.png',
    focus: TutorialFocus.hand,
    advance: TutorialAdvance.yearEnd,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep9Title,
    bodyKey: KolkhozText.tutorialStep9Body,
    tipKey: KolkhozText.tutorialStep9Tip,
    calloutKey: KolkhozText.tutorialStep9Callout,
    iconPath: 'assets/ui/Icons/icon-north.png',
    focus: TutorialFocus.table,
    advance: TutorialAdvance.swapPhase,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep10Title,
    bodyKey: KolkhozText.tutorialStep10Body,
    tipKey: KolkhozText.tutorialStep10Tip,
    calloutKey: KolkhozText.tutorialStep10Callout,
    iconPath: 'assets/ui/Icons/icon-cellar.png',
    focus: TutorialFocus.hand,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep11Title,
    bodyKey: KolkhozText.tutorialStep11Body,
    tipKey: KolkhozText.tutorialStep11Tip,
    calloutKey: KolkhozText.tutorialStep11Callout,
    iconPath: 'assets/ui/Icons/icon-warning.png',
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep12Title,
    bodyKey: KolkhozText.tutorialStep12Body,
    tipKey: KolkhozText.tutorialStep12Tip,
    calloutKey: KolkhozText.tutorialStep12Callout,
    iconPath: 'assets/ui/Icons/icon-famine.png',
    focus: TutorialFocus.table,
    advance: TutorialAdvance.famineYear,
  ),
  TutorialStepContent(
    titleKey: KolkhozText.tutorialStep13Title,
    bodyKey: KolkhozText.tutorialStep13Body,
    tipKey: KolkhozText.tutorialStep13Tip,
    calloutKey: KolkhozText.tutorialStep13Callout,
    iconPath: 'assets/ui/Icons/icon-medal-star.png',
  ),
];
