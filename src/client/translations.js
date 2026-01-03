// Translation strings for English and Russian

export const translations = {
  en: {
    // Nav bar
    menu: 'Menu',
    brigade: 'Brigade',
    jobs: 'Jobs',
    theNorth: 'The North',
    plot: 'Cellar',
    toggleLanguage: 'Toggle Language',

    // Info bar
    year: 'Year',
    task: 'Task:',
    famineYear: 'Famine Year',
    lead: 'Lead:',
    cellar: 'Cellar:',

    // Player info
    you: 'You',
    player: 'Player',
    pts: 'pts',
    cards: 'cards',
    yourTurn: 'Your turn',

    // Jobs
    wheat: 'Wheat',
    beets: 'Beets',
    potatoes: 'Potatoes',
    sunflower: 'Sunflower',
    dropHere: 'Drop here',

    // Swap phase
    cardSwap: 'Card Swap',
    hidden: 'Hidden',
    rewards: 'Rewards',
    confirmed: 'Confirmed',
    confirm: 'Confirm',
    waitingForOthers: 'Waiting for others...',

    // Requisition
    requisition: 'Requisition',
    failed: 'Failed:',
    yearComplete: 'Year {year} Complete',
    cardsToNorth: 'Cards to North:',
    allJobsComplete: 'All jobs complete!',
    continueToYear: 'Continue to Year {year}',

    // Trump selection
    chooseMainTask: 'Choose Main Task',

    // Game over
    gameOver: 'Game Over!',
    winner: 'Winner:',
    highestScoreWins: '(Highest score wins)',

    // Rules
    rules: 'Rules',
    objective: 'Objective',
    gameplay: 'Gameplay',
    trumpFaceCards: 'Trump Face Cards',
    objectiveText: 'Complete collective farm jobs while protecting your private plot. Highest score wins!',
    gameplayRule1: 'Play cards to tricks - must follow lead suit if able',
    gameplayRule2: 'Trick winner assigns cards to matching job suits',
    gameplayRule3: 'Jobs need 40 work hours to complete',
    jackDesc: 'Worth 0 hours, gets exiled instead of your cards',
    queenDesc: 'All players become vulnerable',
    kingDesc: 'Exiles two cards instead of one',
    jackName: 'Drunk',
    queenName: 'Informer',
    kingName: 'Official',
    newGame: 'New Game',
  },

  ru: {
    // Nav bar
    menu: 'Меню',
    brigade: 'Бригада',
    jobs: 'Работы',
    theNorth: 'Север',
    plot: 'Подвал',
    toggleLanguage: 'Сменить язык',

    // Info bar
    year: 'Год',
    task: 'Задача:',
    famineYear: 'Год неурожая',
    lead: 'Ведёт:',
    cellar: 'Подвал:',

    // Player info
    you: 'Вы',
    player: 'Игрок',
    pts: 'очк',
    cards: 'карт',
    yourTurn: 'Ваш ход',

    // Jobs
    wheat: 'Пшеница',
    beets: 'Свёкла',
    potatoes: 'Картофель',
    sunflower: 'Подсолнух',
    dropHere: 'Сюда',

    // Swap phase
    cardSwap: 'Обмен карт',
    hidden: 'Скрытые',
    rewards: 'Награды',
    confirmed: 'Подтверждено',
    confirm: 'Подтвердить',
    waitingForOthers: 'Ожидание...',

    // Requisition
    requisition: 'Реквизиция',
    failed: 'Провалено:',
    yearComplete: 'Год {year} Завершён',
    cardsToNorth: 'Карт на Север:',
    allJobsComplete: 'Все работы выполнены!',
    continueToYear: 'Продолжить к Году {year}',

    // Trump selection
    chooseMainTask: 'Выберите главную задачу',

    // Game over
    gameOver: 'Игра окончена!',
    winner: 'Победитель:',
    highestScoreWins: '(Побеждает наибольший счёт)',

    // Rules
    rules: 'Правила',
    objective: 'Цель',
    gameplay: 'Игра',
    trumpFaceCards: 'Козырные карты',
    objectiveText: 'Выполняйте работы колхоза, защищая свой участок. Побеждает наибольший счёт!',
    gameplayRule1: 'Играйте карты в трюки - следуйте масти если возможно',
    gameplayRule2: 'Победитель трюка назначает карты на работы',
    gameplayRule3: 'Работы требуют 40 часов для завершения',
    jackDesc: 'Стоит 0 часов, отправляется на Север вместо ваших карт',
    queenDesc: 'Все игроки становятся уязвимыми',
    kingDesc: 'Отправляет две карты вместо одной',
    jackName: 'Пьяница',
    queenName: 'Доносчик',
    kingName: 'Чиновник',
    newGame: 'Новая игра',
  },
};

// Helper function to get a translated string with optional interpolation
export function t(translations, lang, key, params = {}) {
  const str = translations[lang]?.[key] || translations.en[key] || key;
  return str.replace(/\{(\w+)\}/g, (_, k) => params[k] ?? `{${k}}`);
}

// Job names by suit
export function getJobName(lang, suit) {
  const jobNames = {
    en: { Hearts: 'Wheat', Diamonds: 'Beets', Clubs: 'Potatoes', Spades: 'Sunflower' },
    ru: { Hearts: 'Пшеница', Diamonds: 'Свёкла', Clubs: 'Картофель', Spades: 'Подсолнух' },
  };
  return jobNames[lang]?.[suit] || jobNames.en[suit] || suit;
}
