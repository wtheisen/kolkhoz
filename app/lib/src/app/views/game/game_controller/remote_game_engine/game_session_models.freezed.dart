// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_session_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OnlineTournamentGameStatus {

 String get tournamentID; int get roundNumber; int get tableNumber; int get totalRounds; String get status;
/// Create a copy of OnlineTournamentGameStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineTournamentGameStatusCopyWith<OnlineTournamentGameStatus> get copyWith => _$OnlineTournamentGameStatusCopyWithImpl<OnlineTournamentGameStatus>(this as OnlineTournamentGameStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineTournamentGameStatus&&(identical(other.tournamentID, tournamentID) || other.tournamentID == tournamentID)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.tableNumber, tableNumber) || other.tableNumber == tableNumber)&&(identical(other.totalRounds, totalRounds) || other.totalRounds == totalRounds)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tournamentID,roundNumber,tableNumber,totalRounds,status);

@override
String toString() {
  return 'OnlineTournamentGameStatus(tournamentID: $tournamentID, roundNumber: $roundNumber, tableNumber: $tableNumber, totalRounds: $totalRounds, status: $status)';
}


}

/// @nodoc
abstract mixin class $OnlineTournamentGameStatusCopyWith<$Res>  {
  factory $OnlineTournamentGameStatusCopyWith(OnlineTournamentGameStatus value, $Res Function(OnlineTournamentGameStatus) _then) = _$OnlineTournamentGameStatusCopyWithImpl;
@useResult
$Res call({
 String tournamentID, int roundNumber, int tableNumber, int totalRounds, String status
});




}
/// @nodoc
class _$OnlineTournamentGameStatusCopyWithImpl<$Res>
    implements $OnlineTournamentGameStatusCopyWith<$Res> {
  _$OnlineTournamentGameStatusCopyWithImpl(this._self, this._then);

  final OnlineTournamentGameStatus _self;
  final $Res Function(OnlineTournamentGameStatus) _then;

/// Create a copy of OnlineTournamentGameStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tournamentID = null,Object? roundNumber = null,Object? tableNumber = null,Object? totalRounds = null,Object? status = null,}) {
  return _then(_self.copyWith(
tournamentID: null == tournamentID ? _self.tournamentID : tournamentID // ignore: cast_nullable_to_non_nullable
as String,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,tableNumber: null == tableNumber ? _self.tableNumber : tableNumber // ignore: cast_nullable_to_non_nullable
as int,totalRounds: null == totalRounds ? _self.totalRounds : totalRounds // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineTournamentGameStatus].
extension OnlineTournamentGameStatusPatterns on OnlineTournamentGameStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineTournamentGameStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineTournamentGameStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineTournamentGameStatus value)  $default,){
final _that = this;
switch (_that) {
case _OnlineTournamentGameStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineTournamentGameStatus value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineTournamentGameStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tournamentID,  int roundNumber,  int tableNumber,  int totalRounds,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineTournamentGameStatus() when $default != null:
return $default(_that.tournamentID,_that.roundNumber,_that.tableNumber,_that.totalRounds,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tournamentID,  int roundNumber,  int tableNumber,  int totalRounds,  String status)  $default,) {final _that = this;
switch (_that) {
case _OnlineTournamentGameStatus():
return $default(_that.tournamentID,_that.roundNumber,_that.tableNumber,_that.totalRounds,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tournamentID,  int roundNumber,  int tableNumber,  int totalRounds,  String status)?  $default,) {final _that = this;
switch (_that) {
case _OnlineTournamentGameStatus() when $default != null:
return $default(_that.tournamentID,_that.roundNumber,_that.tableNumber,_that.totalRounds,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineTournamentGameStatus implements OnlineTournamentGameStatus {
  const _OnlineTournamentGameStatus({required this.tournamentID, required this.roundNumber, required this.tableNumber, this.totalRounds = 4, required this.status});
  factory _OnlineTournamentGameStatus.fromJson(Map<String, dynamic> json) => _$OnlineTournamentGameStatusFromJson(json);

@override final  String tournamentID;
@override final  int roundNumber;
@override final  int tableNumber;
@override@JsonKey() final  int totalRounds;
@override final  String status;

/// Create a copy of OnlineTournamentGameStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineTournamentGameStatusCopyWith<_OnlineTournamentGameStatus> get copyWith => __$OnlineTournamentGameStatusCopyWithImpl<_OnlineTournamentGameStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineTournamentGameStatus&&(identical(other.tournamentID, tournamentID) || other.tournamentID == tournamentID)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.tableNumber, tableNumber) || other.tableNumber == tableNumber)&&(identical(other.totalRounds, totalRounds) || other.totalRounds == totalRounds)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tournamentID,roundNumber,tableNumber,totalRounds,status);

@override
String toString() {
  return 'OnlineTournamentGameStatus(tournamentID: $tournamentID, roundNumber: $roundNumber, tableNumber: $tableNumber, totalRounds: $totalRounds, status: $status)';
}


}

/// @nodoc
abstract mixin class _$OnlineTournamentGameStatusCopyWith<$Res> implements $OnlineTournamentGameStatusCopyWith<$Res> {
  factory _$OnlineTournamentGameStatusCopyWith(_OnlineTournamentGameStatus value, $Res Function(_OnlineTournamentGameStatus) _then) = __$OnlineTournamentGameStatusCopyWithImpl;
@override @useResult
$Res call({
 String tournamentID, int roundNumber, int tableNumber, int totalRounds, String status
});




}
/// @nodoc
class __$OnlineTournamentGameStatusCopyWithImpl<$Res>
    implements _$OnlineTournamentGameStatusCopyWith<$Res> {
  __$OnlineTournamentGameStatusCopyWithImpl(this._self, this._then);

  final _OnlineTournamentGameStatus _self;
  final $Res Function(_OnlineTournamentGameStatus) _then;

/// Create a copy of OnlineTournamentGameStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tournamentID = null,Object? roundNumber = null,Object? tableNumber = null,Object? totalRounds = null,Object? status = null,}) {
  return _then(_OnlineTournamentGameStatus(
tournamentID: null == tournamentID ? _self.tournamentID : tournamentID // ignore: cast_nullable_to_non_nullable
as String,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,tableNumber: null == tableNumber ? _self.tableNumber : tableNumber // ignore: cast_nullable_to_non_nullable
as int,totalRounds: null == totalRounds ? _self.totalRounds : totalRounds // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$OnlineSessionUpdate {

 String get sessionID; int? get seed;@JsonKey(readValue: _inviteCodeFromJson) String get inviteCode; int? get viewerID; int get actionLogCount; bool get isViewerTurn; List<OnlineEngineAction> get legalActions;@JsonKey(fromJson: _variantsFromJson) KolkhozGameVariants get variants;@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> get controllers; List<OnlinePlayerProfile> get playerProfiles; bool get ranked; bool get browserJoinable; List<OnlineSeatPresence> get seatPresence; int? get turnPlayerID; double? get turnDeadlineAt; bool get started; double? get lobbyCountdownEndsAt; List<OnlineEngineAction> get gameLogActions; List<OnlineReaction> get reactions; OnlineSeriesStatus? get series; OnlineTournamentGameStatus? get tournament; OnlineEngineSnapshot get snapshot;
/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<OnlineSessionUpdate> get copyWith => _$OnlineSessionUpdateCopyWithImpl<OnlineSessionUpdate>(this as OnlineSessionUpdate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSessionUpdate&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.viewerID, viewerID) || other.viewerID == viewerID)&&(identical(other.actionLogCount, actionLogCount) || other.actionLogCount == actionLogCount)&&(identical(other.isViewerTurn, isViewerTurn) || other.isViewerTurn == isViewerTurn)&&const DeepCollectionEquality().equals(other.legalActions, legalActions)&&(identical(other.variants, variants) || other.variants == variants)&&const DeepCollectionEquality().equals(other.controllers, controllers)&&const DeepCollectionEquality().equals(other.playerProfiles, playerProfiles)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.browserJoinable, browserJoinable) || other.browserJoinable == browserJoinable)&&const DeepCollectionEquality().equals(other.seatPresence, seatPresence)&&(identical(other.turnPlayerID, turnPlayerID) || other.turnPlayerID == turnPlayerID)&&(identical(other.turnDeadlineAt, turnDeadlineAt) || other.turnDeadlineAt == turnDeadlineAt)&&(identical(other.started, started) || other.started == started)&&(identical(other.lobbyCountdownEndsAt, lobbyCountdownEndsAt) || other.lobbyCountdownEndsAt == lobbyCountdownEndsAt)&&const DeepCollectionEquality().equals(other.gameLogActions, gameLogActions)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.series, series) || other.series == series)&&(identical(other.tournament, tournament) || other.tournament == tournament)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,sessionID,seed,inviteCode,viewerID,actionLogCount,isViewerTurn,const DeepCollectionEquality().hash(legalActions),variants,const DeepCollectionEquality().hash(controllers),const DeepCollectionEquality().hash(playerProfiles),ranked,browserJoinable,const DeepCollectionEquality().hash(seatPresence),turnPlayerID,turnDeadlineAt,started,lobbyCountdownEndsAt,const DeepCollectionEquality().hash(gameLogActions),const DeepCollectionEquality().hash(reactions),series,tournament,snapshot]);

@override
String toString() {
  return 'OnlineSessionUpdate(sessionID: $sessionID, seed: $seed, inviteCode: $inviteCode, viewerID: $viewerID, actionLogCount: $actionLogCount, isViewerTurn: $isViewerTurn, legalActions: $legalActions, variants: $variants, controllers: $controllers, playerProfiles: $playerProfiles, ranked: $ranked, browserJoinable: $browserJoinable, seatPresence: $seatPresence, turnPlayerID: $turnPlayerID, turnDeadlineAt: $turnDeadlineAt, started: $started, lobbyCountdownEndsAt: $lobbyCountdownEndsAt, gameLogActions: $gameLogActions, reactions: $reactions, series: $series, tournament: $tournament, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class $OnlineSessionUpdateCopyWith<$Res>  {
  factory $OnlineSessionUpdateCopyWith(OnlineSessionUpdate value, $Res Function(OnlineSessionUpdate) _then) = _$OnlineSessionUpdateCopyWithImpl;
@useResult
$Res call({
 String sessionID, int? seed,@JsonKey(readValue: _inviteCodeFromJson) String inviteCode, int? viewerID, int actionLogCount, bool isViewerTurn, List<OnlineEngineAction> legalActions,@JsonKey(fromJson: _variantsFromJson) KolkhozGameVariants variants,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, List<OnlinePlayerProfile> playerProfiles, bool ranked, bool browserJoinable, List<OnlineSeatPresence> seatPresence, int? turnPlayerID, double? turnDeadlineAt, bool started, double? lobbyCountdownEndsAt, List<OnlineEngineAction> gameLogActions, List<OnlineReaction> reactions, OnlineSeriesStatus? series, OnlineTournamentGameStatus? tournament, OnlineEngineSnapshot snapshot
});


$OnlineSeriesStatusCopyWith<$Res>? get series;$OnlineTournamentGameStatusCopyWith<$Res>? get tournament;$OnlineEngineSnapshotCopyWith<$Res> get snapshot;

}
/// @nodoc
class _$OnlineSessionUpdateCopyWithImpl<$Res>
    implements $OnlineSessionUpdateCopyWith<$Res> {
  _$OnlineSessionUpdateCopyWithImpl(this._self, this._then);

  final OnlineSessionUpdate _self;
  final $Res Function(OnlineSessionUpdate) _then;

/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? seed = freezed,Object? inviteCode = null,Object? viewerID = freezed,Object? actionLogCount = null,Object? isViewerTurn = null,Object? legalActions = null,Object? variants = null,Object? controllers = null,Object? playerProfiles = null,Object? ranked = null,Object? browserJoinable = null,Object? seatPresence = null,Object? turnPlayerID = freezed,Object? turnDeadlineAt = freezed,Object? started = null,Object? lobbyCountdownEndsAt = freezed,Object? gameLogActions = null,Object? reactions = null,Object? series = freezed,Object? tournament = freezed,Object? snapshot = null,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,viewerID: freezed == viewerID ? _self.viewerID : viewerID // ignore: cast_nullable_to_non_nullable
as int?,actionLogCount: null == actionLogCount ? _self.actionLogCount : actionLogCount // ignore: cast_nullable_to_non_nullable
as int,isViewerTurn: null == isViewerTurn ? _self.isViewerTurn : isViewerTurn // ignore: cast_nullable_to_non_nullable
as bool,legalActions: null == legalActions ? _self.legalActions : legalActions // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineAction>,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as KolkhozGameVariants,controllers: null == controllers ? _self.controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,playerProfiles: null == playerProfiles ? _self.playerProfiles : playerProfiles // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerProfile>,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,browserJoinable: null == browserJoinable ? _self.browserJoinable : browserJoinable // ignore: cast_nullable_to_non_nullable
as bool,seatPresence: null == seatPresence ? _self.seatPresence : seatPresence // ignore: cast_nullable_to_non_nullable
as List<OnlineSeatPresence>,turnPlayerID: freezed == turnPlayerID ? _self.turnPlayerID : turnPlayerID // ignore: cast_nullable_to_non_nullable
as int?,turnDeadlineAt: freezed == turnDeadlineAt ? _self.turnDeadlineAt : turnDeadlineAt // ignore: cast_nullable_to_non_nullable
as double?,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,lobbyCountdownEndsAt: freezed == lobbyCountdownEndsAt ? _self.lobbyCountdownEndsAt : lobbyCountdownEndsAt // ignore: cast_nullable_to_non_nullable
as double?,gameLogActions: null == gameLogActions ? _self.gameLogActions : gameLogActions // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineAction>,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<OnlineReaction>,series: freezed == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as OnlineSeriesStatus?,tournament: freezed == tournament ? _self.tournament : tournament // ignore: cast_nullable_to_non_nullable
as OnlineTournamentGameStatus?,snapshot: null == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as OnlineEngineSnapshot,
  ));
}
/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSeriesStatusCopyWith<$Res>? get series {
    if (_self.series == null) {
    return null;
  }

  return $OnlineSeriesStatusCopyWith<$Res>(_self.series!, (value) {
    return _then(_self.copyWith(series: value));
  });
}/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineTournamentGameStatusCopyWith<$Res>? get tournament {
    if (_self.tournament == null) {
    return null;
  }

  return $OnlineTournamentGameStatusCopyWith<$Res>(_self.tournament!, (value) {
    return _then(_self.copyWith(tournament: value));
  });
}/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineSnapshotCopyWith<$Res> get snapshot {
  
  return $OnlineEngineSnapshotCopyWith<$Res>(_self.snapshot, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineSessionUpdate].
extension OnlineSessionUpdatePatterns on OnlineSessionUpdate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSessionUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSessionUpdate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSessionUpdate value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionUpdate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSessionUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionUpdate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID,  int? seed, @JsonKey(readValue: _inviteCodeFromJson)  String inviteCode,  int? viewerID,  int actionLogCount,  bool isViewerTurn,  List<OnlineEngineAction> legalActions, @JsonKey(fromJson: _variantsFromJson)  KolkhozGameVariants variants, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  bool ranked,  bool browserJoinable,  List<OnlineSeatPresence> seatPresence,  int? turnPlayerID,  double? turnDeadlineAt,  bool started,  double? lobbyCountdownEndsAt,  List<OnlineEngineAction> gameLogActions,  List<OnlineReaction> reactions,  OnlineSeriesStatus? series,  OnlineTournamentGameStatus? tournament,  OnlineEngineSnapshot snapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSessionUpdate() when $default != null:
return $default(_that.sessionID,_that.seed,_that.inviteCode,_that.viewerID,_that.actionLogCount,_that.isViewerTurn,_that.legalActions,_that.variants,_that.controllers,_that.playerProfiles,_that.ranked,_that.browserJoinable,_that.seatPresence,_that.turnPlayerID,_that.turnDeadlineAt,_that.started,_that.lobbyCountdownEndsAt,_that.gameLogActions,_that.reactions,_that.series,_that.tournament,_that.snapshot);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID,  int? seed, @JsonKey(readValue: _inviteCodeFromJson)  String inviteCode,  int? viewerID,  int actionLogCount,  bool isViewerTurn,  List<OnlineEngineAction> legalActions, @JsonKey(fromJson: _variantsFromJson)  KolkhozGameVariants variants, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  bool ranked,  bool browserJoinable,  List<OnlineSeatPresence> seatPresence,  int? turnPlayerID,  double? turnDeadlineAt,  bool started,  double? lobbyCountdownEndsAt,  List<OnlineEngineAction> gameLogActions,  List<OnlineReaction> reactions,  OnlineSeriesStatus? series,  OnlineTournamentGameStatus? tournament,  OnlineEngineSnapshot snapshot)  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionUpdate():
return $default(_that.sessionID,_that.seed,_that.inviteCode,_that.viewerID,_that.actionLogCount,_that.isViewerTurn,_that.legalActions,_that.variants,_that.controllers,_that.playerProfiles,_that.ranked,_that.browserJoinable,_that.seatPresence,_that.turnPlayerID,_that.turnDeadlineAt,_that.started,_that.lobbyCountdownEndsAt,_that.gameLogActions,_that.reactions,_that.series,_that.tournament,_that.snapshot);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID,  int? seed, @JsonKey(readValue: _inviteCodeFromJson)  String inviteCode,  int? viewerID,  int actionLogCount,  bool isViewerTurn,  List<OnlineEngineAction> legalActions, @JsonKey(fromJson: _variantsFromJson)  KolkhozGameVariants variants, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  bool ranked,  bool browserJoinable,  List<OnlineSeatPresence> seatPresence,  int? turnPlayerID,  double? turnDeadlineAt,  bool started,  double? lobbyCountdownEndsAt,  List<OnlineEngineAction> gameLogActions,  List<OnlineReaction> reactions,  OnlineSeriesStatus? series,  OnlineTournamentGameStatus? tournament,  OnlineEngineSnapshot snapshot)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionUpdate() when $default != null:
return $default(_that.sessionID,_that.seed,_that.inviteCode,_that.viewerID,_that.actionLogCount,_that.isViewerTurn,_that.legalActions,_that.variants,_that.controllers,_that.playerProfiles,_that.ranked,_that.browserJoinable,_that.seatPresence,_that.turnPlayerID,_that.turnDeadlineAt,_that.started,_that.lobbyCountdownEndsAt,_that.gameLogActions,_that.reactions,_that.series,_that.tournament,_that.snapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSessionUpdate extends OnlineSessionUpdate {
  const _OnlineSessionUpdate({required this.sessionID, this.seed, @JsonKey(readValue: _inviteCodeFromJson) required this.inviteCode, required this.viewerID, required this.actionLogCount, this.isViewerTurn = false, final  List<OnlineEngineAction> legalActions = const [], @JsonKey(fromJson: _variantsFromJson) required this.variants, @JsonKey(fromJson: _controllersFromJson) required final  List<KolkhozPlayerController> controllers, final  List<OnlinePlayerProfile> playerProfiles = const [], this.ranked = true, this.browserJoinable = true, final  List<OnlineSeatPresence> seatPresence = const [], this.turnPlayerID, this.turnDeadlineAt, this.started = true, this.lobbyCountdownEndsAt, final  List<OnlineEngineAction> gameLogActions = const [], final  List<OnlineReaction> reactions = const [], this.series, this.tournament, required this.snapshot}): _legalActions = legalActions,_controllers = controllers,_playerProfiles = playerProfiles,_seatPresence = seatPresence,_gameLogActions = gameLogActions,_reactions = reactions,super._();
  factory _OnlineSessionUpdate.fromJson(Map<String, dynamic> json) => _$OnlineSessionUpdateFromJson(json);

@override final  String sessionID;
@override final  int? seed;
@override@JsonKey(readValue: _inviteCodeFromJson) final  String inviteCode;
@override final  int? viewerID;
@override final  int actionLogCount;
@override@JsonKey() final  bool isViewerTurn;
 final  List<OnlineEngineAction> _legalActions;
@override@JsonKey() List<OnlineEngineAction> get legalActions {
  if (_legalActions is EqualUnmodifiableListView) return _legalActions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_legalActions);
}

@override@JsonKey(fromJson: _variantsFromJson) final  KolkhozGameVariants variants;
 final  List<KolkhozPlayerController> _controllers;
@override@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> get controllers {
  if (_controllers is EqualUnmodifiableListView) return _controllers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_controllers);
}

 final  List<OnlinePlayerProfile> _playerProfiles;
@override@JsonKey() List<OnlinePlayerProfile> get playerProfiles {
  if (_playerProfiles is EqualUnmodifiableListView) return _playerProfiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_playerProfiles);
}

@override@JsonKey() final  bool ranked;
@override@JsonKey() final  bool browserJoinable;
 final  List<OnlineSeatPresence> _seatPresence;
@override@JsonKey() List<OnlineSeatPresence> get seatPresence {
  if (_seatPresence is EqualUnmodifiableListView) return _seatPresence;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seatPresence);
}

@override final  int? turnPlayerID;
@override final  double? turnDeadlineAt;
@override@JsonKey() final  bool started;
@override final  double? lobbyCountdownEndsAt;
 final  List<OnlineEngineAction> _gameLogActions;
@override@JsonKey() List<OnlineEngineAction> get gameLogActions {
  if (_gameLogActions is EqualUnmodifiableListView) return _gameLogActions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gameLogActions);
}

 final  List<OnlineReaction> _reactions;
@override@JsonKey() List<OnlineReaction> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

@override final  OnlineSeriesStatus? series;
@override final  OnlineTournamentGameStatus? tournament;
@override final  OnlineEngineSnapshot snapshot;

/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSessionUpdateCopyWith<_OnlineSessionUpdate> get copyWith => __$OnlineSessionUpdateCopyWithImpl<_OnlineSessionUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSessionUpdate&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.viewerID, viewerID) || other.viewerID == viewerID)&&(identical(other.actionLogCount, actionLogCount) || other.actionLogCount == actionLogCount)&&(identical(other.isViewerTurn, isViewerTurn) || other.isViewerTurn == isViewerTurn)&&const DeepCollectionEquality().equals(other._legalActions, _legalActions)&&(identical(other.variants, variants) || other.variants == variants)&&const DeepCollectionEquality().equals(other._controllers, _controllers)&&const DeepCollectionEquality().equals(other._playerProfiles, _playerProfiles)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.browserJoinable, browserJoinable) || other.browserJoinable == browserJoinable)&&const DeepCollectionEquality().equals(other._seatPresence, _seatPresence)&&(identical(other.turnPlayerID, turnPlayerID) || other.turnPlayerID == turnPlayerID)&&(identical(other.turnDeadlineAt, turnDeadlineAt) || other.turnDeadlineAt == turnDeadlineAt)&&(identical(other.started, started) || other.started == started)&&(identical(other.lobbyCountdownEndsAt, lobbyCountdownEndsAt) || other.lobbyCountdownEndsAt == lobbyCountdownEndsAt)&&const DeepCollectionEquality().equals(other._gameLogActions, _gameLogActions)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.series, series) || other.series == series)&&(identical(other.tournament, tournament) || other.tournament == tournament)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,sessionID,seed,inviteCode,viewerID,actionLogCount,isViewerTurn,const DeepCollectionEquality().hash(_legalActions),variants,const DeepCollectionEquality().hash(_controllers),const DeepCollectionEquality().hash(_playerProfiles),ranked,browserJoinable,const DeepCollectionEquality().hash(_seatPresence),turnPlayerID,turnDeadlineAt,started,lobbyCountdownEndsAt,const DeepCollectionEquality().hash(_gameLogActions),const DeepCollectionEquality().hash(_reactions),series,tournament,snapshot]);

@override
String toString() {
  return 'OnlineSessionUpdate(sessionID: $sessionID, seed: $seed, inviteCode: $inviteCode, viewerID: $viewerID, actionLogCount: $actionLogCount, isViewerTurn: $isViewerTurn, legalActions: $legalActions, variants: $variants, controllers: $controllers, playerProfiles: $playerProfiles, ranked: $ranked, browserJoinable: $browserJoinable, seatPresence: $seatPresence, turnPlayerID: $turnPlayerID, turnDeadlineAt: $turnDeadlineAt, started: $started, lobbyCountdownEndsAt: $lobbyCountdownEndsAt, gameLogActions: $gameLogActions, reactions: $reactions, series: $series, tournament: $tournament, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class _$OnlineSessionUpdateCopyWith<$Res> implements $OnlineSessionUpdateCopyWith<$Res> {
  factory _$OnlineSessionUpdateCopyWith(_OnlineSessionUpdate value, $Res Function(_OnlineSessionUpdate) _then) = __$OnlineSessionUpdateCopyWithImpl;
@override @useResult
$Res call({
 String sessionID, int? seed,@JsonKey(readValue: _inviteCodeFromJson) String inviteCode, int? viewerID, int actionLogCount, bool isViewerTurn, List<OnlineEngineAction> legalActions,@JsonKey(fromJson: _variantsFromJson) KolkhozGameVariants variants,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, List<OnlinePlayerProfile> playerProfiles, bool ranked, bool browserJoinable, List<OnlineSeatPresence> seatPresence, int? turnPlayerID, double? turnDeadlineAt, bool started, double? lobbyCountdownEndsAt, List<OnlineEngineAction> gameLogActions, List<OnlineReaction> reactions, OnlineSeriesStatus? series, OnlineTournamentGameStatus? tournament, OnlineEngineSnapshot snapshot
});


@override $OnlineSeriesStatusCopyWith<$Res>? get series;@override $OnlineTournamentGameStatusCopyWith<$Res>? get tournament;@override $OnlineEngineSnapshotCopyWith<$Res> get snapshot;

}
/// @nodoc
class __$OnlineSessionUpdateCopyWithImpl<$Res>
    implements _$OnlineSessionUpdateCopyWith<$Res> {
  __$OnlineSessionUpdateCopyWithImpl(this._self, this._then);

  final _OnlineSessionUpdate _self;
  final $Res Function(_OnlineSessionUpdate) _then;

/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? seed = freezed,Object? inviteCode = null,Object? viewerID = freezed,Object? actionLogCount = null,Object? isViewerTurn = null,Object? legalActions = null,Object? variants = null,Object? controllers = null,Object? playerProfiles = null,Object? ranked = null,Object? browserJoinable = null,Object? seatPresence = null,Object? turnPlayerID = freezed,Object? turnDeadlineAt = freezed,Object? started = null,Object? lobbyCountdownEndsAt = freezed,Object? gameLogActions = null,Object? reactions = null,Object? series = freezed,Object? tournament = freezed,Object? snapshot = null,}) {
  return _then(_OnlineSessionUpdate(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,viewerID: freezed == viewerID ? _self.viewerID : viewerID // ignore: cast_nullable_to_non_nullable
as int?,actionLogCount: null == actionLogCount ? _self.actionLogCount : actionLogCount // ignore: cast_nullable_to_non_nullable
as int,isViewerTurn: null == isViewerTurn ? _self.isViewerTurn : isViewerTurn // ignore: cast_nullable_to_non_nullable
as bool,legalActions: null == legalActions ? _self._legalActions : legalActions // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineAction>,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as KolkhozGameVariants,controllers: null == controllers ? _self._controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,playerProfiles: null == playerProfiles ? _self._playerProfiles : playerProfiles // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerProfile>,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,browserJoinable: null == browserJoinable ? _self.browserJoinable : browserJoinable // ignore: cast_nullable_to_non_nullable
as bool,seatPresence: null == seatPresence ? _self._seatPresence : seatPresence // ignore: cast_nullable_to_non_nullable
as List<OnlineSeatPresence>,turnPlayerID: freezed == turnPlayerID ? _self.turnPlayerID : turnPlayerID // ignore: cast_nullable_to_non_nullable
as int?,turnDeadlineAt: freezed == turnDeadlineAt ? _self.turnDeadlineAt : turnDeadlineAt // ignore: cast_nullable_to_non_nullable
as double?,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,lobbyCountdownEndsAt: freezed == lobbyCountdownEndsAt ? _self.lobbyCountdownEndsAt : lobbyCountdownEndsAt // ignore: cast_nullable_to_non_nullable
as double?,gameLogActions: null == gameLogActions ? _self._gameLogActions : gameLogActions // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineAction>,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<OnlineReaction>,series: freezed == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as OnlineSeriesStatus?,tournament: freezed == tournament ? _self.tournament : tournament // ignore: cast_nullable_to_non_nullable
as OnlineTournamentGameStatus?,snapshot: null == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as OnlineEngineSnapshot,
  ));
}

/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSeriesStatusCopyWith<$Res>? get series {
    if (_self.series == null) {
    return null;
  }

  return $OnlineSeriesStatusCopyWith<$Res>(_self.series!, (value) {
    return _then(_self.copyWith(series: value));
  });
}/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineTournamentGameStatusCopyWith<$Res>? get tournament {
    if (_self.tournament == null) {
    return null;
  }

  return $OnlineTournamentGameStatusCopyWith<$Res>(_self.tournament!, (value) {
    return _then(_self.copyWith(tournament: value));
  });
}/// Create a copy of OnlineSessionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineSnapshotCopyWith<$Res> get snapshot {
  
  return $OnlineEngineSnapshotCopyWith<$Res>(_self.snapshot, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// @nodoc
mixin _$OnlineSeriesStatus {

 String get seriesID; int get bestOf; int get roundNumber; bool get completed; int? get winnerPlayerID;@JsonKey(fromJson: _winsFromJson) Map<int, int> get wins;
/// Create a copy of OnlineSeriesStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSeriesStatusCopyWith<OnlineSeriesStatus> get copyWith => _$OnlineSeriesStatusCopyWithImpl<OnlineSeriesStatus>(this as OnlineSeriesStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSeriesStatus&&(identical(other.seriesID, seriesID) || other.seriesID == seriesID)&&(identical(other.bestOf, bestOf) || other.bestOf == bestOf)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.winnerPlayerID, winnerPlayerID) || other.winnerPlayerID == winnerPlayerID)&&const DeepCollectionEquality().equals(other.wins, wins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seriesID,bestOf,roundNumber,completed,winnerPlayerID,const DeepCollectionEquality().hash(wins));

@override
String toString() {
  return 'OnlineSeriesStatus(seriesID: $seriesID, bestOf: $bestOf, roundNumber: $roundNumber, completed: $completed, winnerPlayerID: $winnerPlayerID, wins: $wins)';
}


}

/// @nodoc
abstract mixin class $OnlineSeriesStatusCopyWith<$Res>  {
  factory $OnlineSeriesStatusCopyWith(OnlineSeriesStatus value, $Res Function(OnlineSeriesStatus) _then) = _$OnlineSeriesStatusCopyWithImpl;
@useResult
$Res call({
 String seriesID, int bestOf, int roundNumber, bool completed, int? winnerPlayerID,@JsonKey(fromJson: _winsFromJson) Map<int, int> wins
});




}
/// @nodoc
class _$OnlineSeriesStatusCopyWithImpl<$Res>
    implements $OnlineSeriesStatusCopyWith<$Res> {
  _$OnlineSeriesStatusCopyWithImpl(this._self, this._then);

  final OnlineSeriesStatus _self;
  final $Res Function(OnlineSeriesStatus) _then;

/// Create a copy of OnlineSeriesStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seriesID = null,Object? bestOf = null,Object? roundNumber = null,Object? completed = null,Object? winnerPlayerID = freezed,Object? wins = null,}) {
  return _then(_self.copyWith(
seriesID: null == seriesID ? _self.seriesID : seriesID // ignore: cast_nullable_to_non_nullable
as String,bestOf: null == bestOf ? _self.bestOf : bestOf // ignore: cast_nullable_to_non_nullable
as int,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,winnerPlayerID: freezed == winnerPlayerID ? _self.winnerPlayerID : winnerPlayerID // ignore: cast_nullable_to_non_nullable
as int?,wins: null == wins ? _self.wins : wins // ignore: cast_nullable_to_non_nullable
as Map<int, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineSeriesStatus].
extension OnlineSeriesStatusPatterns on OnlineSeriesStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSeriesStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSeriesStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSeriesStatus value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSeriesStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSeriesStatus value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSeriesStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String seriesID,  int bestOf,  int roundNumber,  bool completed,  int? winnerPlayerID, @JsonKey(fromJson: _winsFromJson)  Map<int, int> wins)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSeriesStatus() when $default != null:
return $default(_that.seriesID,_that.bestOf,_that.roundNumber,_that.completed,_that.winnerPlayerID,_that.wins);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String seriesID,  int bestOf,  int roundNumber,  bool completed,  int? winnerPlayerID, @JsonKey(fromJson: _winsFromJson)  Map<int, int> wins)  $default,) {final _that = this;
switch (_that) {
case _OnlineSeriesStatus():
return $default(_that.seriesID,_that.bestOf,_that.roundNumber,_that.completed,_that.winnerPlayerID,_that.wins);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String seriesID,  int bestOf,  int roundNumber,  bool completed,  int? winnerPlayerID, @JsonKey(fromJson: _winsFromJson)  Map<int, int> wins)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSeriesStatus() when $default != null:
return $default(_that.seriesID,_that.bestOf,_that.roundNumber,_that.completed,_that.winnerPlayerID,_that.wins);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSeriesStatus extends OnlineSeriesStatus {
  const _OnlineSeriesStatus({required this.seriesID, required this.bestOf, required this.roundNumber, this.completed = false, required this.winnerPlayerID, @JsonKey(fromJson: _winsFromJson) required final  Map<int, int> wins}): _wins = wins,super._();
  factory _OnlineSeriesStatus.fromJson(Map<String, dynamic> json) => _$OnlineSeriesStatusFromJson(json);

@override final  String seriesID;
@override final  int bestOf;
@override final  int roundNumber;
@override@JsonKey() final  bool completed;
@override final  int? winnerPlayerID;
 final  Map<int, int> _wins;
@override@JsonKey(fromJson: _winsFromJson) Map<int, int> get wins {
  if (_wins is EqualUnmodifiableMapView) return _wins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_wins);
}


/// Create a copy of OnlineSeriesStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSeriesStatusCopyWith<_OnlineSeriesStatus> get copyWith => __$OnlineSeriesStatusCopyWithImpl<_OnlineSeriesStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSeriesStatus&&(identical(other.seriesID, seriesID) || other.seriesID == seriesID)&&(identical(other.bestOf, bestOf) || other.bestOf == bestOf)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.winnerPlayerID, winnerPlayerID) || other.winnerPlayerID == winnerPlayerID)&&const DeepCollectionEquality().equals(other._wins, _wins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seriesID,bestOf,roundNumber,completed,winnerPlayerID,const DeepCollectionEquality().hash(_wins));

@override
String toString() {
  return 'OnlineSeriesStatus(seriesID: $seriesID, bestOf: $bestOf, roundNumber: $roundNumber, completed: $completed, winnerPlayerID: $winnerPlayerID, wins: $wins)';
}


}

/// @nodoc
abstract mixin class _$OnlineSeriesStatusCopyWith<$Res> implements $OnlineSeriesStatusCopyWith<$Res> {
  factory _$OnlineSeriesStatusCopyWith(_OnlineSeriesStatus value, $Res Function(_OnlineSeriesStatus) _then) = __$OnlineSeriesStatusCopyWithImpl;
@override @useResult
$Res call({
 String seriesID, int bestOf, int roundNumber, bool completed, int? winnerPlayerID,@JsonKey(fromJson: _winsFromJson) Map<int, int> wins
});




}
/// @nodoc
class __$OnlineSeriesStatusCopyWithImpl<$Res>
    implements _$OnlineSeriesStatusCopyWith<$Res> {
  __$OnlineSeriesStatusCopyWithImpl(this._self, this._then);

  final _OnlineSeriesStatus _self;
  final $Res Function(_OnlineSeriesStatus) _then;

/// Create a copy of OnlineSeriesStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seriesID = null,Object? bestOf = null,Object? roundNumber = null,Object? completed = null,Object? winnerPlayerID = freezed,Object? wins = null,}) {
  return _then(_OnlineSeriesStatus(
seriesID: null == seriesID ? _self.seriesID : seriesID // ignore: cast_nullable_to_non_nullable
as String,bestOf: null == bestOf ? _self.bestOf : bestOf // ignore: cast_nullable_to_non_nullable
as int,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,winnerPlayerID: freezed == winnerPlayerID ? _self.winnerPlayerID : winnerPlayerID // ignore: cast_nullable_to_non_nullable
as int?,wins: null == wins ? _self._wins : wins // ignore: cast_nullable_to_non_nullable
as Map<int, int>,
  ));
}


}


/// @nodoc
mixin _$OnlineReaction {

 int get revision; int get playerID; String get reactionID; int get year; int get phase; double get createdAt;
/// Create a copy of OnlineReaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineReactionCopyWith<OnlineReaction> get copyWith => _$OnlineReactionCopyWithImpl<OnlineReaction>(this as OnlineReaction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineReaction&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.reactionID, reactionID) || other.reactionID == reactionID)&&(identical(other.year, year) || other.year == year)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,revision,playerID,reactionID,year,phase,createdAt);

@override
String toString() {
  return 'OnlineReaction(revision: $revision, playerID: $playerID, reactionID: $reactionID, year: $year, phase: $phase, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OnlineReactionCopyWith<$Res>  {
  factory $OnlineReactionCopyWith(OnlineReaction value, $Res Function(OnlineReaction) _then) = _$OnlineReactionCopyWithImpl;
@useResult
$Res call({
 int revision, int playerID, String reactionID, int year, int phase, double createdAt
});




}
/// @nodoc
class _$OnlineReactionCopyWithImpl<$Res>
    implements $OnlineReactionCopyWith<$Res> {
  _$OnlineReactionCopyWithImpl(this._self, this._then);

  final OnlineReaction _self;
  final $Res Function(OnlineReaction) _then;

/// Create a copy of OnlineReaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revision = null,Object? playerID = null,Object? reactionID = null,Object? year = null,Object? phase = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,reactionID: null == reactionID ? _self.reactionID : reactionID // ignore: cast_nullable_to_non_nullable
as String,year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineReaction].
extension OnlineReactionPatterns on OnlineReaction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineReaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineReaction() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineReaction value)  $default,){
final _that = this;
switch (_that) {
case _OnlineReaction():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineReaction value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineReaction() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int revision,  int playerID,  String reactionID,  int year,  int phase,  double createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineReaction() when $default != null:
return $default(_that.revision,_that.playerID,_that.reactionID,_that.year,_that.phase,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int revision,  int playerID,  String reactionID,  int year,  int phase,  double createdAt)  $default,) {final _that = this;
switch (_that) {
case _OnlineReaction():
return $default(_that.revision,_that.playerID,_that.reactionID,_that.year,_that.phase,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int revision,  int playerID,  String reactionID,  int year,  int phase,  double createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OnlineReaction() when $default != null:
return $default(_that.revision,_that.playerID,_that.reactionID,_that.year,_that.phase,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineReaction implements OnlineReaction {
  const _OnlineReaction({required this.revision, required this.playerID, required this.reactionID, required this.year, required this.phase, required this.createdAt});
  factory _OnlineReaction.fromJson(Map<String, dynamic> json) => _$OnlineReactionFromJson(json);

@override final  int revision;
@override final  int playerID;
@override final  String reactionID;
@override final  int year;
@override final  int phase;
@override final  double createdAt;

/// Create a copy of OnlineReaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineReactionCopyWith<_OnlineReaction> get copyWith => __$OnlineReactionCopyWithImpl<_OnlineReaction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineReaction&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.reactionID, reactionID) || other.reactionID == reactionID)&&(identical(other.year, year) || other.year == year)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,revision,playerID,reactionID,year,phase,createdAt);

@override
String toString() {
  return 'OnlineReaction(revision: $revision, playerID: $playerID, reactionID: $reactionID, year: $year, phase: $phase, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OnlineReactionCopyWith<$Res> implements $OnlineReactionCopyWith<$Res> {
  factory _$OnlineReactionCopyWith(_OnlineReaction value, $Res Function(_OnlineReaction) _then) = __$OnlineReactionCopyWithImpl;
@override @useResult
$Res call({
 int revision, int playerID, String reactionID, int year, int phase, double createdAt
});




}
/// @nodoc
class __$OnlineReactionCopyWithImpl<$Res>
    implements _$OnlineReactionCopyWith<$Res> {
  __$OnlineReactionCopyWithImpl(this._self, this._then);

  final _OnlineReaction _self;
  final $Res Function(_OnlineReaction) _then;

/// Create a copy of OnlineReaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revision = null,Object? playerID = null,Object? reactionID = null,Object? year = null,Object? phase = null,Object? createdAt = null,}) {
  return _then(_OnlineReaction(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,reactionID: null == reactionID ? _self.reactionID : reactionID // ignore: cast_nullable_to_non_nullable
as String,year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$OnlineSeatPresence {

 int get playerID; bool get connected; double? get lastSeenAt; int get timeouts; bool get autopilot; bool get abandoned;
/// Create a copy of OnlineSeatPresence
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSeatPresenceCopyWith<OnlineSeatPresence> get copyWith => _$OnlineSeatPresenceCopyWithImpl<OnlineSeatPresence>(this as OnlineSeatPresence, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSeatPresence&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.lastSeenAt, lastSeenAt) || other.lastSeenAt == lastSeenAt)&&(identical(other.timeouts, timeouts) || other.timeouts == timeouts)&&(identical(other.autopilot, autopilot) || other.autopilot == autopilot)&&(identical(other.abandoned, abandoned) || other.abandoned == abandoned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,connected,lastSeenAt,timeouts,autopilot,abandoned);

@override
String toString() {
  return 'OnlineSeatPresence(playerID: $playerID, connected: $connected, lastSeenAt: $lastSeenAt, timeouts: $timeouts, autopilot: $autopilot, abandoned: $abandoned)';
}


}

/// @nodoc
abstract mixin class $OnlineSeatPresenceCopyWith<$Res>  {
  factory $OnlineSeatPresenceCopyWith(OnlineSeatPresence value, $Res Function(OnlineSeatPresence) _then) = _$OnlineSeatPresenceCopyWithImpl;
@useResult
$Res call({
 int playerID, bool connected, double? lastSeenAt, int timeouts, bool autopilot, bool abandoned
});




}
/// @nodoc
class _$OnlineSeatPresenceCopyWithImpl<$Res>
    implements $OnlineSeatPresenceCopyWith<$Res> {
  _$OnlineSeatPresenceCopyWithImpl(this._self, this._then);

  final OnlineSeatPresence _self;
  final $Res Function(OnlineSeatPresence) _then;

/// Create a copy of OnlineSeatPresence
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerID = null,Object? connected = null,Object? lastSeenAt = freezed,Object? timeouts = null,Object? autopilot = null,Object? abandoned = null,}) {
  return _then(_self.copyWith(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,lastSeenAt: freezed == lastSeenAt ? _self.lastSeenAt : lastSeenAt // ignore: cast_nullable_to_non_nullable
as double?,timeouts: null == timeouts ? _self.timeouts : timeouts // ignore: cast_nullable_to_non_nullable
as int,autopilot: null == autopilot ? _self.autopilot : autopilot // ignore: cast_nullable_to_non_nullable
as bool,abandoned: null == abandoned ? _self.abandoned : abandoned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineSeatPresence].
extension OnlineSeatPresencePatterns on OnlineSeatPresence {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSeatPresence value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSeatPresence() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSeatPresence value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSeatPresence():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSeatPresence value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSeatPresence() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int playerID,  bool connected,  double? lastSeenAt,  int timeouts,  bool autopilot,  bool abandoned)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSeatPresence() when $default != null:
return $default(_that.playerID,_that.connected,_that.lastSeenAt,_that.timeouts,_that.autopilot,_that.abandoned);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int playerID,  bool connected,  double? lastSeenAt,  int timeouts,  bool autopilot,  bool abandoned)  $default,) {final _that = this;
switch (_that) {
case _OnlineSeatPresence():
return $default(_that.playerID,_that.connected,_that.lastSeenAt,_that.timeouts,_that.autopilot,_that.abandoned);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int playerID,  bool connected,  double? lastSeenAt,  int timeouts,  bool autopilot,  bool abandoned)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSeatPresence() when $default != null:
return $default(_that.playerID,_that.connected,_that.lastSeenAt,_that.timeouts,_that.autopilot,_that.abandoned);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSeatPresence implements OnlineSeatPresence {
  const _OnlineSeatPresence({required this.playerID, this.connected = false, this.lastSeenAt, this.timeouts = 0, this.autopilot = false, this.abandoned = false});
  factory _OnlineSeatPresence.fromJson(Map<String, dynamic> json) => _$OnlineSeatPresenceFromJson(json);

@override final  int playerID;
@override@JsonKey() final  bool connected;
@override final  double? lastSeenAt;
@override@JsonKey() final  int timeouts;
@override@JsonKey() final  bool autopilot;
@override@JsonKey() final  bool abandoned;

/// Create a copy of OnlineSeatPresence
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSeatPresenceCopyWith<_OnlineSeatPresence> get copyWith => __$OnlineSeatPresenceCopyWithImpl<_OnlineSeatPresence>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSeatPresence&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.lastSeenAt, lastSeenAt) || other.lastSeenAt == lastSeenAt)&&(identical(other.timeouts, timeouts) || other.timeouts == timeouts)&&(identical(other.autopilot, autopilot) || other.autopilot == autopilot)&&(identical(other.abandoned, abandoned) || other.abandoned == abandoned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,connected,lastSeenAt,timeouts,autopilot,abandoned);

@override
String toString() {
  return 'OnlineSeatPresence(playerID: $playerID, connected: $connected, lastSeenAt: $lastSeenAt, timeouts: $timeouts, autopilot: $autopilot, abandoned: $abandoned)';
}


}

/// @nodoc
abstract mixin class _$OnlineSeatPresenceCopyWith<$Res> implements $OnlineSeatPresenceCopyWith<$Res> {
  factory _$OnlineSeatPresenceCopyWith(_OnlineSeatPresence value, $Res Function(_OnlineSeatPresence) _then) = __$OnlineSeatPresenceCopyWithImpl;
@override @useResult
$Res call({
 int playerID, bool connected, double? lastSeenAt, int timeouts, bool autopilot, bool abandoned
});




}
/// @nodoc
class __$OnlineSeatPresenceCopyWithImpl<$Res>
    implements _$OnlineSeatPresenceCopyWith<$Res> {
  __$OnlineSeatPresenceCopyWithImpl(this._self, this._then);

  final _OnlineSeatPresence _self;
  final $Res Function(_OnlineSeatPresence) _then;

/// Create a copy of OnlineSeatPresence
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerID = null,Object? connected = null,Object? lastSeenAt = freezed,Object? timeouts = null,Object? autopilot = null,Object? abandoned = null,}) {
  return _then(_OnlineSeatPresence(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,lastSeenAt: freezed == lastSeenAt ? _self.lastSeenAt : lastSeenAt // ignore: cast_nullable_to_non_nullable
as double?,timeouts: null == timeouts ? _self.timeouts : timeouts // ignore: cast_nullable_to_non_nullable
as int,autopilot: null == autopilot ? _self.autopilot : autopilot // ignore: cast_nullable_to_non_nullable
as bool,abandoned: null == abandoned ? _self.abandoned : abandoned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$OnlineSessionResponse {

 String get sessionID;@JsonKey(readValue: _inviteCodeFromJson) String get inviteCode; int get playerID; String get seatToken; OnlineSessionUpdate get update;
/// Create a copy of OnlineSessionResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSessionResponseCopyWith<OnlineSessionResponse> get copyWith => _$OnlineSessionResponseCopyWithImpl<OnlineSessionResponse>(this as OnlineSessionResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSessionResponse&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.seatToken, seatToken) || other.seatToken == seatToken)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,inviteCode,playerID,seatToken,update);

@override
String toString() {
  return 'OnlineSessionResponse(sessionID: $sessionID, inviteCode: $inviteCode, playerID: $playerID, seatToken: $seatToken, update: $update)';
}


}

/// @nodoc
abstract mixin class $OnlineSessionResponseCopyWith<$Res>  {
  factory $OnlineSessionResponseCopyWith(OnlineSessionResponse value, $Res Function(OnlineSessionResponse) _then) = _$OnlineSessionResponseCopyWithImpl;
@useResult
$Res call({
 String sessionID,@JsonKey(readValue: _inviteCodeFromJson) String inviteCode, int playerID, String seatToken, OnlineSessionUpdate update
});


$OnlineSessionUpdateCopyWith<$Res> get update;

}
/// @nodoc
class _$OnlineSessionResponseCopyWithImpl<$Res>
    implements $OnlineSessionResponseCopyWith<$Res> {
  _$OnlineSessionResponseCopyWithImpl(this._self, this._then);

  final OnlineSessionResponse _self;
  final $Res Function(OnlineSessionResponse) _then;

/// Create a copy of OnlineSessionResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? inviteCode = null,Object? playerID = null,Object? seatToken = null,Object? update = null,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,seatToken: null == seatToken ? _self.seatToken : seatToken // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as OnlineSessionUpdate,
  ));
}
/// Create a copy of OnlineSessionResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<$Res> get update {
  
  return $OnlineSessionUpdateCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineSessionResponse].
extension OnlineSessionResponsePatterns on OnlineSessionResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSessionResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSessionResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSessionResponse value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSessionResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID, @JsonKey(readValue: _inviteCodeFromJson)  String inviteCode,  int playerID,  String seatToken,  OnlineSessionUpdate update)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSessionResponse() when $default != null:
return $default(_that.sessionID,_that.inviteCode,_that.playerID,_that.seatToken,_that.update);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID, @JsonKey(readValue: _inviteCodeFromJson)  String inviteCode,  int playerID,  String seatToken,  OnlineSessionUpdate update)  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionResponse():
return $default(_that.sessionID,_that.inviteCode,_that.playerID,_that.seatToken,_that.update);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID, @JsonKey(readValue: _inviteCodeFromJson)  String inviteCode,  int playerID,  String seatToken,  OnlineSessionUpdate update)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionResponse() when $default != null:
return $default(_that.sessionID,_that.inviteCode,_that.playerID,_that.seatToken,_that.update);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSessionResponse implements OnlineSessionResponse {
  const _OnlineSessionResponse({required this.sessionID, @JsonKey(readValue: _inviteCodeFromJson) required this.inviteCode, required this.playerID, required this.seatToken, required this.update});
  factory _OnlineSessionResponse.fromJson(Map<String, dynamic> json) => _$OnlineSessionResponseFromJson(json);

@override final  String sessionID;
@override@JsonKey(readValue: _inviteCodeFromJson) final  String inviteCode;
@override final  int playerID;
@override final  String seatToken;
@override final  OnlineSessionUpdate update;

/// Create a copy of OnlineSessionResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSessionResponseCopyWith<_OnlineSessionResponse> get copyWith => __$OnlineSessionResponseCopyWithImpl<_OnlineSessionResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSessionResponse&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.seatToken, seatToken) || other.seatToken == seatToken)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,inviteCode,playerID,seatToken,update);

@override
String toString() {
  return 'OnlineSessionResponse(sessionID: $sessionID, inviteCode: $inviteCode, playerID: $playerID, seatToken: $seatToken, update: $update)';
}


}

/// @nodoc
abstract mixin class _$OnlineSessionResponseCopyWith<$Res> implements $OnlineSessionResponseCopyWith<$Res> {
  factory _$OnlineSessionResponseCopyWith(_OnlineSessionResponse value, $Res Function(_OnlineSessionResponse) _then) = __$OnlineSessionResponseCopyWithImpl;
@override @useResult
$Res call({
 String sessionID,@JsonKey(readValue: _inviteCodeFromJson) String inviteCode, int playerID, String seatToken, OnlineSessionUpdate update
});


@override $OnlineSessionUpdateCopyWith<$Res> get update;

}
/// @nodoc
class __$OnlineSessionResponseCopyWithImpl<$Res>
    implements _$OnlineSessionResponseCopyWith<$Res> {
  __$OnlineSessionResponseCopyWithImpl(this._self, this._then);

  final _OnlineSessionResponse _self;
  final $Res Function(_OnlineSessionResponse) _then;

/// Create a copy of OnlineSessionResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? inviteCode = null,Object? playerID = null,Object? seatToken = null,Object? update = null,}) {
  return _then(_OnlineSessionResponse(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,seatToken: null == seatToken ? _self.seatToken : seatToken // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as OnlineSessionUpdate,
  ));
}

/// Create a copy of OnlineSessionResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<$Res> get update {
  
  return $OnlineSessionUpdateCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}


/// @nodoc
mixin _$OnlineActionUpdate {

 int get revision; OnlineEngineAction get action; OnlineSessionUpdate get update;
/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineActionUpdateCopyWith<OnlineActionUpdate> get copyWith => _$OnlineActionUpdateCopyWithImpl<OnlineActionUpdate>(this as OnlineActionUpdate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineActionUpdate&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.action, action) || other.action == action)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,revision,action,update);

@override
String toString() {
  return 'OnlineActionUpdate(revision: $revision, action: $action, update: $update)';
}


}

/// @nodoc
abstract mixin class $OnlineActionUpdateCopyWith<$Res>  {
  factory $OnlineActionUpdateCopyWith(OnlineActionUpdate value, $Res Function(OnlineActionUpdate) _then) = _$OnlineActionUpdateCopyWithImpl;
@useResult
$Res call({
 int revision, OnlineEngineAction action, OnlineSessionUpdate update
});


$OnlineEngineActionCopyWith<$Res> get action;$OnlineSessionUpdateCopyWith<$Res> get update;

}
/// @nodoc
class _$OnlineActionUpdateCopyWithImpl<$Res>
    implements $OnlineActionUpdateCopyWith<$Res> {
  _$OnlineActionUpdateCopyWithImpl(this._self, this._then);

  final OnlineActionUpdate _self;
  final $Res Function(OnlineActionUpdate) _then;

/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revision = null,Object? action = null,Object? update = null,}) {
  return _then(_self.copyWith(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as OnlineEngineAction,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as OnlineSessionUpdate,
  ));
}
/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineActionCopyWith<$Res> get action {
  
  return $OnlineEngineActionCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<$Res> get update {
  
  return $OnlineSessionUpdateCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineActionUpdate].
extension OnlineActionUpdatePatterns on OnlineActionUpdate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineActionUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineActionUpdate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineActionUpdate value)  $default,){
final _that = this;
switch (_that) {
case _OnlineActionUpdate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineActionUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineActionUpdate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int revision,  OnlineEngineAction action,  OnlineSessionUpdate update)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineActionUpdate() when $default != null:
return $default(_that.revision,_that.action,_that.update);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int revision,  OnlineEngineAction action,  OnlineSessionUpdate update)  $default,) {final _that = this;
switch (_that) {
case _OnlineActionUpdate():
return $default(_that.revision,_that.action,_that.update);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int revision,  OnlineEngineAction action,  OnlineSessionUpdate update)?  $default,) {final _that = this;
switch (_that) {
case _OnlineActionUpdate() when $default != null:
return $default(_that.revision,_that.action,_that.update);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineActionUpdate implements OnlineActionUpdate {
  const _OnlineActionUpdate({required this.revision, required this.action, required this.update});
  factory _OnlineActionUpdate.fromJson(Map<String, dynamic> json) => _$OnlineActionUpdateFromJson(json);

@override final  int revision;
@override final  OnlineEngineAction action;
@override final  OnlineSessionUpdate update;

/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineActionUpdateCopyWith<_OnlineActionUpdate> get copyWith => __$OnlineActionUpdateCopyWithImpl<_OnlineActionUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineActionUpdate&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.action, action) || other.action == action)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,revision,action,update);

@override
String toString() {
  return 'OnlineActionUpdate(revision: $revision, action: $action, update: $update)';
}


}

/// @nodoc
abstract mixin class _$OnlineActionUpdateCopyWith<$Res> implements $OnlineActionUpdateCopyWith<$Res> {
  factory _$OnlineActionUpdateCopyWith(_OnlineActionUpdate value, $Res Function(_OnlineActionUpdate) _then) = __$OnlineActionUpdateCopyWithImpl;
@override @useResult
$Res call({
 int revision, OnlineEngineAction action, OnlineSessionUpdate update
});


@override $OnlineEngineActionCopyWith<$Res> get action;@override $OnlineSessionUpdateCopyWith<$Res> get update;

}
/// @nodoc
class __$OnlineActionUpdateCopyWithImpl<$Res>
    implements _$OnlineActionUpdateCopyWith<$Res> {
  __$OnlineActionUpdateCopyWithImpl(this._self, this._then);

  final _OnlineActionUpdate _self;
  final $Res Function(_OnlineActionUpdate) _then;

/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revision = null,Object? action = null,Object? update = null,}) {
  return _then(_OnlineActionUpdate(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as OnlineEngineAction,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as OnlineSessionUpdate,
  ));
}

/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineActionCopyWith<$Res> get action {
  
  return $OnlineEngineActionCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}/// Create a copy of OnlineActionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<$Res> get update {
  
  return $OnlineSessionUpdateCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}


/// @nodoc
mixin _$OnlineActionUpdatesResponse {

 String get sessionID; int get actionLogCount; List<OnlineActionUpdate> get updates; OnlineSessionUpdate? get resyncUpdate;
/// Create a copy of OnlineActionUpdatesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineActionUpdatesResponseCopyWith<OnlineActionUpdatesResponse> get copyWith => _$OnlineActionUpdatesResponseCopyWithImpl<OnlineActionUpdatesResponse>(this as OnlineActionUpdatesResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineActionUpdatesResponse&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.actionLogCount, actionLogCount) || other.actionLogCount == actionLogCount)&&const DeepCollectionEquality().equals(other.updates, updates)&&(identical(other.resyncUpdate, resyncUpdate) || other.resyncUpdate == resyncUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,actionLogCount,const DeepCollectionEquality().hash(updates),resyncUpdate);

@override
String toString() {
  return 'OnlineActionUpdatesResponse(sessionID: $sessionID, actionLogCount: $actionLogCount, updates: $updates, resyncUpdate: $resyncUpdate)';
}


}

/// @nodoc
abstract mixin class $OnlineActionUpdatesResponseCopyWith<$Res>  {
  factory $OnlineActionUpdatesResponseCopyWith(OnlineActionUpdatesResponse value, $Res Function(OnlineActionUpdatesResponse) _then) = _$OnlineActionUpdatesResponseCopyWithImpl;
@useResult
$Res call({
 String sessionID, int actionLogCount, List<OnlineActionUpdate> updates, OnlineSessionUpdate? resyncUpdate
});


$OnlineSessionUpdateCopyWith<$Res>? get resyncUpdate;

}
/// @nodoc
class _$OnlineActionUpdatesResponseCopyWithImpl<$Res>
    implements $OnlineActionUpdatesResponseCopyWith<$Res> {
  _$OnlineActionUpdatesResponseCopyWithImpl(this._self, this._then);

  final OnlineActionUpdatesResponse _self;
  final $Res Function(OnlineActionUpdatesResponse) _then;

/// Create a copy of OnlineActionUpdatesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? actionLogCount = null,Object? updates = null,Object? resyncUpdate = freezed,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,actionLogCount: null == actionLogCount ? _self.actionLogCount : actionLogCount // ignore: cast_nullable_to_non_nullable
as int,updates: null == updates ? _self.updates : updates // ignore: cast_nullable_to_non_nullable
as List<OnlineActionUpdate>,resyncUpdate: freezed == resyncUpdate ? _self.resyncUpdate : resyncUpdate // ignore: cast_nullable_to_non_nullable
as OnlineSessionUpdate?,
  ));
}
/// Create a copy of OnlineActionUpdatesResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<$Res>? get resyncUpdate {
    if (_self.resyncUpdate == null) {
    return null;
  }

  return $OnlineSessionUpdateCopyWith<$Res>(_self.resyncUpdate!, (value) {
    return _then(_self.copyWith(resyncUpdate: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineActionUpdatesResponse].
extension OnlineActionUpdatesResponsePatterns on OnlineActionUpdatesResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineActionUpdatesResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineActionUpdatesResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineActionUpdatesResponse value)  $default,){
final _that = this;
switch (_that) {
case _OnlineActionUpdatesResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineActionUpdatesResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineActionUpdatesResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID,  int actionLogCount,  List<OnlineActionUpdate> updates,  OnlineSessionUpdate? resyncUpdate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineActionUpdatesResponse() when $default != null:
return $default(_that.sessionID,_that.actionLogCount,_that.updates,_that.resyncUpdate);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID,  int actionLogCount,  List<OnlineActionUpdate> updates,  OnlineSessionUpdate? resyncUpdate)  $default,) {final _that = this;
switch (_that) {
case _OnlineActionUpdatesResponse():
return $default(_that.sessionID,_that.actionLogCount,_that.updates,_that.resyncUpdate);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID,  int actionLogCount,  List<OnlineActionUpdate> updates,  OnlineSessionUpdate? resyncUpdate)?  $default,) {final _that = this;
switch (_that) {
case _OnlineActionUpdatesResponse() when $default != null:
return $default(_that.sessionID,_that.actionLogCount,_that.updates,_that.resyncUpdate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineActionUpdatesResponse implements OnlineActionUpdatesResponse {
  const _OnlineActionUpdatesResponse({required this.sessionID, required this.actionLogCount, final  List<OnlineActionUpdate> updates = const [], this.resyncUpdate}): _updates = updates;
  factory _OnlineActionUpdatesResponse.fromJson(Map<String, dynamic> json) => _$OnlineActionUpdatesResponseFromJson(json);

@override final  String sessionID;
@override final  int actionLogCount;
 final  List<OnlineActionUpdate> _updates;
@override@JsonKey() List<OnlineActionUpdate> get updates {
  if (_updates is EqualUnmodifiableListView) return _updates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_updates);
}

@override final  OnlineSessionUpdate? resyncUpdate;

/// Create a copy of OnlineActionUpdatesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineActionUpdatesResponseCopyWith<_OnlineActionUpdatesResponse> get copyWith => __$OnlineActionUpdatesResponseCopyWithImpl<_OnlineActionUpdatesResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineActionUpdatesResponse&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.actionLogCount, actionLogCount) || other.actionLogCount == actionLogCount)&&const DeepCollectionEquality().equals(other._updates, _updates)&&(identical(other.resyncUpdate, resyncUpdate) || other.resyncUpdate == resyncUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,actionLogCount,const DeepCollectionEquality().hash(_updates),resyncUpdate);

@override
String toString() {
  return 'OnlineActionUpdatesResponse(sessionID: $sessionID, actionLogCount: $actionLogCount, updates: $updates, resyncUpdate: $resyncUpdate)';
}


}

/// @nodoc
abstract mixin class _$OnlineActionUpdatesResponseCopyWith<$Res> implements $OnlineActionUpdatesResponseCopyWith<$Res> {
  factory _$OnlineActionUpdatesResponseCopyWith(_OnlineActionUpdatesResponse value, $Res Function(_OnlineActionUpdatesResponse) _then) = __$OnlineActionUpdatesResponseCopyWithImpl;
@override @useResult
$Res call({
 String sessionID, int actionLogCount, List<OnlineActionUpdate> updates, OnlineSessionUpdate? resyncUpdate
});


@override $OnlineSessionUpdateCopyWith<$Res>? get resyncUpdate;

}
/// @nodoc
class __$OnlineActionUpdatesResponseCopyWithImpl<$Res>
    implements _$OnlineActionUpdatesResponseCopyWith<$Res> {
  __$OnlineActionUpdatesResponseCopyWithImpl(this._self, this._then);

  final _OnlineActionUpdatesResponse _self;
  final $Res Function(_OnlineActionUpdatesResponse) _then;

/// Create a copy of OnlineActionUpdatesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? actionLogCount = null,Object? updates = null,Object? resyncUpdate = freezed,}) {
  return _then(_OnlineActionUpdatesResponse(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,actionLogCount: null == actionLogCount ? _self.actionLogCount : actionLogCount // ignore: cast_nullable_to_non_nullable
as int,updates: null == updates ? _self._updates : updates // ignore: cast_nullable_to_non_nullable
as List<OnlineActionUpdate>,resyncUpdate: freezed == resyncUpdate ? _self.resyncUpdate : resyncUpdate // ignore: cast_nullable_to_non_nullable
as OnlineSessionUpdate?,
  ));
}

/// Create a copy of OnlineActionUpdatesResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineSessionUpdateCopyWith<$Res>? get resyncUpdate {
    if (_self.resyncUpdate == null) {
    return null;
  }

  return $OnlineSessionUpdateCopyWith<$Res>(_self.resyncUpdate!, (value) {
    return _then(_self.copyWith(resyncUpdate: value));
  });
}
}

// dart format on
