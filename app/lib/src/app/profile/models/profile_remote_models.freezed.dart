// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_remote_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OnlinePlayerProfile {

 int get playerID; String? get userID; String? get displayName; String? get avatarURL;@JsonKey(fromJson: profileStatsFromJson) KolkhozProfileStats get stats;
/// Create a copy of OnlinePlayerProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlinePlayerProfileCopyWith<OnlinePlayerProfile> get copyWith => _$OnlinePlayerProfileCopyWithImpl<OnlinePlayerProfile>(this as OnlinePlayerProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlinePlayerProfile&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarURL, avatarURL) || other.avatarURL == avatarURL)&&(identical(other.stats, stats) || other.stats == stats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,userID,displayName,avatarURL,stats);

@override
String toString() {
  return 'OnlinePlayerProfile(playerID: $playerID, userID: $userID, displayName: $displayName, avatarURL: $avatarURL, stats: $stats)';
}


}

/// @nodoc
abstract mixin class $OnlinePlayerProfileCopyWith<$Res>  {
  factory $OnlinePlayerProfileCopyWith(OnlinePlayerProfile value, $Res Function(OnlinePlayerProfile) _then) = _$OnlinePlayerProfileCopyWithImpl;
@useResult
$Res call({
 int playerID, String? userID, String? displayName, String? avatarURL,@JsonKey(fromJson: profileStatsFromJson) KolkhozProfileStats stats
});




}
/// @nodoc
class _$OnlinePlayerProfileCopyWithImpl<$Res>
    implements $OnlinePlayerProfileCopyWith<$Res> {
  _$OnlinePlayerProfileCopyWithImpl(this._self, this._then);

  final OnlinePlayerProfile _self;
  final $Res Function(OnlinePlayerProfile) _then;

/// Create a copy of OnlinePlayerProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerID = null,Object? userID = freezed,Object? displayName = freezed,Object? avatarURL = freezed,Object? stats = null,}) {
  return _then(_self.copyWith(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,userID: freezed == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarURL: freezed == avatarURL ? _self.avatarURL : avatarURL // ignore: cast_nullable_to_non_nullable
as String?,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as KolkhozProfileStats,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlinePlayerProfile].
extension OnlinePlayerProfilePatterns on OnlinePlayerProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlinePlayerProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlinePlayerProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlinePlayerProfile value)  $default,){
final _that = this;
switch (_that) {
case _OnlinePlayerProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlinePlayerProfile value)?  $default,){
final _that = this;
switch (_that) {
case _OnlinePlayerProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int playerID,  String? userID,  String? displayName,  String? avatarURL, @JsonKey(fromJson: profileStatsFromJson)  KolkhozProfileStats stats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlinePlayerProfile() when $default != null:
return $default(_that.playerID,_that.userID,_that.displayName,_that.avatarURL,_that.stats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int playerID,  String? userID,  String? displayName,  String? avatarURL, @JsonKey(fromJson: profileStatsFromJson)  KolkhozProfileStats stats)  $default,) {final _that = this;
switch (_that) {
case _OnlinePlayerProfile():
return $default(_that.playerID,_that.userID,_that.displayName,_that.avatarURL,_that.stats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int playerID,  String? userID,  String? displayName,  String? avatarURL, @JsonKey(fromJson: profileStatsFromJson)  KolkhozProfileStats stats)?  $default,) {final _that = this;
switch (_that) {
case _OnlinePlayerProfile() when $default != null:
return $default(_that.playerID,_that.userID,_that.displayName,_that.avatarURL,_that.stats);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlinePlayerProfile extends OnlinePlayerProfile {
  const _OnlinePlayerProfile({required this.playerID, this.userID, this.displayName, this.avatarURL, @JsonKey(fromJson: profileStatsFromJson) this.stats = defaultProfileStats}): super._();
  factory _OnlinePlayerProfile.fromJson(Map<String, dynamic> json) => _$OnlinePlayerProfileFromJson(json);

@override final  int playerID;
@override final  String? userID;
@override final  String? displayName;
@override final  String? avatarURL;
@override@JsonKey(fromJson: profileStatsFromJson) final  KolkhozProfileStats stats;

/// Create a copy of OnlinePlayerProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlinePlayerProfileCopyWith<_OnlinePlayerProfile> get copyWith => __$OnlinePlayerProfileCopyWithImpl<_OnlinePlayerProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlinePlayerProfile&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarURL, avatarURL) || other.avatarURL == avatarURL)&&(identical(other.stats, stats) || other.stats == stats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,userID,displayName,avatarURL,stats);

@override
String toString() {
  return 'OnlinePlayerProfile(playerID: $playerID, userID: $userID, displayName: $displayName, avatarURL: $avatarURL, stats: $stats)';
}


}

/// @nodoc
abstract mixin class _$OnlinePlayerProfileCopyWith<$Res> implements $OnlinePlayerProfileCopyWith<$Res> {
  factory _$OnlinePlayerProfileCopyWith(_OnlinePlayerProfile value, $Res Function(_OnlinePlayerProfile) _then) = __$OnlinePlayerProfileCopyWithImpl;
@override @useResult
$Res call({
 int playerID, String? userID, String? displayName, String? avatarURL,@JsonKey(fromJson: profileStatsFromJson) KolkhozProfileStats stats
});




}
/// @nodoc
class __$OnlinePlayerProfileCopyWithImpl<$Res>
    implements _$OnlinePlayerProfileCopyWith<$Res> {
  __$OnlinePlayerProfileCopyWithImpl(this._self, this._then);

  final _OnlinePlayerProfile _self;
  final $Res Function(_OnlinePlayerProfile) _then;

/// Create a copy of OnlinePlayerProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerID = null,Object? userID = freezed,Object? displayName = freezed,Object? avatarURL = freezed,Object? stats = null,}) {
  return _then(_OnlinePlayerProfile(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,userID: freezed == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarURL: freezed == avatarURL ? _self.avatarURL : avatarURL // ignore: cast_nullable_to_non_nullable
as String?,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as KolkhozProfileStats,
  ));
}


}


/// @nodoc
mixin _$OnlineComradeProfile {

 String get userID; String? get displayName; String? get avatarURL; String? get comradeCode;@JsonKey(fromJson: _dateTimeFromEpochSeconds) DateTime? get requestedAt; bool get isOnline; bool get inGame; bool get inLobby; bool get isComrade; int? get rank;@JsonKey(fromJson: profileStatsFromJson) KolkhozProfileStats get stats;@JsonKey(fromJson: _progressionFromJson) ProgressionState get progression;
/// Create a copy of OnlineComradeProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineComradeProfileCopyWith<OnlineComradeProfile> get copyWith => _$OnlineComradeProfileCopyWithImpl<OnlineComradeProfile>(this as OnlineComradeProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineComradeProfile&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarURL, avatarURL) || other.avatarURL == avatarURL)&&(identical(other.comradeCode, comradeCode) || other.comradeCode == comradeCode)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.inGame, inGame) || other.inGame == inGame)&&(identical(other.inLobby, inLobby) || other.inLobby == inLobby)&&(identical(other.isComrade, isComrade) || other.isComrade == isComrade)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.stats, stats) || other.stats == stats)&&(identical(other.progression, progression) || other.progression == progression));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userID,displayName,avatarURL,comradeCode,requestedAt,isOnline,inGame,inLobby,isComrade,rank,stats,progression);

@override
String toString() {
  return 'OnlineComradeProfile(userID: $userID, displayName: $displayName, avatarURL: $avatarURL, comradeCode: $comradeCode, requestedAt: $requestedAt, isOnline: $isOnline, inGame: $inGame, inLobby: $inLobby, isComrade: $isComrade, rank: $rank, stats: $stats, progression: $progression)';
}


}

/// @nodoc
abstract mixin class $OnlineComradeProfileCopyWith<$Res>  {
  factory $OnlineComradeProfileCopyWith(OnlineComradeProfile value, $Res Function(OnlineComradeProfile) _then) = _$OnlineComradeProfileCopyWithImpl;
@useResult
$Res call({
 String userID, String? displayName, String? avatarURL, String? comradeCode,@JsonKey(fromJson: _dateTimeFromEpochSeconds) DateTime? requestedAt, bool isOnline, bool inGame, bool inLobby, bool isComrade, int? rank,@JsonKey(fromJson: profileStatsFromJson) KolkhozProfileStats stats,@JsonKey(fromJson: _progressionFromJson) ProgressionState progression
});




}
/// @nodoc
class _$OnlineComradeProfileCopyWithImpl<$Res>
    implements $OnlineComradeProfileCopyWith<$Res> {
  _$OnlineComradeProfileCopyWithImpl(this._self, this._then);

  final OnlineComradeProfile _self;
  final $Res Function(OnlineComradeProfile) _then;

/// Create a copy of OnlineComradeProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userID = null,Object? displayName = freezed,Object? avatarURL = freezed,Object? comradeCode = freezed,Object? requestedAt = freezed,Object? isOnline = null,Object? inGame = null,Object? inLobby = null,Object? isComrade = null,Object? rank = freezed,Object? stats = null,Object? progression = null,}) {
  return _then(_self.copyWith(
userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarURL: freezed == avatarURL ? _self.avatarURL : avatarURL // ignore: cast_nullable_to_non_nullable
as String?,comradeCode: freezed == comradeCode ? _self.comradeCode : comradeCode // ignore: cast_nullable_to_non_nullable
as String?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,inGame: null == inGame ? _self.inGame : inGame // ignore: cast_nullable_to_non_nullable
as bool,inLobby: null == inLobby ? _self.inLobby : inLobby // ignore: cast_nullable_to_non_nullable
as bool,isComrade: null == isComrade ? _self.isComrade : isComrade // ignore: cast_nullable_to_non_nullable
as bool,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as KolkhozProfileStats,progression: null == progression ? _self.progression : progression // ignore: cast_nullable_to_non_nullable
as ProgressionState,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineComradeProfile].
extension OnlineComradeProfilePatterns on OnlineComradeProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineComradeProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineComradeProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineComradeProfile value)  $default,){
final _that = this;
switch (_that) {
case _OnlineComradeProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineComradeProfile value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineComradeProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userID,  String? displayName,  String? avatarURL,  String? comradeCode, @JsonKey(fromJson: _dateTimeFromEpochSeconds)  DateTime? requestedAt,  bool isOnline,  bool inGame,  bool inLobby,  bool isComrade,  int? rank, @JsonKey(fromJson: profileStatsFromJson)  KolkhozProfileStats stats, @JsonKey(fromJson: _progressionFromJson)  ProgressionState progression)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineComradeProfile() when $default != null:
return $default(_that.userID,_that.displayName,_that.avatarURL,_that.comradeCode,_that.requestedAt,_that.isOnline,_that.inGame,_that.inLobby,_that.isComrade,_that.rank,_that.stats,_that.progression);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userID,  String? displayName,  String? avatarURL,  String? comradeCode, @JsonKey(fromJson: _dateTimeFromEpochSeconds)  DateTime? requestedAt,  bool isOnline,  bool inGame,  bool inLobby,  bool isComrade,  int? rank, @JsonKey(fromJson: profileStatsFromJson)  KolkhozProfileStats stats, @JsonKey(fromJson: _progressionFromJson)  ProgressionState progression)  $default,) {final _that = this;
switch (_that) {
case _OnlineComradeProfile():
return $default(_that.userID,_that.displayName,_that.avatarURL,_that.comradeCode,_that.requestedAt,_that.isOnline,_that.inGame,_that.inLobby,_that.isComrade,_that.rank,_that.stats,_that.progression);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userID,  String? displayName,  String? avatarURL,  String? comradeCode, @JsonKey(fromJson: _dateTimeFromEpochSeconds)  DateTime? requestedAt,  bool isOnline,  bool inGame,  bool inLobby,  bool isComrade,  int? rank, @JsonKey(fromJson: profileStatsFromJson)  KolkhozProfileStats stats, @JsonKey(fromJson: _progressionFromJson)  ProgressionState progression)?  $default,) {final _that = this;
switch (_that) {
case _OnlineComradeProfile() when $default != null:
return $default(_that.userID,_that.displayName,_that.avatarURL,_that.comradeCode,_that.requestedAt,_that.isOnline,_that.inGame,_that.inLobby,_that.isComrade,_that.rank,_that.stats,_that.progression);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineComradeProfile extends OnlineComradeProfile {
  const _OnlineComradeProfile({required this.userID, this.displayName, this.avatarURL, this.comradeCode, @JsonKey(fromJson: _dateTimeFromEpochSeconds) this.requestedAt, this.isOnline = false, this.inGame = false, this.inLobby = false, this.isComrade = false, this.rank, @JsonKey(fromJson: profileStatsFromJson) this.stats = defaultProfileStats, @JsonKey(fromJson: _progressionFromJson) this.progression = const ProgressionState()}): super._();
  factory _OnlineComradeProfile.fromJson(Map<String, dynamic> json) => _$OnlineComradeProfileFromJson(json);

@override final  String userID;
@override final  String? displayName;
@override final  String? avatarURL;
@override final  String? comradeCode;
@override@JsonKey(fromJson: _dateTimeFromEpochSeconds) final  DateTime? requestedAt;
@override@JsonKey() final  bool isOnline;
@override@JsonKey() final  bool inGame;
@override@JsonKey() final  bool inLobby;
@override@JsonKey() final  bool isComrade;
@override final  int? rank;
@override@JsonKey(fromJson: profileStatsFromJson) final  KolkhozProfileStats stats;
@override@JsonKey(fromJson: _progressionFromJson) final  ProgressionState progression;

/// Create a copy of OnlineComradeProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineComradeProfileCopyWith<_OnlineComradeProfile> get copyWith => __$OnlineComradeProfileCopyWithImpl<_OnlineComradeProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineComradeProfile&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarURL, avatarURL) || other.avatarURL == avatarURL)&&(identical(other.comradeCode, comradeCode) || other.comradeCode == comradeCode)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.inGame, inGame) || other.inGame == inGame)&&(identical(other.inLobby, inLobby) || other.inLobby == inLobby)&&(identical(other.isComrade, isComrade) || other.isComrade == isComrade)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.stats, stats) || other.stats == stats)&&(identical(other.progression, progression) || other.progression == progression));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userID,displayName,avatarURL,comradeCode,requestedAt,isOnline,inGame,inLobby,isComrade,rank,stats,progression);

@override
String toString() {
  return 'OnlineComradeProfile(userID: $userID, displayName: $displayName, avatarURL: $avatarURL, comradeCode: $comradeCode, requestedAt: $requestedAt, isOnline: $isOnline, inGame: $inGame, inLobby: $inLobby, isComrade: $isComrade, rank: $rank, stats: $stats, progression: $progression)';
}


}

/// @nodoc
abstract mixin class _$OnlineComradeProfileCopyWith<$Res> implements $OnlineComradeProfileCopyWith<$Res> {
  factory _$OnlineComradeProfileCopyWith(_OnlineComradeProfile value, $Res Function(_OnlineComradeProfile) _then) = __$OnlineComradeProfileCopyWithImpl;
@override @useResult
$Res call({
 String userID, String? displayName, String? avatarURL, String? comradeCode,@JsonKey(fromJson: _dateTimeFromEpochSeconds) DateTime? requestedAt, bool isOnline, bool inGame, bool inLobby, bool isComrade, int? rank,@JsonKey(fromJson: profileStatsFromJson) KolkhozProfileStats stats,@JsonKey(fromJson: _progressionFromJson) ProgressionState progression
});




}
/// @nodoc
class __$OnlineComradeProfileCopyWithImpl<$Res>
    implements _$OnlineComradeProfileCopyWith<$Res> {
  __$OnlineComradeProfileCopyWithImpl(this._self, this._then);

  final _OnlineComradeProfile _self;
  final $Res Function(_OnlineComradeProfile) _then;

/// Create a copy of OnlineComradeProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userID = null,Object? displayName = freezed,Object? avatarURL = freezed,Object? comradeCode = freezed,Object? requestedAt = freezed,Object? isOnline = null,Object? inGame = null,Object? inLobby = null,Object? isComrade = null,Object? rank = freezed,Object? stats = null,Object? progression = null,}) {
  return _then(_OnlineComradeProfile(
userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarURL: freezed == avatarURL ? _self.avatarURL : avatarURL // ignore: cast_nullable_to_non_nullable
as String?,comradeCode: freezed == comradeCode ? _self.comradeCode : comradeCode // ignore: cast_nullable_to_non_nullable
as String?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,inGame: null == inGame ? _self.inGame : inGame // ignore: cast_nullable_to_non_nullable
as bool,inLobby: null == inLobby ? _self.inLobby : inLobby // ignore: cast_nullable_to_non_nullable
as bool,isComrade: null == isComrade ? _self.isComrade : isComrade // ignore: cast_nullable_to_non_nullable
as bool,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as KolkhozProfileStats,progression: null == progression ? _self.progression : progression // ignore: cast_nullable_to_non_nullable
as ProgressionState,
  ));
}


}


/// @nodoc
mixin _$OnlineComradesResponse {

 String? get userID; String? get comradeCode; List<OnlineComradeProfile> get comrades; List<OnlineComradeProfile> get incomingRequests; List<OnlineComradeProfile> get outgoingRequests;
/// Create a copy of OnlineComradesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineComradesResponseCopyWith<OnlineComradesResponse> get copyWith => _$OnlineComradesResponseCopyWithImpl<OnlineComradesResponse>(this as OnlineComradesResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineComradesResponse&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.comradeCode, comradeCode) || other.comradeCode == comradeCode)&&const DeepCollectionEquality().equals(other.comrades, comrades)&&const DeepCollectionEquality().equals(other.incomingRequests, incomingRequests)&&const DeepCollectionEquality().equals(other.outgoingRequests, outgoingRequests));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userID,comradeCode,const DeepCollectionEquality().hash(comrades),const DeepCollectionEquality().hash(incomingRequests),const DeepCollectionEquality().hash(outgoingRequests));

@override
String toString() {
  return 'OnlineComradesResponse(userID: $userID, comradeCode: $comradeCode, comrades: $comrades, incomingRequests: $incomingRequests, outgoingRequests: $outgoingRequests)';
}


}

/// @nodoc
abstract mixin class $OnlineComradesResponseCopyWith<$Res>  {
  factory $OnlineComradesResponseCopyWith(OnlineComradesResponse value, $Res Function(OnlineComradesResponse) _then) = _$OnlineComradesResponseCopyWithImpl;
@useResult
$Res call({
 String? userID, String? comradeCode, List<OnlineComradeProfile> comrades, List<OnlineComradeProfile> incomingRequests, List<OnlineComradeProfile> outgoingRequests
});




}
/// @nodoc
class _$OnlineComradesResponseCopyWithImpl<$Res>
    implements $OnlineComradesResponseCopyWith<$Res> {
  _$OnlineComradesResponseCopyWithImpl(this._self, this._then);

  final OnlineComradesResponse _self;
  final $Res Function(OnlineComradesResponse) _then;

/// Create a copy of OnlineComradesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userID = freezed,Object? comradeCode = freezed,Object? comrades = null,Object? incomingRequests = null,Object? outgoingRequests = null,}) {
  return _then(_self.copyWith(
userID: freezed == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String?,comradeCode: freezed == comradeCode ? _self.comradeCode : comradeCode // ignore: cast_nullable_to_non_nullable
as String?,comrades: null == comrades ? _self.comrades : comrades // ignore: cast_nullable_to_non_nullable
as List<OnlineComradeProfile>,incomingRequests: null == incomingRequests ? _self.incomingRequests : incomingRequests // ignore: cast_nullable_to_non_nullable
as List<OnlineComradeProfile>,outgoingRequests: null == outgoingRequests ? _self.outgoingRequests : outgoingRequests // ignore: cast_nullable_to_non_nullable
as List<OnlineComradeProfile>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineComradesResponse].
extension OnlineComradesResponsePatterns on OnlineComradesResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineComradesResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineComradesResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineComradesResponse value)  $default,){
final _that = this;
switch (_that) {
case _OnlineComradesResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineComradesResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineComradesResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? userID,  String? comradeCode,  List<OnlineComradeProfile> comrades,  List<OnlineComradeProfile> incomingRequests,  List<OnlineComradeProfile> outgoingRequests)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineComradesResponse() when $default != null:
return $default(_that.userID,_that.comradeCode,_that.comrades,_that.incomingRequests,_that.outgoingRequests);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? userID,  String? comradeCode,  List<OnlineComradeProfile> comrades,  List<OnlineComradeProfile> incomingRequests,  List<OnlineComradeProfile> outgoingRequests)  $default,) {final _that = this;
switch (_that) {
case _OnlineComradesResponse():
return $default(_that.userID,_that.comradeCode,_that.comrades,_that.incomingRequests,_that.outgoingRequests);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? userID,  String? comradeCode,  List<OnlineComradeProfile> comrades,  List<OnlineComradeProfile> incomingRequests,  List<OnlineComradeProfile> outgoingRequests)?  $default,) {final _that = this;
switch (_that) {
case _OnlineComradesResponse() when $default != null:
return $default(_that.userID,_that.comradeCode,_that.comrades,_that.incomingRequests,_that.outgoingRequests);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineComradesResponse extends OnlineComradesResponse {
  const _OnlineComradesResponse({this.userID, this.comradeCode, final  List<OnlineComradeProfile> comrades = const [], final  List<OnlineComradeProfile> incomingRequests = const [], final  List<OnlineComradeProfile> outgoingRequests = const []}): _comrades = comrades,_incomingRequests = incomingRequests,_outgoingRequests = outgoingRequests,super._();
  factory _OnlineComradesResponse.fromJson(Map<String, dynamic> json) => _$OnlineComradesResponseFromJson(json);

@override final  String? userID;
@override final  String? comradeCode;
 final  List<OnlineComradeProfile> _comrades;
@override@JsonKey() List<OnlineComradeProfile> get comrades {
  if (_comrades is EqualUnmodifiableListView) return _comrades;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_comrades);
}

 final  List<OnlineComradeProfile> _incomingRequests;
@override@JsonKey() List<OnlineComradeProfile> get incomingRequests {
  if (_incomingRequests is EqualUnmodifiableListView) return _incomingRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_incomingRequests);
}

 final  List<OnlineComradeProfile> _outgoingRequests;
@override@JsonKey() List<OnlineComradeProfile> get outgoingRequests {
  if (_outgoingRequests is EqualUnmodifiableListView) return _outgoingRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_outgoingRequests);
}


/// Create a copy of OnlineComradesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineComradesResponseCopyWith<_OnlineComradesResponse> get copyWith => __$OnlineComradesResponseCopyWithImpl<_OnlineComradesResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineComradesResponse&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.comradeCode, comradeCode) || other.comradeCode == comradeCode)&&const DeepCollectionEquality().equals(other._comrades, _comrades)&&const DeepCollectionEquality().equals(other._incomingRequests, _incomingRequests)&&const DeepCollectionEquality().equals(other._outgoingRequests, _outgoingRequests));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userID,comradeCode,const DeepCollectionEquality().hash(_comrades),const DeepCollectionEquality().hash(_incomingRequests),const DeepCollectionEquality().hash(_outgoingRequests));

@override
String toString() {
  return 'OnlineComradesResponse(userID: $userID, comradeCode: $comradeCode, comrades: $comrades, incomingRequests: $incomingRequests, outgoingRequests: $outgoingRequests)';
}


}

/// @nodoc
abstract mixin class _$OnlineComradesResponseCopyWith<$Res> implements $OnlineComradesResponseCopyWith<$Res> {
  factory _$OnlineComradesResponseCopyWith(_OnlineComradesResponse value, $Res Function(_OnlineComradesResponse) _then) = __$OnlineComradesResponseCopyWithImpl;
@override @useResult
$Res call({
 String? userID, String? comradeCode, List<OnlineComradeProfile> comrades, List<OnlineComradeProfile> incomingRequests, List<OnlineComradeProfile> outgoingRequests
});




}
/// @nodoc
class __$OnlineComradesResponseCopyWithImpl<$Res>
    implements _$OnlineComradesResponseCopyWith<$Res> {
  __$OnlineComradesResponseCopyWithImpl(this._self, this._then);

  final _OnlineComradesResponse _self;
  final $Res Function(_OnlineComradesResponse) _then;

/// Create a copy of OnlineComradesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userID = freezed,Object? comradeCode = freezed,Object? comrades = null,Object? incomingRequests = null,Object? outgoingRequests = null,}) {
  return _then(_OnlineComradesResponse(
userID: freezed == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String?,comradeCode: freezed == comradeCode ? _self.comradeCode : comradeCode // ignore: cast_nullable_to_non_nullable
as String?,comrades: null == comrades ? _self._comrades : comrades // ignore: cast_nullable_to_non_nullable
as List<OnlineComradeProfile>,incomingRequests: null == incomingRequests ? _self._incomingRequests : incomingRequests // ignore: cast_nullable_to_non_nullable
as List<OnlineComradeProfile>,outgoingRequests: null == outgoingRequests ? _self._outgoingRequests : outgoingRequests // ignore: cast_nullable_to_non_nullable
as List<OnlineComradeProfile>,
  ));
}


}

// dart format on
