// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get lobbyCreateGame => 'Создать игру';

  @override
  String get lobbyPlayDemo => 'Играть демо';

  @override
  String get lobbyJoinGame => 'Войти в игру';

  @override
  String get lobbyHowToPlay => 'Как играть';

  @override
  String get lobbyAccountStatus => 'Аккаунт';

  @override
  String get lobbyLanguage => 'Язык';

  @override
  String get lobbyTheme => 'Тема';

  @override
  String get lobbySettings => 'Настройки';

  @override
  String get presetKolkhoz => 'Колхоз';

  @override
  String get presetLittleKolkhoz => 'Колхозик';

  @override
  String get presetCampStyle => 'Лагерный';

  @override
  String get presetCustom => 'Свой';

  @override
  String get variantDeck52Cards => '52 карты';

  @override
  String get variantDeck36Cards => '36 карт';

  @override
  String get variantDeckLabel => 'КОЛОДА';

  @override
  String variantValue1CardDeck({required Object value1}) {
    return 'Колода $value1 карт';
  }

  @override
  String variantValue1YearPlan({required Object value1}) {
    return 'План на $value1 лет';
  }

  @override
  String get variantNomenklaturaTitle => 'Номенклатура живёт по своим законам';

  @override
  String get variantNomenklaturaDescription =>
      'Козырные фигуры имеют особые силы: Валет ссылается, Дама раскрывает всех, Король удваивает ссылку.';

  @override
  String get variantSwapTitle => 'Замените мыло на шило';

  @override
  String get variantSwapDescription =>
      'Обменивайте карты между рукой и участком в начале каждого года.';

  @override
  String get variantNorthernStyleTitle => 'Игра по-северному';

  @override
  String get variantNorthernStyleDescription =>
      'Нет наград за работы - все остаются уязвимы.';

  @override
  String get variantMiceTitle => 'Разговоры вели даже с мышами';

  @override
  String get variantMiceDescription =>
      'Все игроки раскрывают весь участок при реквизиции.';

  @override
  String get variantOrdenNachalnikuTitle => 'Орден — начальнику, работа — нам';

  @override
  String get variantOrdenNachalnikuDescription =>
      'Карты, назначенные на выполненные работы, копятся как награды.';

  @override
  String get variantMedalsTitle => 'Орденов — полшкафа, а есть — нечего';

  @override
  String get variantMedalsDescription =>
      'Победы во взятках идут в итоговый счёт.';

  @override
  String get variantHeroTitle => 'стахановец';

  @override
  String get variantHeroDescription =>
      'Выиграйте все взятки за год: вы защищены, а все остальные уязвимы для реквизиции.';

  @override
  String get variantAccumulationTitle => 'НАКОПЛЕНИЕ';

  @override
  String get variantAccumulationDescription =>
      'Невостребованные награды за работы переносятся на следующий год.';

  @override
  String get variantWreckerTitle => 'ВРЕДИТЕЛЬ';

  @override
  String get variantWreckerDescription =>
      'Добавляет джокера со значением 0: он считается всеми мастями и проваливает свою работу при реквизиции.';

  @override
  String get variantFinalYearTrumpTitle => 'Козырь последнего года';

  @override
  String get variantFinalYearTrumpDescription =>
      'Оставшаяся карта пятого года определяет козырь; вредитель означает игру без козыря.';

  @override
  String get variantPassCardsTitle => 'Передача';

  @override
  String get variantPassCardsDescription =>
      'Передавайте одну скрытую карту влево и вправо по очереди со второго по пятый год.';

  @override
  String get variantHighestCardsRequisitionTitle => 'Реквизиция старших карт';

  @override
  String get variantHighestCardsRequisitionDescription =>
      'Теряйте старшие карты проваленных культур — по одной за каждую проваленную работу.';

  @override
  String get variantLottoRewardsTitle => 'Лотерейные награды';

  @override
  String get variantLottoRewardsDescription =>
      'В каждой культуре награда 5 заменяется скрытой случайной картой от 5 до короля.';

  @override
  String get variantDemoModeTitle => 'ДЕМО-РЕЖИМ';

  @override
  String get variantDemoModeDescription => 'Колхоз на 5 лет с лёгким ИИ';

  @override
  String get appsettingsDark => 'ТЬМА';

  @override
  String get appsettingsLight => 'СВЕТ';

  @override
  String get appsettingsSwitchToLightMode => 'Включить светлую тему';

  @override
  String get appsettingsSwitchToDarkMode => 'Включить тёмную тему';

  @override
  String get appsettingsCardBacks => 'Рубашки карт';

  @override
  String get appsettingsClassic => 'Классика';

  @override
  String get appsettingsHarvest => 'Урожай';

  @override
  String get appsettingsGranary => 'Амбар';

  @override
  String get appsettingsWinter => 'Зима';

  @override
  String get tabledisplayYou => 'Вы';

  @override
  String get tutorialdisplayBack => 'Назад';

  @override
  String get tutorialdisplayDone => 'Готово';

  @override
  String get tutorialdisplayNext => 'Далее';

  @override
  String get tutorialdisplayForemanMisha => 'БРИГАДИР МИША';

  @override
  String get tutorialdisplayTip => 'СОВЕТ';

  @override
  String get tutorialdisplayDoneWellWorkedComrade =>
      'Готово. Хорошая работа, товарищ.';

  @override
  String get boardviewPassDevice => 'Передайте устройство';

  @override
  String boardviewSeatValue1IsUp({required Object value1}) {
    return 'Ходит место $value1.';
  }

  @override
  String get boardviewReady => 'Готов';

  @override
  String get boardviewYourTurn => 'ВАШ ХОД';

  @override
  String get boardviewWait => 'ЖДИТЕ';

  @override
  String get boardviewFamineYear => 'Год неурожая';

  @override
  String get boardviewChooseTrump => 'Выберите козырь';

  @override
  String get lowerbaractionsSwap => 'Обмен';

  @override
  String get lowerbaractionsUndo => 'Отменить';

  @override
  String get lowerbaractionsConfirm => 'Подтвердить';

  @override
  String get lowerbaractionsFinish => 'Завершить';

  @override
  String lowerbaractionsYearValue1({required Object value1}) {
    return 'Год $value1';
  }

  @override
  String phasedisplayYearValue1Phasename({
    required Object value1,
    required Object phaseName,
  }) {
    return 'Год $value1 - $phaseName';
  }

  @override
  String get kolkhozappCancel => 'Отмена';

  @override
  String get kolkhozappNewGame => 'Новая игра?';

  @override
  String get kolkhozappThisWillReplaceTheCurrentGame =>
      'Текущая партия будет заменена.';

  @override
  String get kolkhozappNewGame2 => 'Новая игра';

  @override
  String get kolkhozappMainMenu => 'Главное меню?';

  @override
  String get kolkhozappLeaveTheCurrentGameAndReturnToSetup =>
      'Выйти из текущей партии и вернуться к настройке.';

  @override
  String get kolkhozappMainMenu2 => 'Главное меню';

  @override
  String get kolkhozappRememberYouMustFollowSuitIfAble =>
      'Помните: если можете, нужно ходить в масть.';

  @override
  String get kolkhozappSignedInProfileLoaded =>
      'Вход выполнен. Профиль загружен.';

  @override
  String get kolkhozappAccountCreatedCheckYourEmailToConfirmItThe =>
      'Аккаунт создан. Подтвердите email, затем войдите.';

  @override
  String get kolkhozappAccountCreated => 'Аккаунт создан.';

  @override
  String get kolkhozappAccountDeleted => 'Аккаунт удалён.';

  @override
  String get kolkhozappPasswordResetEmailSent =>
      'Письмо для сброса пароля отправлено.';

  @override
  String get kolkhozappSyncingProfile => 'Синхронизация профиля...';

  @override
  String get kolkhozappProfileSaved => 'Профиль сохранён.';

  @override
  String get kolkhozappProfileLoaded => 'Профиль загружен.';

  @override
  String get kolkhozappAccountRequestFailed =>
      'Запрос аккаунта не удался. Повторите попытку через минуту.';

  @override
  String get kolkhozappAccountInvalidEmail =>
      'Введите действительный email, включая метку после +.';

  @override
  String get kolkhozappAccountAlreadyExists =>
      'Аккаунт с таким email уже существует. Войдите или сбросьте пароль.';

  @override
  String get kolkhozappAccountRateLimited =>
      'Слишком много попыток. Подождите несколько минут и повторите.';

  @override
  String get kolkhozappAccountCreationUnavailable =>
      'Создание аккаунта временно недоступно. Повторите позже.';

  @override
  String get kolkhozappAccountWeakPassword =>
      'Выберите более надёжный пароль и повторите.';

  @override
  String get kolkhozappAccountServiceUnavailable =>
      'Не удалось связаться с сервисом аккаунтов. Проверьте подключение и повторите.';

  @override
  String get kolkhozappAccountInvalidCredentials =>
      'Неверный email или пароль. Повторите или сбросьте пароль.';

  @override
  String get kolkhozappProfileSyncFailed => 'Синхронизация профиля не удалась.';

  @override
  String get kolkhozappSignInBeforeJoiningOnlinePlay =>
      'Войдите в аккаунт перед онлайн-игрой.';

  @override
  String get kolkhozappOnlineSignInExpiredSignInAgain =>
      'Онлайн-вход истёк. Войдите снова.';

  @override
  String get kolkhozappCouldNotVerifyOnlineAccountTryAgain =>
      'Не удалось проверить онлайн-аккаунт. Повторите попытку.';

  @override
  String get kolkhozappCloudAccountUnavailable => 'Облачный аккаунт недоступен';

  @override
  String get kolkhozappConnectingAccount => 'Подключение аккаунта...';

  @override
  String kolkhozappSignedInEmail({required Object email}) {
    return 'Вход: $email';
  }

  @override
  String get kolkhozappSignedIn => 'Вход выполнен';

  @override
  String get kolkhozappSignedOut2 => 'Вы не вошли';

  @override
  String get kolkhozappGameBy => 'АВТОР ИГРЫ';

  @override
  String get kolkhozappWilliamTheisen => 'УИЛЬЯМ ТАЙСОН';

  @override
  String get kolkhozappProfile => 'Профиль';

  @override
  String get kolkhozappLeaderboard => 'ТАБЛИЦА ЛИДЕРОВ';

  @override
  String get kolkhozappSettings => 'НАСТРОЙКИ';

  @override
  String get kolkhozappProgress => 'ПРОГРЕСС';

  @override
  String get kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom =>
      'Не удалось подключиться к серверу. Повторите попытку чуть позже.';

  @override
  String get kolkhozappOnlineRequestFailedTryAgain =>
      'Онлайн-запрос не удался. Повторите попытку.';

  @override
  String get kolkhozappDemoMode2YearKolkhozWithEasyAi =>
      'Демо-режим: Колхоз на 5 лет с лёгким ИИ.';

  @override
  String get kolkhozappWorking => 'Идёт...';

  @override
  String get kolkhozappStartDemo => 'Начать демо';

  @override
  String get kolkhozappStartOnlineGame => 'Начать онлайн';

  @override
  String get kolkhozappStartOfflineGame => 'Начать офлайн';

  @override
  String get kolkhozappContinueToLobby => 'Перейти в лобби';

  @override
  String get kolkhozappBackToSetup => 'Назад к настройке';

  @override
  String get kolkhozappSaveFavorite => 'Сохранить любимую';

  @override
  String get kolkhozappUseFavorite => 'Взять любимую';

  @override
  String get kolkhozappFavoriteSaved => 'Любимая настройка сохранена';

  @override
  String get kolkhozappRanked => 'Рейтинг';

  @override
  String get kolkhozappLocked => 'Частная';

  @override
  String get kolkhozappBrowser => 'Публичная';

  @override
  String get kolkhozappAccess => 'ВИДИМОСТЬ';

  @override
  String get kolkhozappComrades => 'Товарищи';

  @override
  String get kolkhozappYourComradeCode => 'ВАШ КОД ТОВАРИЩА';

  @override
  String get kolkhozappComradeCode => 'КОД ТОВАРИЩА';

  @override
  String get kolkhozappAddComrade => 'Добавить';

  @override
  String get kolkhozappRemove => 'Убрать';

  @override
  String get kolkhozappNoComrades => 'Товарищей пока нет';

  @override
  String get kolkhozappComradeAdded => 'Товарищ добавлен';

  @override
  String get kolkhozappComradeRequestSent => 'Запрос отправлен';

  @override
  String get kolkhozappComrade => 'Товарищ';

  @override
  String get kolkhozappNotComrade => 'Не товарищ';

  @override
  String get kolkhozappPending => 'Ожидает';

  @override
  String get kolkhozappIncomingRequests => 'Входящие запросы';

  @override
  String get kolkhozappOutgoingRequests => 'Отправленные запросы';

  @override
  String get kolkhozappNoComradeRequests => 'Нет запросов';

  @override
  String get kolkhozappAccept => 'Принять';

  @override
  String get kolkhozappDecline => 'Отклонить';

  @override
  String get kolkhozappComradeRequestAccepted => 'Запрос принят';

  @override
  String get kolkhozappComradeRequestDeclined => 'Запрос отклонён';

  @override
  String get kolkhozappComradeRemoved => 'Товарищ убран';

  @override
  String get kolkhozappGameInvite => 'Приглашение в игру';

  @override
  String kolkhozappValue1InvitedYouToAGame({required Object value1}) {
    return '$value1 приглашает вас в игру.';
  }

  @override
  String get kolkhozappOfflineStatus => 'Не в сети';

  @override
  String get kolkhozappInGame => 'В игре';

  @override
  String get kolkhozappInLobby => 'В лобби';

  @override
  String get kolkhozappCasual => 'Без рейтинга';

  @override
  String get kolkhozappGameType => 'ТИП';

  @override
  String kolkhozappPValue1({required Object value1}) {
    return 'И$value1';
  }

  @override
  String get kolkhozappHotseat => 'За столом';

  @override
  String get kolkhozappOnline => 'Онлайн';

  @override
  String kolkhozappDecktypeCardsMaxyearsYears({
    required Object deckType,
    required Object maxYears,
  }) {
    return '$deckType КАРТ / $maxYears ГОДА';
  }

  @override
  String get kolkhozappHowToPlay => 'КАК ИГРАТЬ';

  @override
  String get kolkhozappTutorial => 'Обучение';

  @override
  String get kolkhozappProfile2 => 'ПРОФИЛЬ';

  @override
  String get kolkhozappDisplayName => 'ИМЯ ИГРОКА';

  @override
  String get kolkhozappPortrait => 'ПОРТРЕТ';

  @override
  String get kolkhozappPasswordsDoNotMatch => 'Пароли не совпадают.';

  @override
  String get kolkhozappCloudProfilesAreNotConfiguredForThisBuild =>
      'Облачные профили не настроены для этой сборки.';

  @override
  String get kolkhozappCloudProfilesAreStarting =>
      'Облачные профили запускаются.';

  @override
  String get kolkhozappSignInToSyncProfileAndOnlineSeats =>
      'Войдите, чтобы синхронизировать профиль и места.';

  @override
  String get kolkhozappAccount => 'АККАУНТ';

  @override
  String get kolkhozappEmail => 'EMAIL';

  @override
  String get kolkhozappPassword => 'ПАРОЛЬ';

  @override
  String get kolkhozappConfirmPassword => 'ПОВТОРИТЕ ПАРОЛЬ';

  @override
  String get kolkhozappSignIn => 'Войти';

  @override
  String get kolkhozappReset => 'Сбросить';

  @override
  String get kolkhozappCreate => 'Создать';

  @override
  String get kolkhozappOffline => 'ОФЛАЙН';

  @override
  String get kolkhozappGames => 'игры';

  @override
  String get kolkhozappOffWins => 'ОФЛ ПОБ';

  @override
  String get kolkhozappWins => 'победы';

  @override
  String get kolkhozappOnline2 => 'ОНЛАЙН';

  @override
  String get kolkhozappOnWins => 'ОНЛ ПОБ';

  @override
  String get kolkhozappCasualRating => 'КАЗУАЛ РЕЙТИНГ';

  @override
  String get kolkhozappRankedRating => 'РЕЙТИНГОВЫЙ РЕЙТИНГ';

  @override
  String get kolkhozappRating => 'РЕЙТИНГ';

  @override
  String get kolkhozappCurrent => 'текущий';

  @override
  String get kolkhozappWins2 => 'ПОБЕДЫ';

  @override
  String get kolkhozappTotal => 'всего';

  @override
  String get kolkhozappLosses => 'ПОРАЖЕНИЯ';

  @override
  String get kolkhozappStats => 'СТАТИСТИКА';

  @override
  String get kolkhozappNoOpenGames => 'Нет открытых игр';

  @override
  String kolkhozappValue1Open({required Object value1}) {
    return 'Открыто: $value1';
  }

  @override
  String kolkhozappValue1CitizensOnline({required Object value1}) {
    return 'Граждан онлайн: $value1';
  }

  @override
  String kolkhozappRefreshInValue1s({required Object value1}) {
    return 'Обновление через $value1с';
  }

  @override
  String kolkhozappJoinedValue1({required Object value1}) {
    return 'Вошли $value1';
  }

  @override
  String get kolkhozappSentNorthOnlinePlayIsLockedForThisAccount =>
      'Сослан на север: онлайн временно закрыт для аккаунта.';

  @override
  String get kolkhozappTheOnlineServerRejectedTheRequest =>
      'Сервер отклонил запрос.';

  @override
  String get kolkhozappOnlinePlay => 'ОНЛАЙН ИГРА';

  @override
  String get kolkhozappJoinAnOpenGameOrEnterAnInviteCode =>
      'Войдите в открытую игру или по коду.';

  @override
  String get kolkhozappInviteCode => 'КОД ПРИГЛАШЕНИЯ';

  @override
  String get kolkhozappYourInviteCode => 'ВАШ КОД';

  @override
  String get kolkhozappWaitingForPlayers => 'Ожидание игроков';

  @override
  String kolkhozappGameStartsInValue1s({required Object value1}) {
    return 'Игра начнётся через $value1 с';
  }

  @override
  String get kolkhozappSearchingForPlayer => 'Поиск игрока';

  @override
  String get kolkhozappCopyCode => 'Копировать код';

  @override
  String get kolkhozappCopyResult => 'Копировать итог';

  @override
  String get kolkhozappCopied => 'Скопировано';

  @override
  String get kolkhozappJoinGame => 'Войти и играть';

  @override
  String get kolkhozappAssignGame => 'Назначить игру';

  @override
  String get kolkhozappKick => 'Исключить';

  @override
  String get kolkhozappOpenGames => 'ОТКРЫТЫЕ ИГРЫ';

  @override
  String get kolkhozappRefresh => 'Обновить';

  @override
  String kolkhozappOpenOpenseats({required Object openSeats}) {
    return 'Открыто $openSeats';
  }

  @override
  String get kolkhozappHost => 'ХОЗЯИН';

  @override
  String get kolkhozappSeats => 'МЕСТА';

  @override
  String get kolkhozappTurn => 'ХОД';

  @override
  String get kolkhozappMoves => 'ХОДЫ';

  @override
  String get kolkhozappWaiting => 'ОЖИДАНИЕ';

  @override
  String get kolkhozappOpen => 'СВОБОДНО';

  @override
  String get kolkhozappAverageRating => 'СР РЕЙТИНГ';

  @override
  String get kolkhozappPlayer => 'ИГРОК';

  @override
  String get kolkhozappScore => 'ОЧКИ';

  @override
  String get kolkhozappMedals => 'МЕДАЛИ';

  @override
  String get kolkhozappHand => 'РУКА';

  @override
  String get kolkhozappCellar => 'ПОДВАЛ';

  @override
  String get kolkhozappPlot => 'УЧАСТОК';

  @override
  String get kolkhozappController => 'УПРАВЛЕНИЕ';

  @override
  String get kolkhozappBrigadeLeader => 'БРИГАДИР';

  @override
  String get kolkhozappCurrentTurn => 'ТЕКУЩИЙ ХОД';

  @override
  String get kolkhozappAny => 'Любое';

  @override
  String get kolkhozappHuman => 'Игрок';

  @override
  String get kolkhozappEasy => 'Легко';

  @override
  String get kolkhozappMedium => 'Средне';

  @override
  String get kolkhozappHard => 'Сложно';

  @override
  String get plotdisplayOtherStoresAboveActivePlayerSCellarBelow =>
      'Участки других сверху, подвал активного игрока снизу.';

  @override
  String get plotdisplayAllJobsComplete => 'Все работы выполнены.';

  @override
  String get plotdisplayAuditComplete => 'Проверка завершена.';

  @override
  String get boardOptionspanelInstant => 'Мигом';

  @override
  String get boardOptionspanelFast => 'Быстро';

  @override
  String get boardOptionspanelNormal => 'Норма';

  @override
  String get boardOptionspanelSlow => 'Медленно';

  @override
  String get boardOptionspanelSession => 'Партия';

  @override
  String get boardOptionspanelAssist => 'Помощь';

  @override
  String get boardOptionspanelDisplay => 'Вид';

  @override
  String get boardOptionspanelRules => 'Правила';

  @override
  String get boardOptionspanelMenu => 'Меню';

  @override
  String get boardOptionspanelGameControls => 'Управление игрой';

  @override
  String get boardOptionspanelHowToPlay => 'Как играть';

  @override
  String get boardOptionspanelSafeguards => 'Защита';

  @override
  String get boardOptionspanelConfirmNewGame => 'Подтверждать новую игру';

  @override
  String get boardOptionspanelAskBeforeReplacingTheCurrentGame =>
      'Спросить перед заменой текущей партии.';

  @override
  String get boardOptionspanelConfirmMainMenu => 'Подтверждать выход';

  @override
  String get boardOptionspanelAskBeforeLeavingTheCurrentGame =>
      'Спросить перед выходом из текущей партии.';

  @override
  String get boardOptionspanelMoveHelp => 'Помощь хода';

  @override
  String get boardOptionspanelInvalidTapHints => 'Подсказки ошибок';

  @override
  String get boardOptionspanelShowTheForemanReminderWhenYouTapAnIllegalC =>
      'Показывать напоминание бригадира при неверной карте.';

  @override
  String get boardOptionspanelAnimationSpeed => 'Скорость анимации';

  @override
  String get boardPlotpanelRequisition => 'Реквизиция';

  @override
  String get boardPlotpanelPrivatePlot => 'Личный участок';

  @override
  String get boardPlotpanelGameOver => 'Игра окончена';

  @override
  String boardPlotpanelWinnerWinnernameWinnerscore({
    required Object winnerName,
    required Object winnerScore,
  }) {
    return 'Победитель: $winnerName - $winnerScore';
  }

  @override
  String get boardHandtrayUndo => 'Назад';

  @override
  String get boardHandtrayPlay => 'Ход';

  @override
  String get handConsoleYourTurnToPlay => 'Ваш ход';

  @override
  String get handConsoleChooseSwap => 'Выберите обмен';

  @override
  String get handConsoleAssignTrick => 'Распределите взятку';

  @override
  String get handConsoleReviewRequisition => 'Проверьте реквизицию';

  @override
  String handConsoleWaitingForValue1({required Object value1}) {
    return 'Ждём: $value1';
  }

  @override
  String handConsoleWaitingForValue1ToPlay({required Object value1}) {
    return 'Ждём хода: $value1';
  }

  @override
  String handConsoleWaitingForValue1ToSwap({required Object value1}) {
    return 'Ждём обмена: $value1';
  }

  @override
  String handConsoleWaitingForValue1ToAssign({required Object value1}) {
    return 'Ждём работ: $value1';
  }

  @override
  String get handConsoleContinue => 'Далее';

  @override
  String get boardJobspanelDone => 'ГОТОВО';

  @override
  String get boardJobspanelTapToAssign => 'НАЗНАЧИТЬ';

  @override
  String get boardBoardrailBoard => 'Стол';

  @override
  String get boardBoardrailJobs => 'Работы';

  @override
  String get boardBoardrailNorth => 'Север';

  @override
  String get boardBoardrailCellar => 'Подвал';

  @override
  String get boardBoardrailLang => 'Язык';

  @override
  String get boardBoardrailBrigade => 'Бригада';

  @override
  String get boardBoardrailTheNorth => 'Север';

  @override
  String get ruleSummary1Title => 'Цель';

  @override
  String get ruleSummary1Body =>
      'Выполняйте работы колхоза, защищая свой участок. Побеждает наибольший счёт!';

  @override
  String get ruleSummary2Title => 'Игра';

  @override
  String get ruleSummary2Body =>
      'Играйте карты во взятки - следуйте масти если возможно.';

  @override
  String get ruleSummary3Title => 'Работы';

  @override
  String get ruleSummary3Body => 'Работы требуют 40 часов для завершения.';

  @override
  String get ruleSummary4Title => 'Козырные карты';

  @override
  String get ruleSummary4Body =>
      'Валет, Дама и Король имеют особые силы в игре с номенклатурой.';

  @override
  String get ruleSummary5Title => 'Подсчёт очков';

  @override
  String get ruleSummary5Body =>
      'Карты на вашем участке дают очки. Побеждает тот, у кого больше.';

  @override
  String get ruleSummary6Title => 'Работы';

  @override
  String get ruleSummary6Body =>
      'Выигрывайте взятки и назначайте карты на подходящие работы.';

  @override
  String get ruleSummary7Title => 'Защита';

  @override
  String get ruleSummary7Body =>
      'Берегите карты участка от реквизиции за проваленные работы.';

  @override
  String get ruleSummary8Title => 'Козырные карты';

  @override
  String get ruleSummary8Body =>
      'Валет уходит на Север, Дама раскрывает, Король удваивает ссылку.';

  @override
  String get tutorialStep1Title => 'Добро пожаловать в колхоз';

  @override
  String get tutorialStep1Body =>
      'Это настоящая игра, товарищ — играйте, пока мы говорим. Цель: закончить пятилетку с самым богатым подвалом.';

  @override
  String get tutorialStep1Tip =>
      'Старшие скрытые карты — ваш запас. Потеря одной на Севере может решить итоговый счёт.';

  @override
  String get tutorialStep1Callout =>
      'Кнопки листают уроки. Стол остаётся вашим.';

  @override
  String get tutorialStep2Title => 'Осмотрите доску работ';

  @override
  String get tutorialStep2Body =>
      'Каждый год четыре работы, по одной на культуру. В наградах всегда 1–4 и один тайный случайный ранг от 5 до К; счётчик — часы: 40 закрывают работу.';

  @override
  String get tutorialStep2Tip =>
      'Проваленные работы зовут реквизицию в конце года. Запоминайте обречённые культуры.';

  @override
  String get tutorialStep2Callout =>
      'Найдите четыре счётчика работ наверху стола.';

  @override
  String get tutorialStep3Title => 'Козырная культура';

  @override
  String get tutorialStep3Body =>
      'В планировании одну культуру объявляют главной задачей — козырем. В пятом году лишнюю карту сдачи открывают для выбора козыря; Вредитель означает игру без козыря.';

  @override
  String get tutorialStep3Tip =>
      'Выбирайте козырь под руку, которую хотите разыграть, а не только под самую крупную карту.';

  @override
  String get tutorialStep3Callout => 'Ждём объявления козыря…';

  @override
  String get tutorialStep4Title => 'Сыграйте карту';

  @override
  String get tutorialStep4Body =>
      'Ходите в масть, если можете — разрешённые карты подсвечены. Нет масти? Кладите что угодно, хоть козырь.';

  @override
  String get tutorialStep4Tip =>
      'Уступить взятку можно — и часто мудро. Победители привлекают внимание.';

  @override
  String get tutorialStep4Callout =>
      'Сыграйте карту с руки, когда придёт ваш ход.';

  @override
  String get tutorialStep5Title => 'Взятие взятки';

  @override
  String get tutorialStep5Body =>
      'Взятку берёт старшая карта ведущей масти — если не лёг козырь: тогда старший козырь. Победитель берёт медаль и становится бригадиром.';

  @override
  String get tutorialStep5Tip =>
      'Медали решают ничьи в конце — но каждая победа рисует мишень на подвале.';

  @override
  String get tutorialStep5Callout => 'Смотрите, кто возьмёт эту взятку.';

  @override
  String get tutorialStep6Title => 'Назначьте работу';

  @override
  String get tutorialStep6Body =>
      'Бригадир отправляет карты взятки на работы — законны только культуры из взятки. Ранг карты — её часы.';

  @override
  String get tutorialStep6Tip =>
      'Назначайте работу, защищая культуры своих лучших карт подвала.';

  @override
  String get tutorialStep6Callout =>
      'Выиграв взятку, распределите её карты по работам.';

  @override
  String get tutorialStep7Title => 'Выполните норму';

  @override
  String get tutorialStep7Body =>
      'Работа с 40 часами закрыта: награда падает в подвал закрывшего, и эта культура в этом году не вызовет реквизицию.';

  @override
  String get tutorialStep7Tip =>
      'Закрытая работа и платит, и защищает. Две птицы — одна норма.';

  @override
  String get tutorialStep7Callout =>
      'Доведите работу до 40 часов и заберите награду.';

  @override
  String get tutorialStep8Title => 'Последняя карта';

  @override
  String get tutorialStep8Body =>
      'Взяток только четыре. Пятая карта в конце года уходит в подвал рубашкой вверх — её ранг станет очками.';

  @override
  String get tutorialStep8Tip => 'Ведите год так, чтобы уцелела лучшая карта.';

  @override
  String get tutorialStep8Callout =>
      'Несыгранная карта спрячется сама в конце года.';

  @override
  String get tutorialStep9Title => 'Это реквизиция';

  @override
  String get tutorialStep9Body =>
      'Если провалены N культур, каждый уязвимый игрок теряет N старших карт этих мастей из подвала. Парторг добавляет одну, а Пьяница исключает свою масть из нормы.';

  @override
  String get tutorialStep9Tip =>
      'Не брали взяток? Нечего предъявить. У трусости свои награды.';

  @override
  String get tutorialStep9Callout => 'Внимательно изучите отчёт о реквизиции.';

  @override
  String get tutorialStep10Title => 'Ежегодный обмен';

  @override
  String get tutorialStep10Body =>
      'Со второго года перед началом взятки можно обменять одну карту с руки на одну карту подвала.';

  @override
  String get tutorialStep10Tip =>
      'Прячьте старшие карты, пока безопасно; вытаскивайте обречённые культуры.';

  @override
  String get tutorialStep10Callout =>
      'Решите вопрос с обменом до начала взятки.';

  @override
  String get tutorialStep11Title => 'Берегитесь Вредителя';

  @override
  String get tutorialStep11Body =>
      'Среди рабочих прячется джокер: ходит под любую масть, даёт 0 часов — и работа с ним проваливает проверку.';

  @override
  String get tutorialStep11Tip =>
      'Берите его смело, прячьте с горечью — или сделайте чужой проблемой.';

  @override
  String get tutorialStep11Callout =>
      'Он в правилах «Колхоза» — следите за джокером.';

  @override
  String get tutorialStep12Title => 'Пятый год — голод';

  @override
  String get tutorialStep12Body =>
      'Последний год скуден: четыре карты, три взятки и никакого козыря. Коротко — и обычно решающе.';

  @override
  String get tutorialStep12Tip =>
      'Приберегите гибкие старшие карты на голод; без козыря плохой ход не исправить.';

  @override
  String get tutorialStep12Callout => 'Ждём голодного года…';

  @override
  String get tutorialStep13Title => 'Побеждает лучший подвал';

  @override
  String get tutorialStep13Body =>
      'После пятого года каждая карта подвала приносит свой ранг. Наибольшая сумма выигрывает пятилетку; медали решают ничьи. Не подведите, товарищ.';

  @override
  String get tutorialStep13Tip =>
      'Один сбережённый король стоит года осторожности.';

  @override
  String get tutorialStep13Callout => 'Закончите пятилетку — Миша следит.';

  @override
  String get suitWheat => 'Пшеница';

  @override
  String get suitSunflower => 'Подсолнух';

  @override
  String get suitPotatoes => 'Картофель';

  @override
  String get suitBeets => 'Свёкла';

  @override
  String get phasePlanning => 'План';

  @override
  String get phaseSwap => 'Обмен';

  @override
  String get phaseTrick => 'Взятка';

  @override
  String get phaseAssignment => 'Работы';

  @override
  String get phaseRequisition => 'Реквизиция';

  @override
  String get phaseGameOver => 'Итог';

  @override
  String get languageSwitchTitle => 'Switch to English';
}
