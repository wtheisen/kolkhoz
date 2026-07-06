import 'app_settings.dart';

class RuleSummary {
  const RuleSummary({
    required this.iconPath,
    required this.titleEn,
    required this.titleRu,
    required this.bodyEn,
    required this.bodyRu,
  });

  final String iconPath;
  final String titleEn;
  final String titleRu;
  final String bodyEn;
  final String bodyRu;

  String title(KolkhozLanguage language) {
    return language.text(en: titleEn, ru: titleRu);
  }

  String body(KolkhozLanguage language) {
    return language.text(en: bodyEn, ru: bodyRu);
  }
}

const lobbyRuleSummaries = [
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-plot.png',
    titleEn: 'Objective',
    titleRu: 'Цель',
    bodyEn:
        'Complete collective farm jobs while protecting your private plot. Highest score wins!',
    bodyRu:
        'Выполняйте работы колхоза, защищая свой участок. Побеждает наибольший счёт!',
  ),
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-hand.png',
    titleEn: 'Gameplay',
    titleRu: 'Игра',
    bodyEn: 'Play cards to tricks - must follow lead suit if able.',
    bodyRu: 'Играйте карты во взятки - следуйте масти если возможно.',
  ),
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-jobs.png',
    titleEn: 'Jobs',
    titleRu: 'Работы',
    bodyEn: 'Jobs need 40 work hours to complete.',
    bodyRu: 'Работы требуют 40 часов для завершения.',
  ),
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-warning.png',
    titleEn: 'Trump Face Cards',
    titleRu: 'Козырные карты',
    bodyEn: 'Jack, Queen, and King have special powers in nomenclature games.',
    bodyRu: 'Валет, Дама и Король имеют особые силы в игре с номенклатурой.',
  ),
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
    titleEn: 'Scoring',
    titleRu: 'Подсчёт очков',
    bodyEn: 'Cards in your plot equal your score. Highest score wins.',
    bodyRu: 'Карты на вашем участке дают очки. Побеждает тот, у кого больше.',
  ),
];

const optionsRuleSummaries = [
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-jobs.png',
    titleEn: 'Work',
    titleRu: 'Работы',
    bodyEn: 'Win tricks, then assign captured cards to matching jobs.',
    bodyRu: 'Выигрывайте взятки и назначайте карты на подходящие работы.',
  ),
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-plot.png',
    titleEn: 'Protect',
    titleRu: 'Защита',
    bodyEn: 'Keep plot cards safe from failed-job requisition.',
    bodyRu: 'Берегите карты участка от реквизиции за проваленные работы.',
  ),
  RuleSummary(
    iconPath: 'ios_resources/Icons/icon-warning.png',
    titleEn: 'Trump faces',
    titleRu: 'Козырные карты',
    bodyEn: 'Jack goes north, Queen exposes, King doubles exile.',
    bodyRu: 'Валет уходит на Север, Дама раскрывает, Король удваивает ссылку.',
  ),
];

class TutorialStepContent {
  const TutorialStepContent({
    required this.titleEn,
    required this.titleRu,
    required this.bodyEn,
    required this.bodyRu,
    required this.tipEn,
    required this.tipRu,
    required this.calloutEn,
    required this.calloutRu,
    required this.iconPath,
  });

  final String titleEn;
  final String titleRu;
  final String bodyEn;
  final String bodyRu;
  final String tipEn;
  final String tipRu;
  final String calloutEn;
  final String calloutRu;
  final String iconPath;

  String title(KolkhozLanguage language) {
    return language.text(en: titleEn, ru: titleRu);
  }

  String body(KolkhozLanguage language) {
    return language.text(en: bodyEn, ru: bodyRu);
  }

  String tip(KolkhozLanguage language) {
    return language.text(en: tipEn, ru: tipRu);
  }

  String callout(KolkhozLanguage language) {
    return language.text(en: calloutEn, ru: calloutRu);
  }
}

const tutorialStepContents = [
  TutorialStepContent(
    titleEn: 'First, read the table',
    titleRu: 'Сначала осмотрите стол',
    bodyEn:
        'Every year has four jobs. Your hand wins tricks; your cellar keeps the points that survive requisition.',
    bodyRu:
        'Каждый год есть четыре работы. Рука выигрывает взятки, а подвал сохраняет очки, которые переживут реквизицию.',
    tipEn:
        'High hidden cards are your bank. Losing one to the North can swing the final score.',
    tipRu:
        'Старшие скрытые карты - ваш запас. Потеря одной на Севере может решить итоговый счет.',
    calloutEn: 'Tap the Cellar icon to inspect your kept card.',
    calloutRu: 'Нажмите значок подвала, чтобы проверить сохраненную карту.',
    iconPath: 'ios_resources/Icons/icon-plot.png',
  ),
  TutorialStepContent(
    titleEn: 'Pick the trump crop',
    titleRu: 'Выберите козырную культуру',
    bodyEn:
        'In planning, the selector chooses one crop as trump. Trump cards can beat the led crop.',
    bodyRu:
        'В планировании выбранный игрок назначает одну культуру козырем. Козыри могут побить масть хода.',
    tipEn:
        'Pick trump for the hand you expect to play, not only for the biggest card you see.',
    tipRu:
        'Выбирайте козырь под руку, которую хотите разыграть, а не только под самую крупную карту.',
    calloutEn: 'Tap Wheat as trump.',
    calloutRu: 'Нажмите пшеницу как козырь.',
    iconPath: 'ios_resources/Icons/icon-jobs.png',
  ),
  TutorialStepContent(
    titleEn: 'Win the trick',
    titleRu: 'Выиграйте взятку',
    bodyEn:
        'Follow suit when you can. Highest card in the winning suit takes the trick.',
    bodyRu:
        'Следуйте масти, когда можете. Старшая карта в выигравшей масти берет взятку.',
    tipEn:
        'Winning is power, but it paints a target on your cellar for the rest of the year.',
    tipRu: 'Победа дает власть, но делает ваш подвал целью до конца года.',
    calloutEn: 'Tap a highlighted legal card.',
    calloutRu: 'Нажмите подсвеченную разрешенную карту.',
    iconPath: 'ios_resources/Icons/icon-hand.png',
  ),
  TutorialStepContent(
    titleEn: 'Medal now, risk later',
    titleRu: 'Медаль сейчас, риск потом',
    bodyEn:
        'Trick winners earn medals. Medals break ties, but winning also exposes you to requisition.',
    bodyRu:
        'Победители взяток получают медали. Медали решают ничьи, но победа также открывает вас реквизиции.',
    tipEn:
        'Sometimes ducking a trick is correct if your cellar holds a card you cannot afford to lose.',
    tipRu:
        'Иногда лучше уступить взятку, если в подвале карта, которую нельзя потерять.',
    calloutEn: 'Continue to see where the risk lands.',
    calloutRu: 'Продолжите, чтобы увидеть, куда попадет риск.',
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
  ),
  TutorialStepContent(
    titleEn: 'The winner assigns work',
    titleRu: 'Победитель назначает работу',
    bodyEn:
        'As brigade leader, you send captured cards into jobs to protect matching crops.',
    bodyRu:
        'Как бригадир, отправляйте взятые карты на работы, чтобы защитить подходящие культуры.',
    tipEn:
        'Assign work to protect the suits that match your best cellar cards.',
    tipRu: 'Назначайте работу, чтобы защищать масти ваших лучших карт подвала.',
    calloutEn: 'Tap the Jobs icon to view the work board.',
    calloutRu: 'Нажмите значок работ, чтобы открыть доску работ.',
    iconPath: 'ios_resources/Icons/icon-jobs.png',
  ),
  TutorialStepContent(
    titleEn: 'Finish jobs for rewards',
    titleRu: 'Завершайте работы ради наград',
    bodyEn:
        'When a job reaches 40 hours, the revealed reward card goes into the winner\'s cellar.',
    bodyRu:
        'Когда работа набирает 40 часов, открытая награда уходит в подвал победителя.',
    tipEn:
        'A finished job both pays you and stops that crop from causing requisition this year.',
    tipRu:
        'Завершенная работа приносит награду и не вызывает реквизицию этой культуры в этом году.',
    calloutEn: 'Inspect completed job rewards, then continue.',
    calloutRu: 'Проверьте награды завершенных работ, затем продолжайте.',
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
  ),
  TutorialStepContent(
    titleEn: 'This is requisition',
    titleRu: 'Это реквизиция',
    bodyEn:
        'Failed crops can reveal and exile matching cellar cards from players who won tricks.',
    bodyRu:
        'Проваленные культуры могут раскрыть и сослать карты подвала у игроков, выигравших взятки.',
    tipEn:
        'A medal may break a tie later, but losing a high cellar card hurts immediately.',
    tipRu:
        'Медаль может позже решить ничью, но потеря старшей карты сразу бьет по счету.',
    calloutEn: 'Tap the requisition report.',
    calloutRu: 'Нажмите отчет о реквизиции.',
    iconPath: 'ios_resources/Icons/icon-north.png',
  ),
  TutorialStepContent(
    titleEn: 'Swap before later years',
    titleRu: 'Обмен перед следующими годами',
    bodyEn:
        'From year two, you may trade one hand card with your cellar before tricks begin.',
    bodyRu:
        'Со второго года можно обменять одну карту руки с подвалом перед взятками.',
    tipEn:
        'Swap high cards into the cellar when they can stay safe; pull danger cards out before requisition.',
    tipRu:
        'Убирайте старшие карты в подвал, когда они в безопасности; вытаскивайте опасные перед реквизицией.',
    calloutEn: 'Tap the Cellar icon again before you swap.',
    calloutRu: 'Снова нажмите значок подвала перед обменом.',
    iconPath: 'ios_resources/Icons/icon-cellar.png',
  ),
  TutorialStepContent(
    titleEn: 'Year five is famine',
    titleRu: 'Пятый год - голод',
    bodyEn:
        'The last year has no trump and only three tricks. It is short and usually decisive.',
    bodyRu:
        'В последний год нет козыря и только три взятки. Он короткий и часто решающий.',
    tipEn:
        'Save flexible high cards for famine; no trump means a bad lead is harder to escape.',
    tipRu:
        'Сохраните гибкие старшие карты на голод; без козыря плохой ход тяжелее исправить.',
    calloutEn: 'Continue when you have seen the famine board.',
    calloutRu: 'Продолжайте, когда осмотрите доску голода.',
    iconPath: 'ios_resources/Icons/icon-famine.png',
  ),
  TutorialStepContent(
    titleEn: 'Highest final cellar wins',
    titleRu: 'Побеждает лучший итог подвала',
    bodyEn:
        'At the end, hidden cellar cards count too. Highest cellar score wins; medals break ties.',
    bodyRu:
        'В конце скрытые карты подвала тоже считаются. Лучший счет подвала побеждает; медали решают ничьи.',
    tipEn:
        'Bigger ranks mean bigger cellar points. One protected high card can decide the whole game.',
    tipRu:
        'Большие ранги дают больше очков подвала. Одна защищенная старшая карта может решить игру.',
    calloutEn: 'Review the final score, then finish.',
    calloutRu: 'Проверьте итоговый счет и завершите.',
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
  ),
];
