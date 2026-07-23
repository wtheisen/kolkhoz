// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_remote_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OnlineRecentGame {

 String get sessionID; int get playerID; int get score; int get rank; bool get won; bool get ranked; double get completedAt;
/// Create a copy of OnlineRecentGame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineRecentGameCopyWith<OnlineRecentGame> get copyWith => _$OnlineRecentGameCopyWithImpl<OnlineRecentGame>(this as OnlineRecentGame, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineRecentGame&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.score, score) || other.score == score)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.won, won) || other.won == won)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,playerID,score,rank,won,ranked,completedAt);

@override
String toString() {
  return 'OnlineRecentGame(sessionID: $sessionID, playerID: $playerID, score: $score, rank: $rank, won: $won, ranked: $ranked, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $OnlineRecentGameCopyWith<$Res>  {
  factory $OnlineRecentGameCopyWith(OnlineRecentGame value, $Res Function(OnlineRecentGame) _then) = _$OnlineRecentGameCopyWithImpl;
@useResult
$Res call({
 String sessionID, int playerID, int score, int rank, bool won, bool ranked, double completedAt
});




}
/// @nodoc
class _$OnlineRecentGameCopyWithImpl<$Res>
    implements $OnlineRecentGameCopyWith<$Res> {
  _$OnlineRecentGameCopyWithImpl(this._self, this._then);

  final OnlineRecentGame _self;
  final $Res Function(OnlineRecentGame) _then;

/// Create a copy of OnlineRecentGame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? playerID = null,Object? score = null,Object? rank = null,Object? won = null,Object? ranked = null,Object? completedAt = null,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,won: null == won ? _self.won : won // ignore: cast_nullable_to_non_nullable
as bool,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineRecentGame].
extension OnlineRecentGamePatterns on OnlineRecentGame {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineRecentGame value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineRecentGame() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineRecentGame value)  $default,){
final _that = this;
switch (_that) {
case _OnlineRecentGame():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineRecentGame value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineRecentGame() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID,  int playerID,  int score,  int rank,  bool won,  bool ranked,  double completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineRecentGame() when $default != null:
return $default(_that.sessionID,_that.playerID,_that.score,_that.rank,_that.won,_that.ranked,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID,  int playerID,  int score,  int rank,  bool won,  bool ranked,  double completedAt)  $default,) {final _that = this;
switch (_that) {
case _OnlineRecentGame():
return $default(_that.sessionID,_that.playerID,_that.score,_that.rank,_that.won,_that.ranked,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID,  int playerID,  int score,  int rank,  bool won,  bool ranked,  double completedAt)?  $default,) {final _that = this;
switch (_that) {
case _OnlineRecentGame() when $default != null:
return $default(_that.sessionID,_that.playerID,_that.score,_that.rank,_that.won,_that.ranked,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineRecentGame implements OnlineRecentGame {
  const _OnlineRecentGame({required this.sessionID, required this.playerID, required this.score, required this.rank, required this.won, required this.ranked, required this.completedAt});
  factory _OnlineRecentGame.fromJson(Map<String, dynamic> json) => _$OnlineRecentGameFromJson(json);

@override final  String sessionID;
@override final  int playerID;
@override final  int score;
@override final  int rank;
@override final  bool won;
@override final  bool ranked;
@override final  double completedAt;

/// Create a copy of OnlineRecentGame
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineRecentGameCopyWith<_OnlineRecentGame> get copyWith => __$OnlineRecentGameCopyWithImpl<_OnlineRecentGame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineRecentGame&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.score, score) || other.score == score)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.won, won) || other.won == won)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,playerID,score,rank,won,ranked,completedAt);

@override
String toString() {
  return 'OnlineRecentGame(sessionID: $sessionID, playerID: $playerID, score: $score, rank: $rank, won: $won, ranked: $ranked, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$OnlineRecentGameCopyWith<$Res> implements $OnlineRecentGameCopyWith<$Res> {
  factory _$OnlineRecentGameCopyWith(_OnlineRecentGame value, $Res Function(_OnlineRecentGame) _then) = __$OnlineRecentGameCopyWithImpl;
@override @useResult
$Res call({
 String sessionID, int playerID, int score, int rank, bool won, bool ranked, double completedAt
});




}
/// @nodoc
class __$OnlineRecentGameCopyWithImpl<$Res>
    implements _$OnlineRecentGameCopyWith<$Res> {
  __$OnlineRecentGameCopyWithImpl(this._self, this._then);

  final _OnlineRecentGame _self;
  final $Res Function(_OnlineRecentGame) _then;

/// Create a copy of OnlineRecentGame
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? playerID = null,Object? score = null,Object? rank = null,Object? won = null,Object? ranked = null,Object? completedAt = null,}) {
  return _then(_OnlineRecentGame(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,won: null == won ? _self.won : won // ignore: cast_nullable_to_non_nullable
as bool,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$OnlineReplayResult {

 int get playerID; int get score; int get rank; String get displayName;
/// Create a copy of OnlineReplayResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineReplayResultCopyWith<OnlineReplayResult> get copyWith => _$OnlineReplayResultCopyWithImpl<OnlineReplayResult>(this as OnlineReplayResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineReplayResult&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.score, score) || other.score == score)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,score,rank,displayName);

@override
String toString() {
  return 'OnlineReplayResult(playerID: $playerID, score: $score, rank: $rank, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class $OnlineReplayResultCopyWith<$Res>  {
  factory $OnlineReplayResultCopyWith(OnlineReplayResult value, $Res Function(OnlineReplayResult) _then) = _$OnlineReplayResultCopyWithImpl;
@useResult
$Res call({
 int playerID, int score, int rank, String displayName
});




}
/// @nodoc
class _$OnlineReplayResultCopyWithImpl<$Res>
    implements $OnlineReplayResultCopyWith<$Res> {
  _$OnlineReplayResultCopyWithImpl(this._self, this._then);

  final OnlineReplayResult _self;
  final $Res Function(OnlineReplayResult) _then;

/// Create a copy of OnlineReplayResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerID = null,Object? score = null,Object? rank = null,Object? displayName = null,}) {
  return _then(_self.copyWith(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineReplayResult].
extension OnlineReplayResultPatterns on OnlineReplayResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineReplayResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineReplayResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineReplayResult value)  $default,){
final _that = this;
switch (_that) {
case _OnlineReplayResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineReplayResult value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineReplayResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int playerID,  int score,  int rank,  String displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineReplayResult() when $default != null:
return $default(_that.playerID,_that.score,_that.rank,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int playerID,  int score,  int rank,  String displayName)  $default,) {final _that = this;
switch (_that) {
case _OnlineReplayResult():
return $default(_that.playerID,_that.score,_that.rank,_that.displayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int playerID,  int score,  int rank,  String displayName)?  $default,) {final _that = this;
switch (_that) {
case _OnlineReplayResult() when $default != null:
return $default(_that.playerID,_that.score,_that.rank,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineReplayResult implements OnlineReplayResult {
  const _OnlineReplayResult({required this.playerID, required this.score, required this.rank, this.displayName = 'Player'});
  factory _OnlineReplayResult.fromJson(Map<String, dynamic> json) => _$OnlineReplayResultFromJson(json);

@override final  int playerID;
@override final  int score;
@override final  int rank;
@override@JsonKey() final  String displayName;

/// Create a copy of OnlineReplayResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineReplayResultCopyWith<_OnlineReplayResult> get copyWith => __$OnlineReplayResultCopyWithImpl<_OnlineReplayResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineReplayResult&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.score, score) || other.score == score)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,score,rank,displayName);

@override
String toString() {
  return 'OnlineReplayResult(playerID: $playerID, score: $score, rank: $rank, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$OnlineReplayResultCopyWith<$Res> implements $OnlineReplayResultCopyWith<$Res> {
  factory _$OnlineReplayResultCopyWith(_OnlineReplayResult value, $Res Function(_OnlineReplayResult) _then) = __$OnlineReplayResultCopyWithImpl;
@override @useResult
$Res call({
 int playerID, int score, int rank, String displayName
});




}
/// @nodoc
class __$OnlineReplayResultCopyWithImpl<$Res>
    implements _$OnlineReplayResultCopyWith<$Res> {
  __$OnlineReplayResultCopyWithImpl(this._self, this._then);

  final _OnlineReplayResult _self;
  final $Res Function(_OnlineReplayResult) _then;

/// Create a copy of OnlineReplayResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerID = null,Object? score = null,Object? rank = null,Object? displayName = null,}) {
  return _then(_OnlineReplayResult(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$OnlineReplayEvent {

 int get revision; String get kind; OnlineEngineAction get action; double get createdAt;
/// Create a copy of OnlineReplayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineReplayEventCopyWith<OnlineReplayEvent> get copyWith => _$OnlineReplayEventCopyWithImpl<OnlineReplayEvent>(this as OnlineReplayEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineReplayEvent&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.action, action) || other.action == action)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,revision,kind,action,createdAt);

@override
String toString() {
  return 'OnlineReplayEvent(revision: $revision, kind: $kind, action: $action, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OnlineReplayEventCopyWith<$Res>  {
  factory $OnlineReplayEventCopyWith(OnlineReplayEvent value, $Res Function(OnlineReplayEvent) _then) = _$OnlineReplayEventCopyWithImpl;
@useResult
$Res call({
 int revision, String kind, OnlineEngineAction action, double createdAt
});


$OnlineEngineActionCopyWith<$Res> get action;

}
/// @nodoc
class _$OnlineReplayEventCopyWithImpl<$Res>
    implements $OnlineReplayEventCopyWith<$Res> {
  _$OnlineReplayEventCopyWithImpl(this._self, this._then);

  final OnlineReplayEvent _self;
  final $Res Function(OnlineReplayEvent) _then;

/// Create a copy of OnlineReplayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revision = null,Object? kind = null,Object? action = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as OnlineEngineAction,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of OnlineReplayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineActionCopyWith<$Res> get action {
  
  return $OnlineEngineActionCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineReplayEvent].
extension OnlineReplayEventPatterns on OnlineReplayEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineReplayEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineReplayEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineReplayEvent value)  $default,){
final _that = this;
switch (_that) {
case _OnlineReplayEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineReplayEvent value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineReplayEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int revision,  String kind,  OnlineEngineAction action,  double createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineReplayEvent() when $default != null:
return $default(_that.revision,_that.kind,_that.action,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int revision,  String kind,  OnlineEngineAction action,  double createdAt)  $default,) {final _that = this;
switch (_that) {
case _OnlineReplayEvent():
return $default(_that.revision,_that.kind,_that.action,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int revision,  String kind,  OnlineEngineAction action,  double createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OnlineReplayEvent() when $default != null:
return $default(_that.revision,_that.kind,_that.action,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineReplayEvent implements OnlineReplayEvent {
  const _OnlineReplayEvent({required this.revision, required this.kind, required this.action, required this.createdAt});
  factory _OnlineReplayEvent.fromJson(Map<String, dynamic> json) => _$OnlineReplayEventFromJson(json);

@override final  int revision;
@override final  String kind;
@override final  OnlineEngineAction action;
@override final  double createdAt;

/// Create a copy of OnlineReplayEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineReplayEventCopyWith<_OnlineReplayEvent> get copyWith => __$OnlineReplayEventCopyWithImpl<_OnlineReplayEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineReplayEvent&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.action, action) || other.action == action)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,revision,kind,action,createdAt);

@override
String toString() {
  return 'OnlineReplayEvent(revision: $revision, kind: $kind, action: $action, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OnlineReplayEventCopyWith<$Res> implements $OnlineReplayEventCopyWith<$Res> {
  factory _$OnlineReplayEventCopyWith(_OnlineReplayEvent value, $Res Function(_OnlineReplayEvent) _then) = __$OnlineReplayEventCopyWithImpl;
@override @useResult
$Res call({
 int revision, String kind, OnlineEngineAction action, double createdAt
});


@override $OnlineEngineActionCopyWith<$Res> get action;

}
/// @nodoc
class __$OnlineReplayEventCopyWithImpl<$Res>
    implements _$OnlineReplayEventCopyWith<$Res> {
  __$OnlineReplayEventCopyWithImpl(this._self, this._then);

  final _OnlineReplayEvent _self;
  final $Res Function(_OnlineReplayEvent) _then;

/// Create a copy of OnlineReplayEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revision = null,Object? kind = null,Object? action = null,Object? createdAt = null,}) {
  return _then(_OnlineReplayEvent(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as OnlineEngineAction,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of OnlineReplayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineActionCopyWith<$Res> get action {
  
  return $OnlineEngineActionCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}


/// @nodoc
mixin _$OnlineGameReplay {

 String get sessionID; int get seed;@JsonKey(fromJson: _variantsFromJson) KolkhozGameVariants get variants;@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> get controllers; bool get ranked; List<OnlineReplayResult> get results; List<OnlineReplayEvent> get events;
/// Create a copy of OnlineGameReplay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineGameReplayCopyWith<OnlineGameReplay> get copyWith => _$OnlineGameReplayCopyWithImpl<OnlineGameReplay>(this as OnlineGameReplay, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineGameReplay&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.variants, variants) || other.variants == variants)&&const DeepCollectionEquality().equals(other.controllers, controllers)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&const DeepCollectionEquality().equals(other.results, results)&&const DeepCollectionEquality().equals(other.events, events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,seed,variants,const DeepCollectionEquality().hash(controllers),ranked,const DeepCollectionEquality().hash(results),const DeepCollectionEquality().hash(events));

@override
String toString() {
  return 'OnlineGameReplay(sessionID: $sessionID, seed: $seed, variants: $variants, controllers: $controllers, ranked: $ranked, results: $results, events: $events)';
}


}

/// @nodoc
abstract mixin class $OnlineGameReplayCopyWith<$Res>  {
  factory $OnlineGameReplayCopyWith(OnlineGameReplay value, $Res Function(OnlineGameReplay) _then) = _$OnlineGameReplayCopyWithImpl;
@useResult
$Res call({
 String sessionID, int seed,@JsonKey(fromJson: _variantsFromJson) KolkhozGameVariants variants,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, bool ranked, List<OnlineReplayResult> results, List<OnlineReplayEvent> events
});




}
/// @nodoc
class _$OnlineGameReplayCopyWithImpl<$Res>
    implements $OnlineGameReplayCopyWith<$Res> {
  _$OnlineGameReplayCopyWithImpl(this._self, this._then);

  final OnlineGameReplay _self;
  final $Res Function(OnlineGameReplay) _then;

/// Create a copy of OnlineGameReplay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? seed = null,Object? variants = null,Object? controllers = null,Object? ranked = null,Object? results = null,Object? events = null,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,seed: null == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as KolkhozGameVariants,controllers: null == controllers ? _self.controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<OnlineReplayResult>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<OnlineReplayEvent>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineGameReplay].
extension OnlineGameReplayPatterns on OnlineGameReplay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineGameReplay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineGameReplay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineGameReplay value)  $default,){
final _that = this;
switch (_that) {
case _OnlineGameReplay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineGameReplay value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineGameReplay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID,  int seed, @JsonKey(fromJson: _variantsFromJson)  KolkhozGameVariants variants, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  bool ranked,  List<OnlineReplayResult> results,  List<OnlineReplayEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineGameReplay() when $default != null:
return $default(_that.sessionID,_that.seed,_that.variants,_that.controllers,_that.ranked,_that.results,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID,  int seed, @JsonKey(fromJson: _variantsFromJson)  KolkhozGameVariants variants, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  bool ranked,  List<OnlineReplayResult> results,  List<OnlineReplayEvent> events)  $default,) {final _that = this;
switch (_that) {
case _OnlineGameReplay():
return $default(_that.sessionID,_that.seed,_that.variants,_that.controllers,_that.ranked,_that.results,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID,  int seed, @JsonKey(fromJson: _variantsFromJson)  KolkhozGameVariants variants, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  bool ranked,  List<OnlineReplayResult> results,  List<OnlineReplayEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _OnlineGameReplay() when $default != null:
return $default(_that.sessionID,_that.seed,_that.variants,_that.controllers,_that.ranked,_that.results,_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineGameReplay implements OnlineGameReplay {
  const _OnlineGameReplay({required this.sessionID, required this.seed, @JsonKey(fromJson: _variantsFromJson) required this.variants, @JsonKey(fromJson: _controllersFromJson) required final  List<KolkhozPlayerController> controllers, this.ranked = false, required final  List<OnlineReplayResult> results, required final  List<OnlineReplayEvent> events}): _controllers = controllers,_results = results,_events = events;
  factory _OnlineGameReplay.fromJson(Map<String, dynamic> json) => _$OnlineGameReplayFromJson(json);

@override final  String sessionID;
@override final  int seed;
@override@JsonKey(fromJson: _variantsFromJson) final  KolkhozGameVariants variants;
 final  List<KolkhozPlayerController> _controllers;
@override@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> get controllers {
  if (_controllers is EqualUnmodifiableListView) return _controllers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_controllers);
}

@override@JsonKey() final  bool ranked;
 final  List<OnlineReplayResult> _results;
@override List<OnlineReplayResult> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}

 final  List<OnlineReplayEvent> _events;
@override List<OnlineReplayEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of OnlineGameReplay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineGameReplayCopyWith<_OnlineGameReplay> get copyWith => __$OnlineGameReplayCopyWithImpl<_OnlineGameReplay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineGameReplay&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.variants, variants) || other.variants == variants)&&const DeepCollectionEquality().equals(other._controllers, _controllers)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&const DeepCollectionEquality().equals(other._results, _results)&&const DeepCollectionEquality().equals(other._events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,seed,variants,const DeepCollectionEquality().hash(_controllers),ranked,const DeepCollectionEquality().hash(_results),const DeepCollectionEquality().hash(_events));

@override
String toString() {
  return 'OnlineGameReplay(sessionID: $sessionID, seed: $seed, variants: $variants, controllers: $controllers, ranked: $ranked, results: $results, events: $events)';
}


}

/// @nodoc
abstract mixin class _$OnlineGameReplayCopyWith<$Res> implements $OnlineGameReplayCopyWith<$Res> {
  factory _$OnlineGameReplayCopyWith(_OnlineGameReplay value, $Res Function(_OnlineGameReplay) _then) = __$OnlineGameReplayCopyWithImpl;
@override @useResult
$Res call({
 String sessionID, int seed,@JsonKey(fromJson: _variantsFromJson) KolkhozGameVariants variants,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, bool ranked, List<OnlineReplayResult> results, List<OnlineReplayEvent> events
});




}
/// @nodoc
class __$OnlineGameReplayCopyWithImpl<$Res>
    implements _$OnlineGameReplayCopyWith<$Res> {
  __$OnlineGameReplayCopyWithImpl(this._self, this._then);

  final _OnlineGameReplay _self;
  final $Res Function(_OnlineGameReplay) _then;

/// Create a copy of OnlineGameReplay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? seed = null,Object? variants = null,Object? controllers = null,Object? ranked = null,Object? results = null,Object? events = null,}) {
  return _then(_OnlineGameReplay(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,seed: null == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as KolkhozGameVariants,controllers: null == controllers ? _self._controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<OnlineReplayResult>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<OnlineReplayEvent>,
  ));
}


}


/// @nodoc
mixin _$OnlineDailyLeader {

 String get displayName; int get score;
/// Create a copy of OnlineDailyLeader
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineDailyLeaderCopyWith<OnlineDailyLeader> get copyWith => _$OnlineDailyLeaderCopyWithImpl<OnlineDailyLeader>(this as OnlineDailyLeader, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineDailyLeader&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,displayName,score);

@override
String toString() {
  return 'OnlineDailyLeader(displayName: $displayName, score: $score)';
}


}

/// @nodoc
abstract mixin class $OnlineDailyLeaderCopyWith<$Res>  {
  factory $OnlineDailyLeaderCopyWith(OnlineDailyLeader value, $Res Function(OnlineDailyLeader) _then) = _$OnlineDailyLeaderCopyWithImpl;
@useResult
$Res call({
 String displayName, int score
});




}
/// @nodoc
class _$OnlineDailyLeaderCopyWithImpl<$Res>
    implements $OnlineDailyLeaderCopyWith<$Res> {
  _$OnlineDailyLeaderCopyWithImpl(this._self, this._then);

  final OnlineDailyLeader _self;
  final $Res Function(OnlineDailyLeader) _then;

/// Create a copy of OnlineDailyLeader
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayName = null,Object? score = null,}) {
  return _then(_self.copyWith(
displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineDailyLeader].
extension OnlineDailyLeaderPatterns on OnlineDailyLeader {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineDailyLeader value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineDailyLeader() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineDailyLeader value)  $default,){
final _that = this;
switch (_that) {
case _OnlineDailyLeader():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineDailyLeader value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineDailyLeader() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String displayName,  int score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineDailyLeader() when $default != null:
return $default(_that.displayName,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String displayName,  int score)  $default,) {final _that = this;
switch (_that) {
case _OnlineDailyLeader():
return $default(_that.displayName,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String displayName,  int score)?  $default,) {final _that = this;
switch (_that) {
case _OnlineDailyLeader() when $default != null:
return $default(_that.displayName,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineDailyLeader implements OnlineDailyLeader {
  const _OnlineDailyLeader({this.displayName = 'Player', required this.score});
  factory _OnlineDailyLeader.fromJson(Map<String, dynamic> json) => _$OnlineDailyLeaderFromJson(json);

@override@JsonKey() final  String displayName;
@override final  int score;

/// Create a copy of OnlineDailyLeader
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineDailyLeaderCopyWith<_OnlineDailyLeader> get copyWith => __$OnlineDailyLeaderCopyWithImpl<_OnlineDailyLeader>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineDailyLeader&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,displayName,score);

@override
String toString() {
  return 'OnlineDailyLeader(displayName: $displayName, score: $score)';
}


}

/// @nodoc
abstract mixin class _$OnlineDailyLeaderCopyWith<$Res> implements $OnlineDailyLeaderCopyWith<$Res> {
  factory _$OnlineDailyLeaderCopyWith(_OnlineDailyLeader value, $Res Function(_OnlineDailyLeader) _then) = __$OnlineDailyLeaderCopyWithImpl;
@override @useResult
$Res call({
 String displayName, int score
});




}
/// @nodoc
class __$OnlineDailyLeaderCopyWithImpl<$Res>
    implements _$OnlineDailyLeaderCopyWith<$Res> {
  __$OnlineDailyLeaderCopyWithImpl(this._self, this._then);

  final _OnlineDailyLeader _self;
  final $Res Function(_OnlineDailyLeader) _then;

/// Create a copy of OnlineDailyLeader
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayName = null,Object? score = null,}) {
  return _then(_OnlineDailyLeader(
displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OnlineDailyChallenge {

 String get date; int get seed;@JsonKey(readValue: _bestScoreFromJson) int? get bestScore; List<OnlineDailyLeader> get leaders;
/// Create a copy of OnlineDailyChallenge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineDailyChallengeCopyWith<OnlineDailyChallenge> get copyWith => _$OnlineDailyChallengeCopyWithImpl<OnlineDailyChallenge>(this as OnlineDailyChallenge, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineDailyChallenge&&(identical(other.date, date) || other.date == date)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.bestScore, bestScore) || other.bestScore == bestScore)&&const DeepCollectionEquality().equals(other.leaders, leaders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,seed,bestScore,const DeepCollectionEquality().hash(leaders));

@override
String toString() {
  return 'OnlineDailyChallenge(date: $date, seed: $seed, bestScore: $bestScore, leaders: $leaders)';
}


}

/// @nodoc
abstract mixin class $OnlineDailyChallengeCopyWith<$Res>  {
  factory $OnlineDailyChallengeCopyWith(OnlineDailyChallenge value, $Res Function(OnlineDailyChallenge) _then) = _$OnlineDailyChallengeCopyWithImpl;
@useResult
$Res call({
 String date, int seed,@JsonKey(readValue: _bestScoreFromJson) int? bestScore, List<OnlineDailyLeader> leaders
});




}
/// @nodoc
class _$OnlineDailyChallengeCopyWithImpl<$Res>
    implements $OnlineDailyChallengeCopyWith<$Res> {
  _$OnlineDailyChallengeCopyWithImpl(this._self, this._then);

  final OnlineDailyChallenge _self;
  final $Res Function(OnlineDailyChallenge) _then;

/// Create a copy of OnlineDailyChallenge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? seed = null,Object? bestScore = freezed,Object? leaders = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,seed: null == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int,bestScore: freezed == bestScore ? _self.bestScore : bestScore // ignore: cast_nullable_to_non_nullable
as int?,leaders: null == leaders ? _self.leaders : leaders // ignore: cast_nullable_to_non_nullable
as List<OnlineDailyLeader>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineDailyChallenge].
extension OnlineDailyChallengePatterns on OnlineDailyChallenge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineDailyChallenge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineDailyChallenge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineDailyChallenge value)  $default,){
final _that = this;
switch (_that) {
case _OnlineDailyChallenge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineDailyChallenge value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineDailyChallenge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  int seed, @JsonKey(readValue: _bestScoreFromJson)  int? bestScore,  List<OnlineDailyLeader> leaders)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineDailyChallenge() when $default != null:
return $default(_that.date,_that.seed,_that.bestScore,_that.leaders);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  int seed, @JsonKey(readValue: _bestScoreFromJson)  int? bestScore,  List<OnlineDailyLeader> leaders)  $default,) {final _that = this;
switch (_that) {
case _OnlineDailyChallenge():
return $default(_that.date,_that.seed,_that.bestScore,_that.leaders);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  int seed, @JsonKey(readValue: _bestScoreFromJson)  int? bestScore,  List<OnlineDailyLeader> leaders)?  $default,) {final _that = this;
switch (_that) {
case _OnlineDailyChallenge() when $default != null:
return $default(_that.date,_that.seed,_that.bestScore,_that.leaders);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineDailyChallenge implements OnlineDailyChallenge {
  const _OnlineDailyChallenge({required this.date, required this.seed, @JsonKey(readValue: _bestScoreFromJson) this.bestScore, final  List<OnlineDailyLeader> leaders = const []}): _leaders = leaders;
  factory _OnlineDailyChallenge.fromJson(Map<String, dynamic> json) => _$OnlineDailyChallengeFromJson(json);

@override final  String date;
@override final  int seed;
@override@JsonKey(readValue: _bestScoreFromJson) final  int? bestScore;
 final  List<OnlineDailyLeader> _leaders;
@override@JsonKey() List<OnlineDailyLeader> get leaders {
  if (_leaders is EqualUnmodifiableListView) return _leaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_leaders);
}


/// Create a copy of OnlineDailyChallenge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineDailyChallengeCopyWith<_OnlineDailyChallenge> get copyWith => __$OnlineDailyChallengeCopyWithImpl<_OnlineDailyChallenge>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineDailyChallenge&&(identical(other.date, date) || other.date == date)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.bestScore, bestScore) || other.bestScore == bestScore)&&const DeepCollectionEquality().equals(other._leaders, _leaders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,seed,bestScore,const DeepCollectionEquality().hash(_leaders));

@override
String toString() {
  return 'OnlineDailyChallenge(date: $date, seed: $seed, bestScore: $bestScore, leaders: $leaders)';
}


}

/// @nodoc
abstract mixin class _$OnlineDailyChallengeCopyWith<$Res> implements $OnlineDailyChallengeCopyWith<$Res> {
  factory _$OnlineDailyChallengeCopyWith(_OnlineDailyChallenge value, $Res Function(_OnlineDailyChallenge) _then) = __$OnlineDailyChallengeCopyWithImpl;
@override @useResult
$Res call({
 String date, int seed,@JsonKey(readValue: _bestScoreFromJson) int? bestScore, List<OnlineDailyLeader> leaders
});




}
/// @nodoc
class __$OnlineDailyChallengeCopyWithImpl<$Res>
    implements _$OnlineDailyChallengeCopyWith<$Res> {
  __$OnlineDailyChallengeCopyWithImpl(this._self, this._then);

  final _OnlineDailyChallenge _self;
  final $Res Function(_OnlineDailyChallenge) _then;

/// Create a copy of OnlineDailyChallenge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? seed = null,Object? bestScore = freezed,Object? leaders = null,}) {
  return _then(_OnlineDailyChallenge(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,seed: null == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int,bestScore: freezed == bestScore ? _self.bestScore : bestScore // ignore: cast_nullable_to_non_nullable
as int?,leaders: null == leaders ? _self._leaders : leaders // ignore: cast_nullable_to_non_nullable
as List<OnlineDailyLeader>,
  ));
}


}


/// @nodoc
mixin _$OnlineTournamentStanding {

 int get rank; String get userID; String get displayName; double get points; int get wins; int get gameScore; bool get isBot; bool get forfeited;
/// Create a copy of OnlineTournamentStanding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineTournamentStandingCopyWith<OnlineTournamentStanding> get copyWith => _$OnlineTournamentStandingCopyWithImpl<OnlineTournamentStanding>(this as OnlineTournamentStanding, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineTournamentStanding&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.points, points) || other.points == points)&&(identical(other.wins, wins) || other.wins == wins)&&(identical(other.gameScore, gameScore) || other.gameScore == gameScore)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.forfeited, forfeited) || other.forfeited == forfeited));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rank,userID,displayName,points,wins,gameScore,isBot,forfeited);

@override
String toString() {
  return 'OnlineTournamentStanding(rank: $rank, userID: $userID, displayName: $displayName, points: $points, wins: $wins, gameScore: $gameScore, isBot: $isBot, forfeited: $forfeited)';
}


}

/// @nodoc
abstract mixin class $OnlineTournamentStandingCopyWith<$Res>  {
  factory $OnlineTournamentStandingCopyWith(OnlineTournamentStanding value, $Res Function(OnlineTournamentStanding) _then) = _$OnlineTournamentStandingCopyWithImpl;
@useResult
$Res call({
 int rank, String userID, String displayName, double points, int wins, int gameScore, bool isBot, bool forfeited
});




}
/// @nodoc
class _$OnlineTournamentStandingCopyWithImpl<$Res>
    implements $OnlineTournamentStandingCopyWith<$Res> {
  _$OnlineTournamentStandingCopyWithImpl(this._self, this._then);

  final OnlineTournamentStanding _self;
  final $Res Function(OnlineTournamentStanding) _then;

/// Create a copy of OnlineTournamentStanding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = null,Object? userID = null,Object? displayName = null,Object? points = null,Object? wins = null,Object? gameScore = null,Object? isBot = null,Object? forfeited = null,}) {
  return _then(_self.copyWith(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as double,wins: null == wins ? _self.wins : wins // ignore: cast_nullable_to_non_nullable
as int,gameScore: null == gameScore ? _self.gameScore : gameScore // ignore: cast_nullable_to_non_nullable
as int,isBot: null == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool,forfeited: null == forfeited ? _self.forfeited : forfeited // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineTournamentStanding].
extension OnlineTournamentStandingPatterns on OnlineTournamentStanding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineTournamentStanding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineTournamentStanding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineTournamentStanding value)  $default,){
final _that = this;
switch (_that) {
case _OnlineTournamentStanding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineTournamentStanding value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineTournamentStanding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int rank,  String userID,  String displayName,  double points,  int wins,  int gameScore,  bool isBot,  bool forfeited)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineTournamentStanding() when $default != null:
return $default(_that.rank,_that.userID,_that.displayName,_that.points,_that.wins,_that.gameScore,_that.isBot,_that.forfeited);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int rank,  String userID,  String displayName,  double points,  int wins,  int gameScore,  bool isBot,  bool forfeited)  $default,) {final _that = this;
switch (_that) {
case _OnlineTournamentStanding():
return $default(_that.rank,_that.userID,_that.displayName,_that.points,_that.wins,_that.gameScore,_that.isBot,_that.forfeited);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int rank,  String userID,  String displayName,  double points,  int wins,  int gameScore,  bool isBot,  bool forfeited)?  $default,) {final _that = this;
switch (_that) {
case _OnlineTournamentStanding() when $default != null:
return $default(_that.rank,_that.userID,_that.displayName,_that.points,_that.wins,_that.gameScore,_that.isBot,_that.forfeited);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineTournamentStanding implements OnlineTournamentStanding {
  const _OnlineTournamentStanding({required this.rank, required this.userID, this.displayName = 'Player', required this.points, this.wins = 0, this.gameScore = 0, this.isBot = false, this.forfeited = false});
  factory _OnlineTournamentStanding.fromJson(Map<String, dynamic> json) => _$OnlineTournamentStandingFromJson(json);

@override final  int rank;
@override final  String userID;
@override@JsonKey() final  String displayName;
@override final  double points;
@override@JsonKey() final  int wins;
@override@JsonKey() final  int gameScore;
@override@JsonKey() final  bool isBot;
@override@JsonKey() final  bool forfeited;

/// Create a copy of OnlineTournamentStanding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineTournamentStandingCopyWith<_OnlineTournamentStanding> get copyWith => __$OnlineTournamentStandingCopyWithImpl<_OnlineTournamentStanding>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineTournamentStanding&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.points, points) || other.points == points)&&(identical(other.wins, wins) || other.wins == wins)&&(identical(other.gameScore, gameScore) || other.gameScore == gameScore)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.forfeited, forfeited) || other.forfeited == forfeited));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rank,userID,displayName,points,wins,gameScore,isBot,forfeited);

@override
String toString() {
  return 'OnlineTournamentStanding(rank: $rank, userID: $userID, displayName: $displayName, points: $points, wins: $wins, gameScore: $gameScore, isBot: $isBot, forfeited: $forfeited)';
}


}

/// @nodoc
abstract mixin class _$OnlineTournamentStandingCopyWith<$Res> implements $OnlineTournamentStandingCopyWith<$Res> {
  factory _$OnlineTournamentStandingCopyWith(_OnlineTournamentStanding value, $Res Function(_OnlineTournamentStanding) _then) = __$OnlineTournamentStandingCopyWithImpl;
@override @useResult
$Res call({
 int rank, String userID, String displayName, double points, int wins, int gameScore, bool isBot, bool forfeited
});




}
/// @nodoc
class __$OnlineTournamentStandingCopyWithImpl<$Res>
    implements _$OnlineTournamentStandingCopyWith<$Res> {
  __$OnlineTournamentStandingCopyWithImpl(this._self, this._then);

  final _OnlineTournamentStanding _self;
  final $Res Function(_OnlineTournamentStanding) _then;

/// Create a copy of OnlineTournamentStanding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rank = null,Object? userID = null,Object? displayName = null,Object? points = null,Object? wins = null,Object? gameScore = null,Object? isBot = null,Object? forfeited = null,}) {
  return _then(_OnlineTournamentStanding(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as double,wins: null == wins ? _self.wins : wins // ignore: cast_nullable_to_non_nullable
as int,gameScore: null == gameScore ? _self.gameScore : gameScore // ignore: cast_nullable_to_non_nullable
as int,isBot: null == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool,forfeited: null == forfeited ? _self.forfeited : forfeited // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$OnlineTournamentTable {

 String get tableID; String get sessionID; int get roundNumber; int get tableNumber; String get status; int get playerID;
/// Create a copy of OnlineTournamentTable
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineTournamentTableCopyWith<OnlineTournamentTable> get copyWith => _$OnlineTournamentTableCopyWithImpl<OnlineTournamentTable>(this as OnlineTournamentTable, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineTournamentTable&&(identical(other.tableID, tableID) || other.tableID == tableID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.tableNumber, tableNumber) || other.tableNumber == tableNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.playerID, playerID) || other.playerID == playerID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tableID,sessionID,roundNumber,tableNumber,status,playerID);

@override
String toString() {
  return 'OnlineTournamentTable(tableID: $tableID, sessionID: $sessionID, roundNumber: $roundNumber, tableNumber: $tableNumber, status: $status, playerID: $playerID)';
}


}

/// @nodoc
abstract mixin class $OnlineTournamentTableCopyWith<$Res>  {
  factory $OnlineTournamentTableCopyWith(OnlineTournamentTable value, $Res Function(OnlineTournamentTable) _then) = _$OnlineTournamentTableCopyWithImpl;
@useResult
$Res call({
 String tableID, String sessionID, int roundNumber, int tableNumber, String status, int playerID
});




}
/// @nodoc
class _$OnlineTournamentTableCopyWithImpl<$Res>
    implements $OnlineTournamentTableCopyWith<$Res> {
  _$OnlineTournamentTableCopyWithImpl(this._self, this._then);

  final OnlineTournamentTable _self;
  final $Res Function(OnlineTournamentTable) _then;

/// Create a copy of OnlineTournamentTable
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tableID = null,Object? sessionID = null,Object? roundNumber = null,Object? tableNumber = null,Object? status = null,Object? playerID = null,}) {
  return _then(_self.copyWith(
tableID: null == tableID ? _self.tableID : tableID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,tableNumber: null == tableNumber ? _self.tableNumber : tableNumber // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineTournamentTable].
extension OnlineTournamentTablePatterns on OnlineTournamentTable {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineTournamentTable value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineTournamentTable() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineTournamentTable value)  $default,){
final _that = this;
switch (_that) {
case _OnlineTournamentTable():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineTournamentTable value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineTournamentTable() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tableID,  String sessionID,  int roundNumber,  int tableNumber,  String status,  int playerID)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineTournamentTable() when $default != null:
return $default(_that.tableID,_that.sessionID,_that.roundNumber,_that.tableNumber,_that.status,_that.playerID);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tableID,  String sessionID,  int roundNumber,  int tableNumber,  String status,  int playerID)  $default,) {final _that = this;
switch (_that) {
case _OnlineTournamentTable():
return $default(_that.tableID,_that.sessionID,_that.roundNumber,_that.tableNumber,_that.status,_that.playerID);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tableID,  String sessionID,  int roundNumber,  int tableNumber,  String status,  int playerID)?  $default,) {final _that = this;
switch (_that) {
case _OnlineTournamentTable() when $default != null:
return $default(_that.tableID,_that.sessionID,_that.roundNumber,_that.tableNumber,_that.status,_that.playerID);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineTournamentTable implements OnlineTournamentTable {
  const _OnlineTournamentTable({required this.tableID, required this.sessionID, required this.roundNumber, required this.tableNumber, required this.status, required this.playerID});
  factory _OnlineTournamentTable.fromJson(Map<String, dynamic> json) => _$OnlineTournamentTableFromJson(json);

@override final  String tableID;
@override final  String sessionID;
@override final  int roundNumber;
@override final  int tableNumber;
@override final  String status;
@override final  int playerID;

/// Create a copy of OnlineTournamentTable
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineTournamentTableCopyWith<_OnlineTournamentTable> get copyWith => __$OnlineTournamentTableCopyWithImpl<_OnlineTournamentTable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineTournamentTable&&(identical(other.tableID, tableID) || other.tableID == tableID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.tableNumber, tableNumber) || other.tableNumber == tableNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.playerID, playerID) || other.playerID == playerID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tableID,sessionID,roundNumber,tableNumber,status,playerID);

@override
String toString() {
  return 'OnlineTournamentTable(tableID: $tableID, sessionID: $sessionID, roundNumber: $roundNumber, tableNumber: $tableNumber, status: $status, playerID: $playerID)';
}


}

/// @nodoc
abstract mixin class _$OnlineTournamentTableCopyWith<$Res> implements $OnlineTournamentTableCopyWith<$Res> {
  factory _$OnlineTournamentTableCopyWith(_OnlineTournamentTable value, $Res Function(_OnlineTournamentTable) _then) = __$OnlineTournamentTableCopyWithImpl;
@override @useResult
$Res call({
 String tableID, String sessionID, int roundNumber, int tableNumber, String status, int playerID
});




}
/// @nodoc
class __$OnlineTournamentTableCopyWithImpl<$Res>
    implements _$OnlineTournamentTableCopyWith<$Res> {
  __$OnlineTournamentTableCopyWithImpl(this._self, this._then);

  final _OnlineTournamentTable _self;
  final $Res Function(_OnlineTournamentTable) _then;

/// Create a copy of OnlineTournamentTable
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tableID = null,Object? sessionID = null,Object? roundNumber = null,Object? tableNumber = null,Object? status = null,Object? playerID = null,}) {
  return _then(_OnlineTournamentTable(
tableID: null == tableID ? _self.tableID : tableID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,tableNumber: null == tableNumber ? _self.tableNumber : tableNumber // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OnlineWeeklyTournament {

 bool get available; String? get tournamentID; double? get startsAt; double? get joinOpensAt; double? get joinClosesAt; String get status; int get roundNumber; int get totalRounds; bool get joined; bool get forfeited; int get entrantCount; List<OnlineTournamentStanding> get standings; OnlineTournamentTable? get table;
/// Create a copy of OnlineWeeklyTournament
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineWeeklyTournamentCopyWith<OnlineWeeklyTournament> get copyWith => _$OnlineWeeklyTournamentCopyWithImpl<OnlineWeeklyTournament>(this as OnlineWeeklyTournament, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineWeeklyTournament&&(identical(other.available, available) || other.available == available)&&(identical(other.tournamentID, tournamentID) || other.tournamentID == tournamentID)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.joinOpensAt, joinOpensAt) || other.joinOpensAt == joinOpensAt)&&(identical(other.joinClosesAt, joinClosesAt) || other.joinClosesAt == joinClosesAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.totalRounds, totalRounds) || other.totalRounds == totalRounds)&&(identical(other.joined, joined) || other.joined == joined)&&(identical(other.forfeited, forfeited) || other.forfeited == forfeited)&&(identical(other.entrantCount, entrantCount) || other.entrantCount == entrantCount)&&const DeepCollectionEquality().equals(other.standings, standings)&&(identical(other.table, table) || other.table == table));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,available,tournamentID,startsAt,joinOpensAt,joinClosesAt,status,roundNumber,totalRounds,joined,forfeited,entrantCount,const DeepCollectionEquality().hash(standings),table);

@override
String toString() {
  return 'OnlineWeeklyTournament(available: $available, tournamentID: $tournamentID, startsAt: $startsAt, joinOpensAt: $joinOpensAt, joinClosesAt: $joinClosesAt, status: $status, roundNumber: $roundNumber, totalRounds: $totalRounds, joined: $joined, forfeited: $forfeited, entrantCount: $entrantCount, standings: $standings, table: $table)';
}


}

/// @nodoc
abstract mixin class $OnlineWeeklyTournamentCopyWith<$Res>  {
  factory $OnlineWeeklyTournamentCopyWith(OnlineWeeklyTournament value, $Res Function(OnlineWeeklyTournament) _then) = _$OnlineWeeklyTournamentCopyWithImpl;
@useResult
$Res call({
 bool available, String? tournamentID, double? startsAt, double? joinOpensAt, double? joinClosesAt, String status, int roundNumber, int totalRounds, bool joined, bool forfeited, int entrantCount, List<OnlineTournamentStanding> standings, OnlineTournamentTable? table
});


$OnlineTournamentTableCopyWith<$Res>? get table;

}
/// @nodoc
class _$OnlineWeeklyTournamentCopyWithImpl<$Res>
    implements $OnlineWeeklyTournamentCopyWith<$Res> {
  _$OnlineWeeklyTournamentCopyWithImpl(this._self, this._then);

  final OnlineWeeklyTournament _self;
  final $Res Function(OnlineWeeklyTournament) _then;

/// Create a copy of OnlineWeeklyTournament
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? available = null,Object? tournamentID = freezed,Object? startsAt = freezed,Object? joinOpensAt = freezed,Object? joinClosesAt = freezed,Object? status = null,Object? roundNumber = null,Object? totalRounds = null,Object? joined = null,Object? forfeited = null,Object? entrantCount = null,Object? standings = null,Object? table = freezed,}) {
  return _then(_self.copyWith(
available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,tournamentID: freezed == tournamentID ? _self.tournamentID : tournamentID // ignore: cast_nullable_to_non_nullable
as String?,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as double?,joinOpensAt: freezed == joinOpensAt ? _self.joinOpensAt : joinOpensAt // ignore: cast_nullable_to_non_nullable
as double?,joinClosesAt: freezed == joinClosesAt ? _self.joinClosesAt : joinClosesAt // ignore: cast_nullable_to_non_nullable
as double?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,totalRounds: null == totalRounds ? _self.totalRounds : totalRounds // ignore: cast_nullable_to_non_nullable
as int,joined: null == joined ? _self.joined : joined // ignore: cast_nullable_to_non_nullable
as bool,forfeited: null == forfeited ? _self.forfeited : forfeited // ignore: cast_nullable_to_non_nullable
as bool,entrantCount: null == entrantCount ? _self.entrantCount : entrantCount // ignore: cast_nullable_to_non_nullable
as int,standings: null == standings ? _self.standings : standings // ignore: cast_nullable_to_non_nullable
as List<OnlineTournamentStanding>,table: freezed == table ? _self.table : table // ignore: cast_nullable_to_non_nullable
as OnlineTournamentTable?,
  ));
}
/// Create a copy of OnlineWeeklyTournament
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineTournamentTableCopyWith<$Res>? get table {
    if (_self.table == null) {
    return null;
  }

  return $OnlineTournamentTableCopyWith<$Res>(_self.table!, (value) {
    return _then(_self.copyWith(table: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineWeeklyTournament].
extension OnlineWeeklyTournamentPatterns on OnlineWeeklyTournament {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineWeeklyTournament value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineWeeklyTournament() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineWeeklyTournament value)  $default,){
final _that = this;
switch (_that) {
case _OnlineWeeklyTournament():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineWeeklyTournament value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineWeeklyTournament() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool available,  String? tournamentID,  double? startsAt,  double? joinOpensAt,  double? joinClosesAt,  String status,  int roundNumber,  int totalRounds,  bool joined,  bool forfeited,  int entrantCount,  List<OnlineTournamentStanding> standings,  OnlineTournamentTable? table)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineWeeklyTournament() when $default != null:
return $default(_that.available,_that.tournamentID,_that.startsAt,_that.joinOpensAt,_that.joinClosesAt,_that.status,_that.roundNumber,_that.totalRounds,_that.joined,_that.forfeited,_that.entrantCount,_that.standings,_that.table);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool available,  String? tournamentID,  double? startsAt,  double? joinOpensAt,  double? joinClosesAt,  String status,  int roundNumber,  int totalRounds,  bool joined,  bool forfeited,  int entrantCount,  List<OnlineTournamentStanding> standings,  OnlineTournamentTable? table)  $default,) {final _that = this;
switch (_that) {
case _OnlineWeeklyTournament():
return $default(_that.available,_that.tournamentID,_that.startsAt,_that.joinOpensAt,_that.joinClosesAt,_that.status,_that.roundNumber,_that.totalRounds,_that.joined,_that.forfeited,_that.entrantCount,_that.standings,_that.table);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool available,  String? tournamentID,  double? startsAt,  double? joinOpensAt,  double? joinClosesAt,  String status,  int roundNumber,  int totalRounds,  bool joined,  bool forfeited,  int entrantCount,  List<OnlineTournamentStanding> standings,  OnlineTournamentTable? table)?  $default,) {final _that = this;
switch (_that) {
case _OnlineWeeklyTournament() when $default != null:
return $default(_that.available,_that.tournamentID,_that.startsAt,_that.joinOpensAt,_that.joinClosesAt,_that.status,_that.roundNumber,_that.totalRounds,_that.joined,_that.forfeited,_that.entrantCount,_that.standings,_that.table);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineWeeklyTournament extends OnlineWeeklyTournament {
  const _OnlineWeeklyTournament({required this.available, this.tournamentID, this.startsAt, this.joinOpensAt, this.joinClosesAt, this.status = 'unavailable', this.roundNumber = 0, this.totalRounds = 4, this.joined = false, this.forfeited = false, this.entrantCount = 0, final  List<OnlineTournamentStanding> standings = const [], this.table}): _standings = standings,super._();
  factory _OnlineWeeklyTournament.fromJson(Map<String, dynamic> json) => _$OnlineWeeklyTournamentFromJson(json);

@override final  bool available;
@override final  String? tournamentID;
@override final  double? startsAt;
@override final  double? joinOpensAt;
@override final  double? joinClosesAt;
@override@JsonKey() final  String status;
@override@JsonKey() final  int roundNumber;
@override@JsonKey() final  int totalRounds;
@override@JsonKey() final  bool joined;
@override@JsonKey() final  bool forfeited;
@override@JsonKey() final  int entrantCount;
 final  List<OnlineTournamentStanding> _standings;
@override@JsonKey() List<OnlineTournamentStanding> get standings {
  if (_standings is EqualUnmodifiableListView) return _standings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_standings);
}

@override final  OnlineTournamentTable? table;

/// Create a copy of OnlineWeeklyTournament
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineWeeklyTournamentCopyWith<_OnlineWeeklyTournament> get copyWith => __$OnlineWeeklyTournamentCopyWithImpl<_OnlineWeeklyTournament>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineWeeklyTournament&&(identical(other.available, available) || other.available == available)&&(identical(other.tournamentID, tournamentID) || other.tournamentID == tournamentID)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.joinOpensAt, joinOpensAt) || other.joinOpensAt == joinOpensAt)&&(identical(other.joinClosesAt, joinClosesAt) || other.joinClosesAt == joinClosesAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.roundNumber, roundNumber) || other.roundNumber == roundNumber)&&(identical(other.totalRounds, totalRounds) || other.totalRounds == totalRounds)&&(identical(other.joined, joined) || other.joined == joined)&&(identical(other.forfeited, forfeited) || other.forfeited == forfeited)&&(identical(other.entrantCount, entrantCount) || other.entrantCount == entrantCount)&&const DeepCollectionEquality().equals(other._standings, _standings)&&(identical(other.table, table) || other.table == table));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,available,tournamentID,startsAt,joinOpensAt,joinClosesAt,status,roundNumber,totalRounds,joined,forfeited,entrantCount,const DeepCollectionEquality().hash(_standings),table);

@override
String toString() {
  return 'OnlineWeeklyTournament(available: $available, tournamentID: $tournamentID, startsAt: $startsAt, joinOpensAt: $joinOpensAt, joinClosesAt: $joinClosesAt, status: $status, roundNumber: $roundNumber, totalRounds: $totalRounds, joined: $joined, forfeited: $forfeited, entrantCount: $entrantCount, standings: $standings, table: $table)';
}


}

/// @nodoc
abstract mixin class _$OnlineWeeklyTournamentCopyWith<$Res> implements $OnlineWeeklyTournamentCopyWith<$Res> {
  factory _$OnlineWeeklyTournamentCopyWith(_OnlineWeeklyTournament value, $Res Function(_OnlineWeeklyTournament) _then) = __$OnlineWeeklyTournamentCopyWithImpl;
@override @useResult
$Res call({
 bool available, String? tournamentID, double? startsAt, double? joinOpensAt, double? joinClosesAt, String status, int roundNumber, int totalRounds, bool joined, bool forfeited, int entrantCount, List<OnlineTournamentStanding> standings, OnlineTournamentTable? table
});


@override $OnlineTournamentTableCopyWith<$Res>? get table;

}
/// @nodoc
class __$OnlineWeeklyTournamentCopyWithImpl<$Res>
    implements _$OnlineWeeklyTournamentCopyWith<$Res> {
  __$OnlineWeeklyTournamentCopyWithImpl(this._self, this._then);

  final _OnlineWeeklyTournament _self;
  final $Res Function(_OnlineWeeklyTournament) _then;

/// Create a copy of OnlineWeeklyTournament
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? available = null,Object? tournamentID = freezed,Object? startsAt = freezed,Object? joinOpensAt = freezed,Object? joinClosesAt = freezed,Object? status = null,Object? roundNumber = null,Object? totalRounds = null,Object? joined = null,Object? forfeited = null,Object? entrantCount = null,Object? standings = null,Object? table = freezed,}) {
  return _then(_OnlineWeeklyTournament(
available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,tournamentID: freezed == tournamentID ? _self.tournamentID : tournamentID // ignore: cast_nullable_to_non_nullable
as String?,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as double?,joinOpensAt: freezed == joinOpensAt ? _self.joinOpensAt : joinOpensAt // ignore: cast_nullable_to_non_nullable
as double?,joinClosesAt: freezed == joinClosesAt ? _self.joinClosesAt : joinClosesAt // ignore: cast_nullable_to_non_nullable
as double?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,roundNumber: null == roundNumber ? _self.roundNumber : roundNumber // ignore: cast_nullable_to_non_nullable
as int,totalRounds: null == totalRounds ? _self.totalRounds : totalRounds // ignore: cast_nullable_to_non_nullable
as int,joined: null == joined ? _self.joined : joined // ignore: cast_nullable_to_non_nullable
as bool,forfeited: null == forfeited ? _self.forfeited : forfeited // ignore: cast_nullable_to_non_nullable
as bool,entrantCount: null == entrantCount ? _self.entrantCount : entrantCount // ignore: cast_nullable_to_non_nullable
as int,standings: null == standings ? _self._standings : standings // ignore: cast_nullable_to_non_nullable
as List<OnlineTournamentStanding>,table: freezed == table ? _self.table : table // ignore: cast_nullable_to_non_nullable
as OnlineTournamentTable?,
  ));
}

/// Create a copy of OnlineWeeklyTournament
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineTournamentTableCopyWith<$Res>? get table {
    if (_self.table == null) {
    return null;
  }

  return $OnlineTournamentTableCopyWith<$Res>(_self.table!, (value) {
    return _then(_self.copyWith(table: value));
  });
}
}


/// @nodoc
mixin _$OnlineSessionListing {

 String get sessionID; String? get inviteCode; List<int> get openSeats; List<int> get occupiedSeats;@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> get controllers; List<OnlinePlayerProfile> get playerProfiles; bool get ranked; bool get browserJoinable; List<OnlineSeatPresence> get seatPresence; int? get turnPlayerID; double? get turnDeadlineAt; bool get started; double? get lobbyCountdownEndsAt; int get actionLogCount; double get createdAt; double get expiresAt;
/// Create a copy of OnlineSessionListing
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSessionListingCopyWith<OnlineSessionListing> get copyWith => _$OnlineSessionListingCopyWithImpl<OnlineSessionListing>(this as OnlineSessionListing, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSessionListing&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&const DeepCollectionEquality().equals(other.openSeats, openSeats)&&const DeepCollectionEquality().equals(other.occupiedSeats, occupiedSeats)&&const DeepCollectionEquality().equals(other.controllers, controllers)&&const DeepCollectionEquality().equals(other.playerProfiles, playerProfiles)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.browserJoinable, browserJoinable) || other.browserJoinable == browserJoinable)&&const DeepCollectionEquality().equals(other.seatPresence, seatPresence)&&(identical(other.turnPlayerID, turnPlayerID) || other.turnPlayerID == turnPlayerID)&&(identical(other.turnDeadlineAt, turnDeadlineAt) || other.turnDeadlineAt == turnDeadlineAt)&&(identical(other.started, started) || other.started == started)&&(identical(other.lobbyCountdownEndsAt, lobbyCountdownEndsAt) || other.lobbyCountdownEndsAt == lobbyCountdownEndsAt)&&(identical(other.actionLogCount, actionLogCount) || other.actionLogCount == actionLogCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,inviteCode,const DeepCollectionEquality().hash(openSeats),const DeepCollectionEquality().hash(occupiedSeats),const DeepCollectionEquality().hash(controllers),const DeepCollectionEquality().hash(playerProfiles),ranked,browserJoinable,const DeepCollectionEquality().hash(seatPresence),turnPlayerID,turnDeadlineAt,started,lobbyCountdownEndsAt,actionLogCount,createdAt,expiresAt);

@override
String toString() {
  return 'OnlineSessionListing(sessionID: $sessionID, inviteCode: $inviteCode, openSeats: $openSeats, occupiedSeats: $occupiedSeats, controllers: $controllers, playerProfiles: $playerProfiles, ranked: $ranked, browserJoinable: $browserJoinable, seatPresence: $seatPresence, turnPlayerID: $turnPlayerID, turnDeadlineAt: $turnDeadlineAt, started: $started, lobbyCountdownEndsAt: $lobbyCountdownEndsAt, actionLogCount: $actionLogCount, createdAt: $createdAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $OnlineSessionListingCopyWith<$Res>  {
  factory $OnlineSessionListingCopyWith(OnlineSessionListing value, $Res Function(OnlineSessionListing) _then) = _$OnlineSessionListingCopyWithImpl;
@useResult
$Res call({
 String sessionID, String? inviteCode, List<int> openSeats, List<int> occupiedSeats,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, List<OnlinePlayerProfile> playerProfiles, bool ranked, bool browserJoinable, List<OnlineSeatPresence> seatPresence, int? turnPlayerID, double? turnDeadlineAt, bool started, double? lobbyCountdownEndsAt, int actionLogCount, double createdAt, double expiresAt
});




}
/// @nodoc
class _$OnlineSessionListingCopyWithImpl<$Res>
    implements $OnlineSessionListingCopyWith<$Res> {
  _$OnlineSessionListingCopyWithImpl(this._self, this._then);

  final OnlineSessionListing _self;
  final $Res Function(OnlineSessionListing) _then;

/// Create a copy of OnlineSessionListing
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? inviteCode = freezed,Object? openSeats = null,Object? occupiedSeats = null,Object? controllers = null,Object? playerProfiles = null,Object? ranked = null,Object? browserJoinable = null,Object? seatPresence = null,Object? turnPlayerID = freezed,Object? turnDeadlineAt = freezed,Object? started = null,Object? lobbyCountdownEndsAt = freezed,Object? actionLogCount = null,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,inviteCode: freezed == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String?,openSeats: null == openSeats ? _self.openSeats : openSeats // ignore: cast_nullable_to_non_nullable
as List<int>,occupiedSeats: null == occupiedSeats ? _self.occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as List<int>,controllers: null == controllers ? _self.controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,playerProfiles: null == playerProfiles ? _self.playerProfiles : playerProfiles // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerProfile>,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,browserJoinable: null == browserJoinable ? _self.browserJoinable : browserJoinable // ignore: cast_nullable_to_non_nullable
as bool,seatPresence: null == seatPresence ? _self.seatPresence : seatPresence // ignore: cast_nullable_to_non_nullable
as List<OnlineSeatPresence>,turnPlayerID: freezed == turnPlayerID ? _self.turnPlayerID : turnPlayerID // ignore: cast_nullable_to_non_nullable
as int?,turnDeadlineAt: freezed == turnDeadlineAt ? _self.turnDeadlineAt : turnDeadlineAt // ignore: cast_nullable_to_non_nullable
as double?,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,lobbyCountdownEndsAt: freezed == lobbyCountdownEndsAt ? _self.lobbyCountdownEndsAt : lobbyCountdownEndsAt // ignore: cast_nullable_to_non_nullable
as double?,actionLogCount: null == actionLogCount ? _self.actionLogCount : actionLogCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineSessionListing].
extension OnlineSessionListingPatterns on OnlineSessionListing {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSessionListing value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSessionListing() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSessionListing value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionListing():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSessionListing value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionListing() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID,  String? inviteCode,  List<int> openSeats,  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  bool ranked,  bool browserJoinable,  List<OnlineSeatPresence> seatPresence,  int? turnPlayerID,  double? turnDeadlineAt,  bool started,  double? lobbyCountdownEndsAt,  int actionLogCount,  double createdAt,  double expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSessionListing() when $default != null:
return $default(_that.sessionID,_that.inviteCode,_that.openSeats,_that.occupiedSeats,_that.controllers,_that.playerProfiles,_that.ranked,_that.browserJoinable,_that.seatPresence,_that.turnPlayerID,_that.turnDeadlineAt,_that.started,_that.lobbyCountdownEndsAt,_that.actionLogCount,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID,  String? inviteCode,  List<int> openSeats,  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  bool ranked,  bool browserJoinable,  List<OnlineSeatPresence> seatPresence,  int? turnPlayerID,  double? turnDeadlineAt,  bool started,  double? lobbyCountdownEndsAt,  int actionLogCount,  double createdAt,  double expiresAt)  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionListing():
return $default(_that.sessionID,_that.inviteCode,_that.openSeats,_that.occupiedSeats,_that.controllers,_that.playerProfiles,_that.ranked,_that.browserJoinable,_that.seatPresence,_that.turnPlayerID,_that.turnDeadlineAt,_that.started,_that.lobbyCountdownEndsAt,_that.actionLogCount,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID,  String? inviteCode,  List<int> openSeats,  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  bool ranked,  bool browserJoinable,  List<OnlineSeatPresence> seatPresence,  int? turnPlayerID,  double? turnDeadlineAt,  bool started,  double? lobbyCountdownEndsAt,  int actionLogCount,  double createdAt,  double expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionListing() when $default != null:
return $default(_that.sessionID,_that.inviteCode,_that.openSeats,_that.occupiedSeats,_that.controllers,_that.playerProfiles,_that.ranked,_that.browserJoinable,_that.seatPresence,_that.turnPlayerID,_that.turnDeadlineAt,_that.started,_that.lobbyCountdownEndsAt,_that.actionLogCount,_that.createdAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSessionListing extends OnlineSessionListing {
  const _OnlineSessionListing({required this.sessionID, this.inviteCode, required final  List<int> openSeats, required final  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson) required final  List<KolkhozPlayerController> controllers, final  List<OnlinePlayerProfile> playerProfiles = const [], this.ranked = true, this.browserJoinable = true, final  List<OnlineSeatPresence> seatPresence = const [], this.turnPlayerID, this.turnDeadlineAt, this.started = true, this.lobbyCountdownEndsAt, required this.actionLogCount, required this.createdAt, this.expiresAt = 0.0}): _openSeats = openSeats,_occupiedSeats = occupiedSeats,_controllers = controllers,_playerProfiles = playerProfiles,_seatPresence = seatPresence,super._();
  factory _OnlineSessionListing.fromJson(Map<String, dynamic> json) => _$OnlineSessionListingFromJson(json);

@override final  String sessionID;
@override final  String? inviteCode;
 final  List<int> _openSeats;
@override List<int> get openSeats {
  if (_openSeats is EqualUnmodifiableListView) return _openSeats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_openSeats);
}

 final  List<int> _occupiedSeats;
@override List<int> get occupiedSeats {
  if (_occupiedSeats is EqualUnmodifiableListView) return _occupiedSeats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_occupiedSeats);
}

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
@override final  int actionLogCount;
@override final  double createdAt;
@override@JsonKey() final  double expiresAt;

/// Create a copy of OnlineSessionListing
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSessionListingCopyWith<_OnlineSessionListing> get copyWith => __$OnlineSessionListingCopyWithImpl<_OnlineSessionListing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSessionListing&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&const DeepCollectionEquality().equals(other._openSeats, _openSeats)&&const DeepCollectionEquality().equals(other._occupiedSeats, _occupiedSeats)&&const DeepCollectionEquality().equals(other._controllers, _controllers)&&const DeepCollectionEquality().equals(other._playerProfiles, _playerProfiles)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.browserJoinable, browserJoinable) || other.browserJoinable == browserJoinable)&&const DeepCollectionEquality().equals(other._seatPresence, _seatPresence)&&(identical(other.turnPlayerID, turnPlayerID) || other.turnPlayerID == turnPlayerID)&&(identical(other.turnDeadlineAt, turnDeadlineAt) || other.turnDeadlineAt == turnDeadlineAt)&&(identical(other.started, started) || other.started == started)&&(identical(other.lobbyCountdownEndsAt, lobbyCountdownEndsAt) || other.lobbyCountdownEndsAt == lobbyCountdownEndsAt)&&(identical(other.actionLogCount, actionLogCount) || other.actionLogCount == actionLogCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,inviteCode,const DeepCollectionEquality().hash(_openSeats),const DeepCollectionEquality().hash(_occupiedSeats),const DeepCollectionEquality().hash(_controllers),const DeepCollectionEquality().hash(_playerProfiles),ranked,browserJoinable,const DeepCollectionEquality().hash(_seatPresence),turnPlayerID,turnDeadlineAt,started,lobbyCountdownEndsAt,actionLogCount,createdAt,expiresAt);

@override
String toString() {
  return 'OnlineSessionListing(sessionID: $sessionID, inviteCode: $inviteCode, openSeats: $openSeats, occupiedSeats: $occupiedSeats, controllers: $controllers, playerProfiles: $playerProfiles, ranked: $ranked, browserJoinable: $browserJoinable, seatPresence: $seatPresence, turnPlayerID: $turnPlayerID, turnDeadlineAt: $turnDeadlineAt, started: $started, lobbyCountdownEndsAt: $lobbyCountdownEndsAt, actionLogCount: $actionLogCount, createdAt: $createdAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$OnlineSessionListingCopyWith<$Res> implements $OnlineSessionListingCopyWith<$Res> {
  factory _$OnlineSessionListingCopyWith(_OnlineSessionListing value, $Res Function(_OnlineSessionListing) _then) = __$OnlineSessionListingCopyWithImpl;
@override @useResult
$Res call({
 String sessionID, String? inviteCode, List<int> openSeats, List<int> occupiedSeats,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, List<OnlinePlayerProfile> playerProfiles, bool ranked, bool browserJoinable, List<OnlineSeatPresence> seatPresence, int? turnPlayerID, double? turnDeadlineAt, bool started, double? lobbyCountdownEndsAt, int actionLogCount, double createdAt, double expiresAt
});




}
/// @nodoc
class __$OnlineSessionListingCopyWithImpl<$Res>
    implements _$OnlineSessionListingCopyWith<$Res> {
  __$OnlineSessionListingCopyWithImpl(this._self, this._then);

  final _OnlineSessionListing _self;
  final $Res Function(_OnlineSessionListing) _then;

/// Create a copy of OnlineSessionListing
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? inviteCode = freezed,Object? openSeats = null,Object? occupiedSeats = null,Object? controllers = null,Object? playerProfiles = null,Object? ranked = null,Object? browserJoinable = null,Object? seatPresence = null,Object? turnPlayerID = freezed,Object? turnDeadlineAt = freezed,Object? started = null,Object? lobbyCountdownEndsAt = freezed,Object? actionLogCount = null,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(_OnlineSessionListing(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,inviteCode: freezed == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String?,openSeats: null == openSeats ? _self._openSeats : openSeats // ignore: cast_nullable_to_non_nullable
as List<int>,occupiedSeats: null == occupiedSeats ? _self._occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as List<int>,controllers: null == controllers ? _self._controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,playerProfiles: null == playerProfiles ? _self._playerProfiles : playerProfiles // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerProfile>,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,browserJoinable: null == browserJoinable ? _self.browserJoinable : browserJoinable // ignore: cast_nullable_to_non_nullable
as bool,seatPresence: null == seatPresence ? _self._seatPresence : seatPresence // ignore: cast_nullable_to_non_nullable
as List<OnlineSeatPresence>,turnPlayerID: freezed == turnPlayerID ? _self.turnPlayerID : turnPlayerID // ignore: cast_nullable_to_non_nullable
as int?,turnDeadlineAt: freezed == turnDeadlineAt ? _self.turnDeadlineAt : turnDeadlineAt // ignore: cast_nullable_to_non_nullable
as double?,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,lobbyCountdownEndsAt: freezed == lobbyCountdownEndsAt ? _self.lobbyCountdownEndsAt : lobbyCountdownEndsAt // ignore: cast_nullable_to_non_nullable
as double?,actionLogCount: null == actionLogCount ? _self.actionLogCount : actionLogCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$OnlineSessionInvite {

 String get sessionID; List<int> get openSeats; List<int> get occupiedSeats;@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> get controllers; List<OnlinePlayerProfile> get playerProfiles; OnlinePlayerProfile? get hostProfile; bool get ranked; bool get browserJoinable; bool get started; double? get lobbyCountdownEndsAt; double get createdAt; double get expiresAt;
/// Create a copy of OnlineSessionInvite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSessionInviteCopyWith<OnlineSessionInvite> get copyWith => _$OnlineSessionInviteCopyWithImpl<OnlineSessionInvite>(this as OnlineSessionInvite, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSessionInvite&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other.openSeats, openSeats)&&const DeepCollectionEquality().equals(other.occupiedSeats, occupiedSeats)&&const DeepCollectionEquality().equals(other.controllers, controllers)&&const DeepCollectionEquality().equals(other.playerProfiles, playerProfiles)&&(identical(other.hostProfile, hostProfile) || other.hostProfile == hostProfile)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.browserJoinable, browserJoinable) || other.browserJoinable == browserJoinable)&&(identical(other.started, started) || other.started == started)&&(identical(other.lobbyCountdownEndsAt, lobbyCountdownEndsAt) || other.lobbyCountdownEndsAt == lobbyCountdownEndsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,const DeepCollectionEquality().hash(openSeats),const DeepCollectionEquality().hash(occupiedSeats),const DeepCollectionEquality().hash(controllers),const DeepCollectionEquality().hash(playerProfiles),hostProfile,ranked,browserJoinable,started,lobbyCountdownEndsAt,createdAt,expiresAt);

@override
String toString() {
  return 'OnlineSessionInvite(sessionID: $sessionID, openSeats: $openSeats, occupiedSeats: $occupiedSeats, controllers: $controllers, playerProfiles: $playerProfiles, hostProfile: $hostProfile, ranked: $ranked, browserJoinable: $browserJoinable, started: $started, lobbyCountdownEndsAt: $lobbyCountdownEndsAt, createdAt: $createdAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $OnlineSessionInviteCopyWith<$Res>  {
  factory $OnlineSessionInviteCopyWith(OnlineSessionInvite value, $Res Function(OnlineSessionInvite) _then) = _$OnlineSessionInviteCopyWithImpl;
@useResult
$Res call({
 String sessionID, List<int> openSeats, List<int> occupiedSeats,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, List<OnlinePlayerProfile> playerProfiles, OnlinePlayerProfile? hostProfile, bool ranked, bool browserJoinable, bool started, double? lobbyCountdownEndsAt, double createdAt, double expiresAt
});


$OnlinePlayerProfileCopyWith<$Res>? get hostProfile;

}
/// @nodoc
class _$OnlineSessionInviteCopyWithImpl<$Res>
    implements $OnlineSessionInviteCopyWith<$Res> {
  _$OnlineSessionInviteCopyWithImpl(this._self, this._then);

  final OnlineSessionInvite _self;
  final $Res Function(OnlineSessionInvite) _then;

/// Create a copy of OnlineSessionInvite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionID = null,Object? openSeats = null,Object? occupiedSeats = null,Object? controllers = null,Object? playerProfiles = null,Object? hostProfile = freezed,Object? ranked = null,Object? browserJoinable = null,Object? started = null,Object? lobbyCountdownEndsAt = freezed,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,openSeats: null == openSeats ? _self.openSeats : openSeats // ignore: cast_nullable_to_non_nullable
as List<int>,occupiedSeats: null == occupiedSeats ? _self.occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as List<int>,controllers: null == controllers ? _self.controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,playerProfiles: null == playerProfiles ? _self.playerProfiles : playerProfiles // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerProfile>,hostProfile: freezed == hostProfile ? _self.hostProfile : hostProfile // ignore: cast_nullable_to_non_nullable
as OnlinePlayerProfile?,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,browserJoinable: null == browserJoinable ? _self.browserJoinable : browserJoinable // ignore: cast_nullable_to_non_nullable
as bool,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,lobbyCountdownEndsAt: freezed == lobbyCountdownEndsAt ? _self.lobbyCountdownEndsAt : lobbyCountdownEndsAt // ignore: cast_nullable_to_non_nullable
as double?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of OnlineSessionInvite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlinePlayerProfileCopyWith<$Res>? get hostProfile {
    if (_self.hostProfile == null) {
    return null;
  }

  return $OnlinePlayerProfileCopyWith<$Res>(_self.hostProfile!, (value) {
    return _then(_self.copyWith(hostProfile: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineSessionInvite].
extension OnlineSessionInvitePatterns on OnlineSessionInvite {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSessionInvite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSessionInvite() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSessionInvite value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionInvite():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSessionInvite value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSessionInvite() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionID,  List<int> openSeats,  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  OnlinePlayerProfile? hostProfile,  bool ranked,  bool browserJoinable,  bool started,  double? lobbyCountdownEndsAt,  double createdAt,  double expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSessionInvite() when $default != null:
return $default(_that.sessionID,_that.openSeats,_that.occupiedSeats,_that.controllers,_that.playerProfiles,_that.hostProfile,_that.ranked,_that.browserJoinable,_that.started,_that.lobbyCountdownEndsAt,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionID,  List<int> openSeats,  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  OnlinePlayerProfile? hostProfile,  bool ranked,  bool browserJoinable,  bool started,  double? lobbyCountdownEndsAt,  double createdAt,  double expiresAt)  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionInvite():
return $default(_that.sessionID,_that.openSeats,_that.occupiedSeats,_that.controllers,_that.playerProfiles,_that.hostProfile,_that.ranked,_that.browserJoinable,_that.started,_that.lobbyCountdownEndsAt,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionID,  List<int> openSeats,  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson)  List<KolkhozPlayerController> controllers,  List<OnlinePlayerProfile> playerProfiles,  OnlinePlayerProfile? hostProfile,  bool ranked,  bool browserJoinable,  bool started,  double? lobbyCountdownEndsAt,  double createdAt,  double expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSessionInvite() when $default != null:
return $default(_that.sessionID,_that.openSeats,_that.occupiedSeats,_that.controllers,_that.playerProfiles,_that.hostProfile,_that.ranked,_that.browserJoinable,_that.started,_that.lobbyCountdownEndsAt,_that.createdAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSessionInvite extends OnlineSessionInvite {
  const _OnlineSessionInvite({required this.sessionID, required final  List<int> openSeats, required final  List<int> occupiedSeats, @JsonKey(fromJson: _controllersFromJson) required final  List<KolkhozPlayerController> controllers, final  List<OnlinePlayerProfile> playerProfiles = const [], this.hostProfile, this.ranked = false, this.browserJoinable = false, this.started = false, this.lobbyCountdownEndsAt, required this.createdAt, this.expiresAt = 0.0}): _openSeats = openSeats,_occupiedSeats = occupiedSeats,_controllers = controllers,_playerProfiles = playerProfiles,super._();
  factory _OnlineSessionInvite.fromJson(Map<String, dynamic> json) => _$OnlineSessionInviteFromJson(json);

@override final  String sessionID;
 final  List<int> _openSeats;
@override List<int> get openSeats {
  if (_openSeats is EqualUnmodifiableListView) return _openSeats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_openSeats);
}

 final  List<int> _occupiedSeats;
@override List<int> get occupiedSeats {
  if (_occupiedSeats is EqualUnmodifiableListView) return _occupiedSeats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_occupiedSeats);
}

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

@override final  OnlinePlayerProfile? hostProfile;
@override@JsonKey() final  bool ranked;
@override@JsonKey() final  bool browserJoinable;
@override@JsonKey() final  bool started;
@override final  double? lobbyCountdownEndsAt;
@override final  double createdAt;
@override@JsonKey() final  double expiresAt;

/// Create a copy of OnlineSessionInvite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSessionInviteCopyWith<_OnlineSessionInvite> get copyWith => __$OnlineSessionInviteCopyWithImpl<_OnlineSessionInvite>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSessionInvite&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._openSeats, _openSeats)&&const DeepCollectionEquality().equals(other._occupiedSeats, _occupiedSeats)&&const DeepCollectionEquality().equals(other._controllers, _controllers)&&const DeepCollectionEquality().equals(other._playerProfiles, _playerProfiles)&&(identical(other.hostProfile, hostProfile) || other.hostProfile == hostProfile)&&(identical(other.ranked, ranked) || other.ranked == ranked)&&(identical(other.browserJoinable, browserJoinable) || other.browserJoinable == browserJoinable)&&(identical(other.started, started) || other.started == started)&&(identical(other.lobbyCountdownEndsAt, lobbyCountdownEndsAt) || other.lobbyCountdownEndsAt == lobbyCountdownEndsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,const DeepCollectionEquality().hash(_openSeats),const DeepCollectionEquality().hash(_occupiedSeats),const DeepCollectionEquality().hash(_controllers),const DeepCollectionEquality().hash(_playerProfiles),hostProfile,ranked,browserJoinable,started,lobbyCountdownEndsAt,createdAt,expiresAt);

@override
String toString() {
  return 'OnlineSessionInvite(sessionID: $sessionID, openSeats: $openSeats, occupiedSeats: $occupiedSeats, controllers: $controllers, playerProfiles: $playerProfiles, hostProfile: $hostProfile, ranked: $ranked, browserJoinable: $browserJoinable, started: $started, lobbyCountdownEndsAt: $lobbyCountdownEndsAt, createdAt: $createdAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$OnlineSessionInviteCopyWith<$Res> implements $OnlineSessionInviteCopyWith<$Res> {
  factory _$OnlineSessionInviteCopyWith(_OnlineSessionInvite value, $Res Function(_OnlineSessionInvite) _then) = __$OnlineSessionInviteCopyWithImpl;
@override @useResult
$Res call({
 String sessionID, List<int> openSeats, List<int> occupiedSeats,@JsonKey(fromJson: _controllersFromJson) List<KolkhozPlayerController> controllers, List<OnlinePlayerProfile> playerProfiles, OnlinePlayerProfile? hostProfile, bool ranked, bool browserJoinable, bool started, double? lobbyCountdownEndsAt, double createdAt, double expiresAt
});


@override $OnlinePlayerProfileCopyWith<$Res>? get hostProfile;

}
/// @nodoc
class __$OnlineSessionInviteCopyWithImpl<$Res>
    implements _$OnlineSessionInviteCopyWith<$Res> {
  __$OnlineSessionInviteCopyWithImpl(this._self, this._then);

  final _OnlineSessionInvite _self;
  final $Res Function(_OnlineSessionInvite) _then;

/// Create a copy of OnlineSessionInvite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? openSeats = null,Object? occupiedSeats = null,Object? controllers = null,Object? playerProfiles = null,Object? hostProfile = freezed,Object? ranked = null,Object? browserJoinable = null,Object? started = null,Object? lobbyCountdownEndsAt = freezed,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(_OnlineSessionInvite(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,openSeats: null == openSeats ? _self._openSeats : openSeats // ignore: cast_nullable_to_non_nullable
as List<int>,occupiedSeats: null == occupiedSeats ? _self._occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as List<int>,controllers: null == controllers ? _self._controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<KolkhozPlayerController>,playerProfiles: null == playerProfiles ? _self._playerProfiles : playerProfiles // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerProfile>,hostProfile: freezed == hostProfile ? _self.hostProfile : hostProfile // ignore: cast_nullable_to_non_nullable
as OnlinePlayerProfile?,ranked: null == ranked ? _self.ranked : ranked // ignore: cast_nullable_to_non_nullable
as bool,browserJoinable: null == browserJoinable ? _self.browserJoinable : browserJoinable // ignore: cast_nullable_to_non_nullable
as bool,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,lobbyCountdownEndsAt: freezed == lobbyCountdownEndsAt ? _self.lobbyCountdownEndsAt : lobbyCountdownEndsAt // ignore: cast_nullable_to_non_nullable
as double?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as double,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of OnlineSessionInvite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlinePlayerProfileCopyWith<$Res>? get hostProfile {
    if (_self.hostProfile == null) {
    return null;
  }

  return $OnlinePlayerProfileCopyWith<$Res>(_self.hostProfile!, (value) {
    return _then(_self.copyWith(hostProfile: value));
  });
}
}


/// @nodoc
mixin _$OnlineServerStatus {

@JsonKey(readValue: _citizensOnlineFromJson) int get citizensOnline;
/// Create a copy of OnlineServerStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineServerStatusCopyWith<OnlineServerStatus> get copyWith => _$OnlineServerStatusCopyWithImpl<OnlineServerStatus>(this as OnlineServerStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineServerStatus&&(identical(other.citizensOnline, citizensOnline) || other.citizensOnline == citizensOnline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,citizensOnline);

@override
String toString() {
  return 'OnlineServerStatus(citizensOnline: $citizensOnline)';
}


}

/// @nodoc
abstract mixin class $OnlineServerStatusCopyWith<$Res>  {
  factory $OnlineServerStatusCopyWith(OnlineServerStatus value, $Res Function(OnlineServerStatus) _then) = _$OnlineServerStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(readValue: _citizensOnlineFromJson) int citizensOnline
});




}
/// @nodoc
class _$OnlineServerStatusCopyWithImpl<$Res>
    implements $OnlineServerStatusCopyWith<$Res> {
  _$OnlineServerStatusCopyWithImpl(this._self, this._then);

  final OnlineServerStatus _self;
  final $Res Function(OnlineServerStatus) _then;

/// Create a copy of OnlineServerStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? citizensOnline = null,}) {
  return _then(_self.copyWith(
citizensOnline: null == citizensOnline ? _self.citizensOnline : citizensOnline // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineServerStatus].
extension OnlineServerStatusPatterns on OnlineServerStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineServerStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineServerStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineServerStatus value)  $default,){
final _that = this;
switch (_that) {
case _OnlineServerStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineServerStatus value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineServerStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(readValue: _citizensOnlineFromJson)  int citizensOnline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineServerStatus() when $default != null:
return $default(_that.citizensOnline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(readValue: _citizensOnlineFromJson)  int citizensOnline)  $default,) {final _that = this;
switch (_that) {
case _OnlineServerStatus():
return $default(_that.citizensOnline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(readValue: _citizensOnlineFromJson)  int citizensOnline)?  $default,) {final _that = this;
switch (_that) {
case _OnlineServerStatus() when $default != null:
return $default(_that.citizensOnline);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineServerStatus implements OnlineServerStatus {
  const _OnlineServerStatus({@JsonKey(readValue: _citizensOnlineFromJson) required this.citizensOnline});
  factory _OnlineServerStatus.fromJson(Map<String, dynamic> json) => _$OnlineServerStatusFromJson(json);

@override@JsonKey(readValue: _citizensOnlineFromJson) final  int citizensOnline;

/// Create a copy of OnlineServerStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineServerStatusCopyWith<_OnlineServerStatus> get copyWith => __$OnlineServerStatusCopyWithImpl<_OnlineServerStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineServerStatus&&(identical(other.citizensOnline, citizensOnline) || other.citizensOnline == citizensOnline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,citizensOnline);

@override
String toString() {
  return 'OnlineServerStatus(citizensOnline: $citizensOnline)';
}


}

/// @nodoc
abstract mixin class _$OnlineServerStatusCopyWith<$Res> implements $OnlineServerStatusCopyWith<$Res> {
  factory _$OnlineServerStatusCopyWith(_OnlineServerStatus value, $Res Function(_OnlineServerStatus) _then) = __$OnlineServerStatusCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(readValue: _citizensOnlineFromJson) int citizensOnline
});




}
/// @nodoc
class __$OnlineServerStatusCopyWithImpl<$Res>
    implements _$OnlineServerStatusCopyWith<$Res> {
  __$OnlineServerStatusCopyWithImpl(this._self, this._then);

  final _OnlineServerStatus _self;
  final $Res Function(_OnlineServerStatus) _then;

/// Create a copy of OnlineServerStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? citizensOnline = null,}) {
  return _then(_OnlineServerStatus(
citizensOnline: null == citizensOnline ? _self.citizensOnline : citizensOnline // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
