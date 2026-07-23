// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_state_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OnlineEngineCard {

 int get suit; int get value; int? get assignmentRound;
/// Create a copy of OnlineEngineCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<OnlineEngineCard> get copyWith => _$OnlineEngineCardCopyWithImpl<OnlineEngineCard>(this as OnlineEngineCard, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineEngineCard&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.value, value) || other.value == value)&&(identical(other.assignmentRound, assignmentRound) || other.assignmentRound == assignmentRound));
}


@override
int get hashCode => Object.hash(runtimeType,suit,value,assignmentRound);

@override
String toString() {
  return 'OnlineEngineCard(suit: $suit, value: $value, assignmentRound: $assignmentRound)';
}


}

/// @nodoc
abstract mixin class $OnlineEngineCardCopyWith<$Res>  {
  factory $OnlineEngineCardCopyWith(OnlineEngineCard value, $Res Function(OnlineEngineCard) _then) = _$OnlineEngineCardCopyWithImpl;
@useResult
$Res call({
 int suit, int value, int? assignmentRound
});




}
/// @nodoc
class _$OnlineEngineCardCopyWithImpl<$Res>
    implements $OnlineEngineCardCopyWith<$Res> {
  _$OnlineEngineCardCopyWithImpl(this._self, this._then);

  final OnlineEngineCard _self;
  final $Res Function(OnlineEngineCard) _then;

/// Create a copy of OnlineEngineCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? suit = null,Object? value = null,Object? assignmentRound = freezed,}) {
  return _then(_self.copyWith(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,assignmentRound: freezed == assignmentRound ? _self.assignmentRound : assignmentRound // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineEngineCard].
extension OnlineEngineCardPatterns on OnlineEngineCard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineEngineCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineEngineCard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineEngineCard value)  $default,){
final _that = this;
switch (_that) {
case _OnlineEngineCard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineEngineCard value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineEngineCard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int suit,  int value,  int? assignmentRound)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineEngineCard() when $default != null:
return $default(_that.suit,_that.value,_that.assignmentRound);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int suit,  int value,  int? assignmentRound)  $default,) {final _that = this;
switch (_that) {
case _OnlineEngineCard():
return $default(_that.suit,_that.value,_that.assignmentRound);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int suit,  int value,  int? assignmentRound)?  $default,) {final _that = this;
switch (_that) {
case _OnlineEngineCard() when $default != null:
return $default(_that.suit,_that.value,_that.assignmentRound);case _:
  return null;

}
}

}

/// @nodoc


class _OnlineEngineCard extends OnlineEngineCard {
  const _OnlineEngineCard({required this.suit, required this.value, this.assignmentRound}): super._();
  

@override final  int suit;
@override final  int value;
@override final  int? assignmentRound;

/// Create a copy of OnlineEngineCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineEngineCardCopyWith<_OnlineEngineCard> get copyWith => __$OnlineEngineCardCopyWithImpl<_OnlineEngineCard>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineEngineCard&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.value, value) || other.value == value)&&(identical(other.assignmentRound, assignmentRound) || other.assignmentRound == assignmentRound));
}


@override
int get hashCode => Object.hash(runtimeType,suit,value,assignmentRound);

@override
String toString() {
  return 'OnlineEngineCard(suit: $suit, value: $value, assignmentRound: $assignmentRound)';
}


}

/// @nodoc
abstract mixin class _$OnlineEngineCardCopyWith<$Res> implements $OnlineEngineCardCopyWith<$Res> {
  factory _$OnlineEngineCardCopyWith(_OnlineEngineCard value, $Res Function(_OnlineEngineCard) _then) = __$OnlineEngineCardCopyWithImpl;
@override @useResult
$Res call({
 int suit, int value, int? assignmentRound
});




}
/// @nodoc
class __$OnlineEngineCardCopyWithImpl<$Res>
    implements _$OnlineEngineCardCopyWith<$Res> {
  __$OnlineEngineCardCopyWithImpl(this._self, this._then);

  final _OnlineEngineCard _self;
  final $Res Function(_OnlineEngineCard) _then;

/// Create a copy of OnlineEngineCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? suit = null,Object? value = null,Object? assignmentRound = freezed,}) {
  return _then(_OnlineEngineCard(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,assignmentRound: freezed == assignmentRound ? _self.assignmentRound : assignmentRound // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$OnlineEngineAction {

 int get kind; int get playerID; int get suit; OnlineEngineCard get card; OnlineEngineCard get handCard; OnlineEngineCard get plotCard; int get plotZone; int get targetSuit;
/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineEngineActionCopyWith<OnlineEngineAction> get copyWith => _$OnlineEngineActionCopyWithImpl<OnlineEngineAction>(this as OnlineEngineAction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineEngineAction&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.card, card) || other.card == card)&&(identical(other.handCard, handCard) || other.handCard == handCard)&&(identical(other.plotCard, plotCard) || other.plotCard == plotCard)&&(identical(other.plotZone, plotZone) || other.plotZone == plotZone)&&(identical(other.targetSuit, targetSuit) || other.targetSuit == targetSuit));
}


@override
int get hashCode => Object.hash(runtimeType,kind,playerID,suit,card,handCard,plotCard,plotZone,targetSuit);

@override
String toString() {
  return 'OnlineEngineAction(kind: $kind, playerID: $playerID, suit: $suit, card: $card, handCard: $handCard, plotCard: $plotCard, plotZone: $plotZone, targetSuit: $targetSuit)';
}


}

/// @nodoc
abstract mixin class $OnlineEngineActionCopyWith<$Res>  {
  factory $OnlineEngineActionCopyWith(OnlineEngineAction value, $Res Function(OnlineEngineAction) _then) = _$OnlineEngineActionCopyWithImpl;
@useResult
$Res call({
 int kind, int playerID, int suit, OnlineEngineCard card, OnlineEngineCard handCard, OnlineEngineCard plotCard, int plotZone, int targetSuit
});


$OnlineEngineCardCopyWith<$Res> get card;$OnlineEngineCardCopyWith<$Res> get handCard;$OnlineEngineCardCopyWith<$Res> get plotCard;

}
/// @nodoc
class _$OnlineEngineActionCopyWithImpl<$Res>
    implements $OnlineEngineActionCopyWith<$Res> {
  _$OnlineEngineActionCopyWithImpl(this._self, this._then);

  final OnlineEngineAction _self;
  final $Res Function(OnlineEngineAction) _then;

/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? playerID = null,Object? suit = null,Object? card = null,Object? handCard = null,Object? plotCard = null,Object? plotZone = null,Object? targetSuit = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as int,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,handCard: null == handCard ? _self.handCard : handCard // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,plotCard: null == plotCard ? _self.plotCard : plotCard // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,plotZone: null == plotZone ? _self.plotZone : plotZone // ignore: cast_nullable_to_non_nullable
as int,targetSuit: null == targetSuit ? _self.targetSuit : targetSuit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get handCard {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.handCard, (value) {
    return _then(_self.copyWith(handCard: value));
  });
}/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get plotCard {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.plotCard, (value) {
    return _then(_self.copyWith(plotCard: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineEngineAction].
extension OnlineEngineActionPatterns on OnlineEngineAction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineEngineAction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineEngineAction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineEngineAction value)  $default,){
final _that = this;
switch (_that) {
case _OnlineEngineAction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineEngineAction value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineEngineAction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int kind,  int playerID,  int suit,  OnlineEngineCard card,  OnlineEngineCard handCard,  OnlineEngineCard plotCard,  int plotZone,  int targetSuit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineEngineAction() when $default != null:
return $default(_that.kind,_that.playerID,_that.suit,_that.card,_that.handCard,_that.plotCard,_that.plotZone,_that.targetSuit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int kind,  int playerID,  int suit,  OnlineEngineCard card,  OnlineEngineCard handCard,  OnlineEngineCard plotCard,  int plotZone,  int targetSuit)  $default,) {final _that = this;
switch (_that) {
case _OnlineEngineAction():
return $default(_that.kind,_that.playerID,_that.suit,_that.card,_that.handCard,_that.plotCard,_that.plotZone,_that.targetSuit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int kind,  int playerID,  int suit,  OnlineEngineCard card,  OnlineEngineCard handCard,  OnlineEngineCard plotCard,  int plotZone,  int targetSuit)?  $default,) {final _that = this;
switch (_that) {
case _OnlineEngineAction() when $default != null:
return $default(_that.kind,_that.playerID,_that.suit,_that.card,_that.handCard,_that.plotCard,_that.plotZone,_that.targetSuit);case _:
  return null;

}
}

}

/// @nodoc


class _OnlineEngineAction extends OnlineEngineAction {
  const _OnlineEngineAction({required this.kind, required this.playerID, this.suit = -1, this.card = const OnlineEngineCard(suit: -1, value: 0), this.handCard = const OnlineEngineCard(suit: -1, value: 0), this.plotCard = const OnlineEngineCard(suit: -1, value: 0), this.plotZone = -1, this.targetSuit = -1}): super._();
  

@override final  int kind;
@override final  int playerID;
@override@JsonKey() final  int suit;
@override@JsonKey() final  OnlineEngineCard card;
@override@JsonKey() final  OnlineEngineCard handCard;
@override@JsonKey() final  OnlineEngineCard plotCard;
@override@JsonKey() final  int plotZone;
@override@JsonKey() final  int targetSuit;

/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineEngineActionCopyWith<_OnlineEngineAction> get copyWith => __$OnlineEngineActionCopyWithImpl<_OnlineEngineAction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineEngineAction&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.card, card) || other.card == card)&&(identical(other.handCard, handCard) || other.handCard == handCard)&&(identical(other.plotCard, plotCard) || other.plotCard == plotCard)&&(identical(other.plotZone, plotZone) || other.plotZone == plotZone)&&(identical(other.targetSuit, targetSuit) || other.targetSuit == targetSuit));
}


@override
int get hashCode => Object.hash(runtimeType,kind,playerID,suit,card,handCard,plotCard,plotZone,targetSuit);

@override
String toString() {
  return 'OnlineEngineAction(kind: $kind, playerID: $playerID, suit: $suit, card: $card, handCard: $handCard, plotCard: $plotCard, plotZone: $plotZone, targetSuit: $targetSuit)';
}


}

/// @nodoc
abstract mixin class _$OnlineEngineActionCopyWith<$Res> implements $OnlineEngineActionCopyWith<$Res> {
  factory _$OnlineEngineActionCopyWith(_OnlineEngineAction value, $Res Function(_OnlineEngineAction) _then) = __$OnlineEngineActionCopyWithImpl;
@override @useResult
$Res call({
 int kind, int playerID, int suit, OnlineEngineCard card, OnlineEngineCard handCard, OnlineEngineCard plotCard, int plotZone, int targetSuit
});


@override $OnlineEngineCardCopyWith<$Res> get card;@override $OnlineEngineCardCopyWith<$Res> get handCard;@override $OnlineEngineCardCopyWith<$Res> get plotCard;

}
/// @nodoc
class __$OnlineEngineActionCopyWithImpl<$Res>
    implements _$OnlineEngineActionCopyWith<$Res> {
  __$OnlineEngineActionCopyWithImpl(this._self, this._then);

  final _OnlineEngineAction _self;
  final $Res Function(_OnlineEngineAction) _then;

/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? playerID = null,Object? suit = null,Object? card = null,Object? handCard = null,Object? plotCard = null,Object? plotZone = null,Object? targetSuit = null,}) {
  return _then(_OnlineEngineAction(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as int,playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,handCard: null == handCard ? _self.handCard : handCard // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,plotCard: null == plotCard ? _self.plotCard : plotCard // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,plotZone: null == plotZone ? _self.plotZone : plotZone // ignore: cast_nullable_to_non_nullable
as int,targetSuit: null == targetSuit ? _self.targetSuit : targetSuit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get handCard {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.handCard, (value) {
    return _then(_self.copyWith(handCard: value));
  });
}/// Create a copy of OnlineEngineAction
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get plotCard {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.plotCard, (value) {
    return _then(_self.copyWith(plotCard: value));
  });
}
}


/// @nodoc
mixin _$OnlinePlayerSnapshot {

 int get id; List<OnlineEngineCard> get hand; List<OnlineEngineCard> get revealedPlot; List<OnlineEngineCard> get hiddenPlot;@JsonKey(readValue: _hiddenPlotCountFromJson) int? get hiddenPlotCount; int get medals; int get bankedMedals; bool get brigadeLeader; bool get wonTrickThisYear; List<OnlinePlotStackSnapshot> get stacks;
/// Create a copy of OnlinePlayerSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlinePlayerSnapshotCopyWith<OnlinePlayerSnapshot> get copyWith => _$OnlinePlayerSnapshotCopyWithImpl<OnlinePlayerSnapshot>(this as OnlinePlayerSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlinePlayerSnapshot&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.hand, hand)&&const DeepCollectionEquality().equals(other.revealedPlot, revealedPlot)&&const DeepCollectionEquality().equals(other.hiddenPlot, hiddenPlot)&&(identical(other.hiddenPlotCount, hiddenPlotCount) || other.hiddenPlotCount == hiddenPlotCount)&&(identical(other.medals, medals) || other.medals == medals)&&(identical(other.bankedMedals, bankedMedals) || other.bankedMedals == bankedMedals)&&(identical(other.brigadeLeader, brigadeLeader) || other.brigadeLeader == brigadeLeader)&&(identical(other.wonTrickThisYear, wonTrickThisYear) || other.wonTrickThisYear == wonTrickThisYear)&&const DeepCollectionEquality().equals(other.stacks, stacks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(hand),const DeepCollectionEquality().hash(revealedPlot),const DeepCollectionEquality().hash(hiddenPlot),hiddenPlotCount,medals,bankedMedals,brigadeLeader,wonTrickThisYear,const DeepCollectionEquality().hash(stacks));

@override
String toString() {
  return 'OnlinePlayerSnapshot(id: $id, hand: $hand, revealedPlot: $revealedPlot, hiddenPlot: $hiddenPlot, hiddenPlotCount: $hiddenPlotCount, medals: $medals, bankedMedals: $bankedMedals, brigadeLeader: $brigadeLeader, wonTrickThisYear: $wonTrickThisYear, stacks: $stacks)';
}


}

/// @nodoc
abstract mixin class $OnlinePlayerSnapshotCopyWith<$Res>  {
  factory $OnlinePlayerSnapshotCopyWith(OnlinePlayerSnapshot value, $Res Function(OnlinePlayerSnapshot) _then) = _$OnlinePlayerSnapshotCopyWithImpl;
@useResult
$Res call({
 int id, List<OnlineEngineCard> hand, List<OnlineEngineCard> revealedPlot, List<OnlineEngineCard> hiddenPlot,@JsonKey(readValue: _hiddenPlotCountFromJson) int? hiddenPlotCount, int medals, int bankedMedals, bool brigadeLeader, bool wonTrickThisYear, List<OnlinePlotStackSnapshot> stacks
});




}
/// @nodoc
class _$OnlinePlayerSnapshotCopyWithImpl<$Res>
    implements $OnlinePlayerSnapshotCopyWith<$Res> {
  _$OnlinePlayerSnapshotCopyWithImpl(this._self, this._then);

  final OnlinePlayerSnapshot _self;
  final $Res Function(OnlinePlayerSnapshot) _then;

/// Create a copy of OnlinePlayerSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? hand = null,Object? revealedPlot = null,Object? hiddenPlot = null,Object? hiddenPlotCount = freezed,Object? medals = null,Object? bankedMedals = null,Object? brigadeLeader = null,Object? wonTrickThisYear = null,Object? stacks = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,hand: null == hand ? _self.hand : hand // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,revealedPlot: null == revealedPlot ? _self.revealedPlot : revealedPlot // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hiddenPlot: null == hiddenPlot ? _self.hiddenPlot : hiddenPlot // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hiddenPlotCount: freezed == hiddenPlotCount ? _self.hiddenPlotCount : hiddenPlotCount // ignore: cast_nullable_to_non_nullable
as int?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as int,bankedMedals: null == bankedMedals ? _self.bankedMedals : bankedMedals // ignore: cast_nullable_to_non_nullable
as int,brigadeLeader: null == brigadeLeader ? _self.brigadeLeader : brigadeLeader // ignore: cast_nullable_to_non_nullable
as bool,wonTrickThisYear: null == wonTrickThisYear ? _self.wonTrickThisYear : wonTrickThisYear // ignore: cast_nullable_to_non_nullable
as bool,stacks: null == stacks ? _self.stacks : stacks // ignore: cast_nullable_to_non_nullable
as List<OnlinePlotStackSnapshot>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlinePlayerSnapshot].
extension OnlinePlayerSnapshotPatterns on OnlinePlayerSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlinePlayerSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlinePlayerSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlinePlayerSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlinePlayerSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlinePlayerSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlinePlayerSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  List<OnlineEngineCard> hand,  List<OnlineEngineCard> revealedPlot,  List<OnlineEngineCard> hiddenPlot, @JsonKey(readValue: _hiddenPlotCountFromJson)  int? hiddenPlotCount,  int medals,  int bankedMedals,  bool brigadeLeader,  bool wonTrickThisYear,  List<OnlinePlotStackSnapshot> stacks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlinePlayerSnapshot() when $default != null:
return $default(_that.id,_that.hand,_that.revealedPlot,_that.hiddenPlot,_that.hiddenPlotCount,_that.medals,_that.bankedMedals,_that.brigadeLeader,_that.wonTrickThisYear,_that.stacks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  List<OnlineEngineCard> hand,  List<OnlineEngineCard> revealedPlot,  List<OnlineEngineCard> hiddenPlot, @JsonKey(readValue: _hiddenPlotCountFromJson)  int? hiddenPlotCount,  int medals,  int bankedMedals,  bool brigadeLeader,  bool wonTrickThisYear,  List<OnlinePlotStackSnapshot> stacks)  $default,) {final _that = this;
switch (_that) {
case _OnlinePlayerSnapshot():
return $default(_that.id,_that.hand,_that.revealedPlot,_that.hiddenPlot,_that.hiddenPlotCount,_that.medals,_that.bankedMedals,_that.brigadeLeader,_that.wonTrickThisYear,_that.stacks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  List<OnlineEngineCard> hand,  List<OnlineEngineCard> revealedPlot,  List<OnlineEngineCard> hiddenPlot, @JsonKey(readValue: _hiddenPlotCountFromJson)  int? hiddenPlotCount,  int medals,  int bankedMedals,  bool brigadeLeader,  bool wonTrickThisYear,  List<OnlinePlotStackSnapshot> stacks)?  $default,) {final _that = this;
switch (_that) {
case _OnlinePlayerSnapshot() when $default != null:
return $default(_that.id,_that.hand,_that.revealedPlot,_that.hiddenPlot,_that.hiddenPlotCount,_that.medals,_that.bankedMedals,_that.brigadeLeader,_that.wonTrickThisYear,_that.stacks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlinePlayerSnapshot extends OnlinePlayerSnapshot {
  const _OnlinePlayerSnapshot({required this.id, required final  List<OnlineEngineCard> hand, required final  List<OnlineEngineCard> revealedPlot, required final  List<OnlineEngineCard> hiddenPlot, @JsonKey(readValue: _hiddenPlotCountFromJson) this.hiddenPlotCount, required this.medals, required this.bankedMedals, required this.brigadeLeader, required this.wonTrickThisYear, required final  List<OnlinePlotStackSnapshot> stacks}): _hand = hand,_revealedPlot = revealedPlot,_hiddenPlot = hiddenPlot,_stacks = stacks,super._();
  factory _OnlinePlayerSnapshot.fromJson(Map<String, dynamic> json) => _$OnlinePlayerSnapshotFromJson(json);

@override final  int id;
 final  List<OnlineEngineCard> _hand;
@override List<OnlineEngineCard> get hand {
  if (_hand is EqualUnmodifiableListView) return _hand;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hand);
}

 final  List<OnlineEngineCard> _revealedPlot;
@override List<OnlineEngineCard> get revealedPlot {
  if (_revealedPlot is EqualUnmodifiableListView) return _revealedPlot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revealedPlot);
}

 final  List<OnlineEngineCard> _hiddenPlot;
@override List<OnlineEngineCard> get hiddenPlot {
  if (_hiddenPlot is EqualUnmodifiableListView) return _hiddenPlot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hiddenPlot);
}

@override@JsonKey(readValue: _hiddenPlotCountFromJson) final  int? hiddenPlotCount;
@override final  int medals;
@override final  int bankedMedals;
@override final  bool brigadeLeader;
@override final  bool wonTrickThisYear;
 final  List<OnlinePlotStackSnapshot> _stacks;
@override List<OnlinePlotStackSnapshot> get stacks {
  if (_stacks is EqualUnmodifiableListView) return _stacks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stacks);
}


/// Create a copy of OnlinePlayerSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlinePlayerSnapshotCopyWith<_OnlinePlayerSnapshot> get copyWith => __$OnlinePlayerSnapshotCopyWithImpl<_OnlinePlayerSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlinePlayerSnapshot&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._hand, _hand)&&const DeepCollectionEquality().equals(other._revealedPlot, _revealedPlot)&&const DeepCollectionEquality().equals(other._hiddenPlot, _hiddenPlot)&&(identical(other.hiddenPlotCount, hiddenPlotCount) || other.hiddenPlotCount == hiddenPlotCount)&&(identical(other.medals, medals) || other.medals == medals)&&(identical(other.bankedMedals, bankedMedals) || other.bankedMedals == bankedMedals)&&(identical(other.brigadeLeader, brigadeLeader) || other.brigadeLeader == brigadeLeader)&&(identical(other.wonTrickThisYear, wonTrickThisYear) || other.wonTrickThisYear == wonTrickThisYear)&&const DeepCollectionEquality().equals(other._stacks, _stacks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_hand),const DeepCollectionEquality().hash(_revealedPlot),const DeepCollectionEquality().hash(_hiddenPlot),hiddenPlotCount,medals,bankedMedals,brigadeLeader,wonTrickThisYear,const DeepCollectionEquality().hash(_stacks));

@override
String toString() {
  return 'OnlinePlayerSnapshot(id: $id, hand: $hand, revealedPlot: $revealedPlot, hiddenPlot: $hiddenPlot, hiddenPlotCount: $hiddenPlotCount, medals: $medals, bankedMedals: $bankedMedals, brigadeLeader: $brigadeLeader, wonTrickThisYear: $wonTrickThisYear, stacks: $stacks)';
}


}

/// @nodoc
abstract mixin class _$OnlinePlayerSnapshotCopyWith<$Res> implements $OnlinePlayerSnapshotCopyWith<$Res> {
  factory _$OnlinePlayerSnapshotCopyWith(_OnlinePlayerSnapshot value, $Res Function(_OnlinePlayerSnapshot) _then) = __$OnlinePlayerSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int id, List<OnlineEngineCard> hand, List<OnlineEngineCard> revealedPlot, List<OnlineEngineCard> hiddenPlot,@JsonKey(readValue: _hiddenPlotCountFromJson) int? hiddenPlotCount, int medals, int bankedMedals, bool brigadeLeader, bool wonTrickThisYear, List<OnlinePlotStackSnapshot> stacks
});




}
/// @nodoc
class __$OnlinePlayerSnapshotCopyWithImpl<$Res>
    implements _$OnlinePlayerSnapshotCopyWith<$Res> {
  __$OnlinePlayerSnapshotCopyWithImpl(this._self, this._then);

  final _OnlinePlayerSnapshot _self;
  final $Res Function(_OnlinePlayerSnapshot) _then;

/// Create a copy of OnlinePlayerSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hand = null,Object? revealedPlot = null,Object? hiddenPlot = null,Object? hiddenPlotCount = freezed,Object? medals = null,Object? bankedMedals = null,Object? brigadeLeader = null,Object? wonTrickThisYear = null,Object? stacks = null,}) {
  return _then(_OnlinePlayerSnapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,hand: null == hand ? _self._hand : hand // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,revealedPlot: null == revealedPlot ? _self._revealedPlot : revealedPlot // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hiddenPlot: null == hiddenPlot ? _self._hiddenPlot : hiddenPlot // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hiddenPlotCount: freezed == hiddenPlotCount ? _self.hiddenPlotCount : hiddenPlotCount // ignore: cast_nullable_to_non_nullable
as int?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as int,bankedMedals: null == bankedMedals ? _self.bankedMedals : bankedMedals // ignore: cast_nullable_to_non_nullable
as int,brigadeLeader: null == brigadeLeader ? _self.brigadeLeader : brigadeLeader // ignore: cast_nullable_to_non_nullable
as bool,wonTrickThisYear: null == wonTrickThisYear ? _self.wonTrickThisYear : wonTrickThisYear // ignore: cast_nullable_to_non_nullable
as bool,stacks: null == stacks ? _self._stacks : stacks // ignore: cast_nullable_to_non_nullable
as List<OnlinePlotStackSnapshot>,
  ));
}


}


/// @nodoc
mixin _$OnlinePlotStackSnapshot {

 List<OnlineEngineCard> get revealed; List<OnlineEngineCard> get hidden;@JsonKey(readValue: _hiddenCountFromJson) int? get hiddenCount;
/// Create a copy of OnlinePlotStackSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlinePlotStackSnapshotCopyWith<OnlinePlotStackSnapshot> get copyWith => _$OnlinePlotStackSnapshotCopyWithImpl<OnlinePlotStackSnapshot>(this as OnlinePlotStackSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlinePlotStackSnapshot&&const DeepCollectionEquality().equals(other.revealed, revealed)&&const DeepCollectionEquality().equals(other.hidden, hidden)&&(identical(other.hiddenCount, hiddenCount) || other.hiddenCount == hiddenCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(revealed),const DeepCollectionEquality().hash(hidden),hiddenCount);

@override
String toString() {
  return 'OnlinePlotStackSnapshot(revealed: $revealed, hidden: $hidden, hiddenCount: $hiddenCount)';
}


}

/// @nodoc
abstract mixin class $OnlinePlotStackSnapshotCopyWith<$Res>  {
  factory $OnlinePlotStackSnapshotCopyWith(OnlinePlotStackSnapshot value, $Res Function(OnlinePlotStackSnapshot) _then) = _$OnlinePlotStackSnapshotCopyWithImpl;
@useResult
$Res call({
 List<OnlineEngineCard> revealed, List<OnlineEngineCard> hidden,@JsonKey(readValue: _hiddenCountFromJson) int? hiddenCount
});




}
/// @nodoc
class _$OnlinePlotStackSnapshotCopyWithImpl<$Res>
    implements $OnlinePlotStackSnapshotCopyWith<$Res> {
  _$OnlinePlotStackSnapshotCopyWithImpl(this._self, this._then);

  final OnlinePlotStackSnapshot _self;
  final $Res Function(OnlinePlotStackSnapshot) _then;

/// Create a copy of OnlinePlotStackSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revealed = null,Object? hidden = null,Object? hiddenCount = freezed,}) {
  return _then(_self.copyWith(
revealed: null == revealed ? _self.revealed : revealed // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hiddenCount: freezed == hiddenCount ? _self.hiddenCount : hiddenCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlinePlotStackSnapshot].
extension OnlinePlotStackSnapshotPatterns on OnlinePlotStackSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlinePlotStackSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlinePlotStackSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlinePlotStackSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlinePlotStackSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlinePlotStackSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlinePlotStackSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<OnlineEngineCard> revealed,  List<OnlineEngineCard> hidden, @JsonKey(readValue: _hiddenCountFromJson)  int? hiddenCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlinePlotStackSnapshot() when $default != null:
return $default(_that.revealed,_that.hidden,_that.hiddenCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<OnlineEngineCard> revealed,  List<OnlineEngineCard> hidden, @JsonKey(readValue: _hiddenCountFromJson)  int? hiddenCount)  $default,) {final _that = this;
switch (_that) {
case _OnlinePlotStackSnapshot():
return $default(_that.revealed,_that.hidden,_that.hiddenCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<OnlineEngineCard> revealed,  List<OnlineEngineCard> hidden, @JsonKey(readValue: _hiddenCountFromJson)  int? hiddenCount)?  $default,) {final _that = this;
switch (_that) {
case _OnlinePlotStackSnapshot() when $default != null:
return $default(_that.revealed,_that.hidden,_that.hiddenCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlinePlotStackSnapshot extends OnlinePlotStackSnapshot {
  const _OnlinePlotStackSnapshot({required final  List<OnlineEngineCard> revealed, required final  List<OnlineEngineCard> hidden, @JsonKey(readValue: _hiddenCountFromJson) this.hiddenCount}): _revealed = revealed,_hidden = hidden,super._();
  factory _OnlinePlotStackSnapshot.fromJson(Map<String, dynamic> json) => _$OnlinePlotStackSnapshotFromJson(json);

 final  List<OnlineEngineCard> _revealed;
@override List<OnlineEngineCard> get revealed {
  if (_revealed is EqualUnmodifiableListView) return _revealed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revealed);
}

 final  List<OnlineEngineCard> _hidden;
@override List<OnlineEngineCard> get hidden {
  if (_hidden is EqualUnmodifiableListView) return _hidden;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hidden);
}

@override@JsonKey(readValue: _hiddenCountFromJson) final  int? hiddenCount;

/// Create a copy of OnlinePlotStackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlinePlotStackSnapshotCopyWith<_OnlinePlotStackSnapshot> get copyWith => __$OnlinePlotStackSnapshotCopyWithImpl<_OnlinePlotStackSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlinePlotStackSnapshot&&const DeepCollectionEquality().equals(other._revealed, _revealed)&&const DeepCollectionEquality().equals(other._hidden, _hidden)&&(identical(other.hiddenCount, hiddenCount) || other.hiddenCount == hiddenCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_revealed),const DeepCollectionEquality().hash(_hidden),hiddenCount);

@override
String toString() {
  return 'OnlinePlotStackSnapshot(revealed: $revealed, hidden: $hidden, hiddenCount: $hiddenCount)';
}


}

/// @nodoc
abstract mixin class _$OnlinePlotStackSnapshotCopyWith<$Res> implements $OnlinePlotStackSnapshotCopyWith<$Res> {
  factory _$OnlinePlotStackSnapshotCopyWith(_OnlinePlotStackSnapshot value, $Res Function(_OnlinePlotStackSnapshot) _then) = __$OnlinePlotStackSnapshotCopyWithImpl;
@override @useResult
$Res call({
 List<OnlineEngineCard> revealed, List<OnlineEngineCard> hidden,@JsonKey(readValue: _hiddenCountFromJson) int? hiddenCount
});




}
/// @nodoc
class __$OnlinePlotStackSnapshotCopyWithImpl<$Res>
    implements _$OnlinePlotStackSnapshotCopyWith<$Res> {
  __$OnlinePlotStackSnapshotCopyWithImpl(this._self, this._then);

  final _OnlinePlotStackSnapshot _self;
  final $Res Function(_OnlinePlotStackSnapshot) _then;

/// Create a copy of OnlinePlotStackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revealed = null,Object? hidden = null,Object? hiddenCount = freezed,}) {
  return _then(_OnlinePlotStackSnapshot(
revealed: null == revealed ? _self._revealed : revealed // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hidden: null == hidden ? _self._hidden : hidden // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,hiddenCount: freezed == hiddenCount ? _self.hiddenCount : hiddenCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$OnlineTrickPlaySnapshot {

 int get playerID; OnlineEngineCard get card;
/// Create a copy of OnlineTrickPlaySnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineTrickPlaySnapshotCopyWith<OnlineTrickPlaySnapshot> get copyWith => _$OnlineTrickPlaySnapshotCopyWithImpl<OnlineTrickPlaySnapshot>(this as OnlineTrickPlaySnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineTrickPlaySnapshot&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.card, card) || other.card == card));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,card);

@override
String toString() {
  return 'OnlineTrickPlaySnapshot(playerID: $playerID, card: $card)';
}


}

/// @nodoc
abstract mixin class $OnlineTrickPlaySnapshotCopyWith<$Res>  {
  factory $OnlineTrickPlaySnapshotCopyWith(OnlineTrickPlaySnapshot value, $Res Function(OnlineTrickPlaySnapshot) _then) = _$OnlineTrickPlaySnapshotCopyWithImpl;
@useResult
$Res call({
 int playerID, OnlineEngineCard card
});


$OnlineEngineCardCopyWith<$Res> get card;

}
/// @nodoc
class _$OnlineTrickPlaySnapshotCopyWithImpl<$Res>
    implements $OnlineTrickPlaySnapshotCopyWith<$Res> {
  _$OnlineTrickPlaySnapshotCopyWithImpl(this._self, this._then);

  final OnlineTrickPlaySnapshot _self;
  final $Res Function(OnlineTrickPlaySnapshot) _then;

/// Create a copy of OnlineTrickPlaySnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerID = null,Object? card = null,}) {
  return _then(_self.copyWith(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,
  ));
}
/// Create a copy of OnlineTrickPlaySnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineTrickPlaySnapshot].
extension OnlineTrickPlaySnapshotPatterns on OnlineTrickPlaySnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineTrickPlaySnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineTrickPlaySnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineTrickPlaySnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineTrickPlaySnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineTrickPlaySnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineTrickPlaySnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int playerID,  OnlineEngineCard card)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineTrickPlaySnapshot() when $default != null:
return $default(_that.playerID,_that.card);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int playerID,  OnlineEngineCard card)  $default,) {final _that = this;
switch (_that) {
case _OnlineTrickPlaySnapshot():
return $default(_that.playerID,_that.card);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int playerID,  OnlineEngineCard card)?  $default,) {final _that = this;
switch (_that) {
case _OnlineTrickPlaySnapshot() when $default != null:
return $default(_that.playerID,_that.card);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineTrickPlaySnapshot implements OnlineTrickPlaySnapshot {
  const _OnlineTrickPlaySnapshot({required this.playerID, required this.card});
  factory _OnlineTrickPlaySnapshot.fromJson(Map<String, dynamic> json) => _$OnlineTrickPlaySnapshotFromJson(json);

@override final  int playerID;
@override final  OnlineEngineCard card;

/// Create a copy of OnlineTrickPlaySnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineTrickPlaySnapshotCopyWith<_OnlineTrickPlaySnapshot> get copyWith => __$OnlineTrickPlaySnapshotCopyWithImpl<_OnlineTrickPlaySnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineTrickPlaySnapshot&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.card, card) || other.card == card));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,card);

@override
String toString() {
  return 'OnlineTrickPlaySnapshot(playerID: $playerID, card: $card)';
}


}

/// @nodoc
abstract mixin class _$OnlineTrickPlaySnapshotCopyWith<$Res> implements $OnlineTrickPlaySnapshotCopyWith<$Res> {
  factory _$OnlineTrickPlaySnapshotCopyWith(_OnlineTrickPlaySnapshot value, $Res Function(_OnlineTrickPlaySnapshot) _then) = __$OnlineTrickPlaySnapshotCopyWithImpl;
@override @useResult
$Res call({
 int playerID, OnlineEngineCard card
});


@override $OnlineEngineCardCopyWith<$Res> get card;

}
/// @nodoc
class __$OnlineTrickPlaySnapshotCopyWithImpl<$Res>
    implements _$OnlineTrickPlaySnapshotCopyWith<$Res> {
  __$OnlineTrickPlaySnapshotCopyWithImpl(this._self, this._then);

  final _OnlineTrickPlaySnapshot _self;
  final $Res Function(_OnlineTrickPlaySnapshot) _then;

/// Create a copy of OnlineTrickPlaySnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerID = null,Object? card = null,}) {
  return _then(_OnlineTrickPlaySnapshot(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,
  ));
}

/// Create a copy of OnlineTrickPlaySnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}


/// @nodoc
mixin _$OnlineSuitCardsSnapshot {

 int get suit; List<OnlineEngineCard> get cards;
/// Create a copy of OnlineSuitCardsSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSuitCardsSnapshotCopyWith<OnlineSuitCardsSnapshot> get copyWith => _$OnlineSuitCardsSnapshotCopyWithImpl<OnlineSuitCardsSnapshot>(this as OnlineSuitCardsSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSuitCardsSnapshot&&(identical(other.suit, suit) || other.suit == suit)&&const DeepCollectionEquality().equals(other.cards, cards));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,suit,const DeepCollectionEquality().hash(cards));

@override
String toString() {
  return 'OnlineSuitCardsSnapshot(suit: $suit, cards: $cards)';
}


}

/// @nodoc
abstract mixin class $OnlineSuitCardsSnapshotCopyWith<$Res>  {
  factory $OnlineSuitCardsSnapshotCopyWith(OnlineSuitCardsSnapshot value, $Res Function(OnlineSuitCardsSnapshot) _then) = _$OnlineSuitCardsSnapshotCopyWithImpl;
@useResult
$Res call({
 int suit, List<OnlineEngineCard> cards
});




}
/// @nodoc
class _$OnlineSuitCardsSnapshotCopyWithImpl<$Res>
    implements $OnlineSuitCardsSnapshotCopyWith<$Res> {
  _$OnlineSuitCardsSnapshotCopyWithImpl(this._self, this._then);

  final OnlineSuitCardsSnapshot _self;
  final $Res Function(OnlineSuitCardsSnapshot) _then;

/// Create a copy of OnlineSuitCardsSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? suit = null,Object? cards = null,}) {
  return _then(_self.copyWith(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,cards: null == cards ? _self.cards : cards // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineSuitCardsSnapshot].
extension OnlineSuitCardsSnapshotPatterns on OnlineSuitCardsSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSuitCardsSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSuitCardsSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSuitCardsSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSuitCardsSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSuitCardsSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSuitCardsSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int suit,  List<OnlineEngineCard> cards)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSuitCardsSnapshot() when $default != null:
return $default(_that.suit,_that.cards);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int suit,  List<OnlineEngineCard> cards)  $default,) {final _that = this;
switch (_that) {
case _OnlineSuitCardsSnapshot():
return $default(_that.suit,_that.cards);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int suit,  List<OnlineEngineCard> cards)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSuitCardsSnapshot() when $default != null:
return $default(_that.suit,_that.cards);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSuitCardsSnapshot implements OnlineSuitCardsSnapshot {
  const _OnlineSuitCardsSnapshot({required this.suit, required final  List<OnlineEngineCard> cards}): _cards = cards;
  factory _OnlineSuitCardsSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineSuitCardsSnapshotFromJson(json);

@override final  int suit;
 final  List<OnlineEngineCard> _cards;
@override List<OnlineEngineCard> get cards {
  if (_cards is EqualUnmodifiableListView) return _cards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cards);
}


/// Create a copy of OnlineSuitCardsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSuitCardsSnapshotCopyWith<_OnlineSuitCardsSnapshot> get copyWith => __$OnlineSuitCardsSnapshotCopyWithImpl<_OnlineSuitCardsSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSuitCardsSnapshot&&(identical(other.suit, suit) || other.suit == suit)&&const DeepCollectionEquality().equals(other._cards, _cards));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,suit,const DeepCollectionEquality().hash(_cards));

@override
String toString() {
  return 'OnlineSuitCardsSnapshot(suit: $suit, cards: $cards)';
}


}

/// @nodoc
abstract mixin class _$OnlineSuitCardsSnapshotCopyWith<$Res> implements $OnlineSuitCardsSnapshotCopyWith<$Res> {
  factory _$OnlineSuitCardsSnapshotCopyWith(_OnlineSuitCardsSnapshot value, $Res Function(_OnlineSuitCardsSnapshot) _then) = __$OnlineSuitCardsSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int suit, List<OnlineEngineCard> cards
});




}
/// @nodoc
class __$OnlineSuitCardsSnapshotCopyWithImpl<$Res>
    implements _$OnlineSuitCardsSnapshotCopyWith<$Res> {
  __$OnlineSuitCardsSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineSuitCardsSnapshot _self;
  final $Res Function(_OnlineSuitCardsSnapshot) _then;

/// Create a copy of OnlineSuitCardsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? suit = null,Object? cards = null,}) {
  return _then(_OnlineSuitCardsSnapshot(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,cards: null == cards ? _self._cards : cards // ignore: cast_nullable_to_non_nullable
as List<OnlineEngineCard>,
  ));
}


}


/// @nodoc
mixin _$OnlineSuitValueSnapshot {

 int get suit; int get value;
/// Create a copy of OnlineSuitValueSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSuitValueSnapshotCopyWith<OnlineSuitValueSnapshot> get copyWith => _$OnlineSuitValueSnapshotCopyWithImpl<OnlineSuitValueSnapshot>(this as OnlineSuitValueSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSuitValueSnapshot&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,suit,value);

@override
String toString() {
  return 'OnlineSuitValueSnapshot(suit: $suit, value: $value)';
}


}

/// @nodoc
abstract mixin class $OnlineSuitValueSnapshotCopyWith<$Res>  {
  factory $OnlineSuitValueSnapshotCopyWith(OnlineSuitValueSnapshot value, $Res Function(OnlineSuitValueSnapshot) _then) = _$OnlineSuitValueSnapshotCopyWithImpl;
@useResult
$Res call({
 int suit, int value
});




}
/// @nodoc
class _$OnlineSuitValueSnapshotCopyWithImpl<$Res>
    implements $OnlineSuitValueSnapshotCopyWith<$Res> {
  _$OnlineSuitValueSnapshotCopyWithImpl(this._self, this._then);

  final OnlineSuitValueSnapshot _self;
  final $Res Function(OnlineSuitValueSnapshot) _then;

/// Create a copy of OnlineSuitValueSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? suit = null,Object? value = null,}) {
  return _then(_self.copyWith(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineSuitValueSnapshot].
extension OnlineSuitValueSnapshotPatterns on OnlineSuitValueSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSuitValueSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSuitValueSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSuitValueSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSuitValueSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSuitValueSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSuitValueSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int suit,  int value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSuitValueSnapshot() when $default != null:
return $default(_that.suit,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int suit,  int value)  $default,) {final _that = this;
switch (_that) {
case _OnlineSuitValueSnapshot():
return $default(_that.suit,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int suit,  int value)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSuitValueSnapshot() when $default != null:
return $default(_that.suit,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSuitValueSnapshot implements OnlineSuitValueSnapshot {
  const _OnlineSuitValueSnapshot({required this.suit, required this.value});
  factory _OnlineSuitValueSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineSuitValueSnapshotFromJson(json);

@override final  int suit;
@override final  int value;

/// Create a copy of OnlineSuitValueSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSuitValueSnapshotCopyWith<_OnlineSuitValueSnapshot> get copyWith => __$OnlineSuitValueSnapshotCopyWithImpl<_OnlineSuitValueSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSuitValueSnapshot&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,suit,value);

@override
String toString() {
  return 'OnlineSuitValueSnapshot(suit: $suit, value: $value)';
}


}

/// @nodoc
abstract mixin class _$OnlineSuitValueSnapshotCopyWith<$Res> implements $OnlineSuitValueSnapshotCopyWith<$Res> {
  factory _$OnlineSuitValueSnapshotCopyWith(_OnlineSuitValueSnapshot value, $Res Function(_OnlineSuitValueSnapshot) _then) = __$OnlineSuitValueSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int suit, int value
});




}
/// @nodoc
class __$OnlineSuitValueSnapshotCopyWithImpl<$Res>
    implements _$OnlineSuitValueSnapshotCopyWith<$Res> {
  __$OnlineSuitValueSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineSuitValueSnapshot _self;
  final $Res Function(_OnlineSuitValueSnapshot) _then;

/// Create a copy of OnlineSuitValueSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? suit = null,Object? value = null,}) {
  return _then(_OnlineSuitValueSnapshot(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OnlineSuitPlayersSnapshot {

 int get suit; List<int> get values;
/// Create a copy of OnlineSuitPlayersSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineSuitPlayersSnapshotCopyWith<OnlineSuitPlayersSnapshot> get copyWith => _$OnlineSuitPlayersSnapshotCopyWithImpl<OnlineSuitPlayersSnapshot>(this as OnlineSuitPlayersSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineSuitPlayersSnapshot&&(identical(other.suit, suit) || other.suit == suit)&&const DeepCollectionEquality().equals(other.values, values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,suit,const DeepCollectionEquality().hash(values));

@override
String toString() {
  return 'OnlineSuitPlayersSnapshot(suit: $suit, values: $values)';
}


}

/// @nodoc
abstract mixin class $OnlineSuitPlayersSnapshotCopyWith<$Res>  {
  factory $OnlineSuitPlayersSnapshotCopyWith(OnlineSuitPlayersSnapshot value, $Res Function(OnlineSuitPlayersSnapshot) _then) = _$OnlineSuitPlayersSnapshotCopyWithImpl;
@useResult
$Res call({
 int suit, List<int> values
});




}
/// @nodoc
class _$OnlineSuitPlayersSnapshotCopyWithImpl<$Res>
    implements $OnlineSuitPlayersSnapshotCopyWith<$Res> {
  _$OnlineSuitPlayersSnapshotCopyWithImpl(this._self, this._then);

  final OnlineSuitPlayersSnapshot _self;
  final $Res Function(OnlineSuitPlayersSnapshot) _then;

/// Create a copy of OnlineSuitPlayersSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? suit = null,Object? values = null,}) {
  return _then(_self.copyWith(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineSuitPlayersSnapshot].
extension OnlineSuitPlayersSnapshotPatterns on OnlineSuitPlayersSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineSuitPlayersSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineSuitPlayersSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineSuitPlayersSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineSuitPlayersSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineSuitPlayersSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineSuitPlayersSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int suit,  List<int> values)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineSuitPlayersSnapshot() when $default != null:
return $default(_that.suit,_that.values);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int suit,  List<int> values)  $default,) {final _that = this;
switch (_that) {
case _OnlineSuitPlayersSnapshot():
return $default(_that.suit,_that.values);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int suit,  List<int> values)?  $default,) {final _that = this;
switch (_that) {
case _OnlineSuitPlayersSnapshot() when $default != null:
return $default(_that.suit,_that.values);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineSuitPlayersSnapshot implements OnlineSuitPlayersSnapshot {
  const _OnlineSuitPlayersSnapshot({required this.suit, required final  List<int> values}): _values = values;
  factory _OnlineSuitPlayersSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineSuitPlayersSnapshotFromJson(json);

@override final  int suit;
 final  List<int> _values;
@override List<int> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}


/// Create a copy of OnlineSuitPlayersSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineSuitPlayersSnapshotCopyWith<_OnlineSuitPlayersSnapshot> get copyWith => __$OnlineSuitPlayersSnapshotCopyWithImpl<_OnlineSuitPlayersSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineSuitPlayersSnapshot&&(identical(other.suit, suit) || other.suit == suit)&&const DeepCollectionEquality().equals(other._values, _values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,suit,const DeepCollectionEquality().hash(_values));

@override
String toString() {
  return 'OnlineSuitPlayersSnapshot(suit: $suit, values: $values)';
}


}

/// @nodoc
abstract mixin class _$OnlineSuitPlayersSnapshotCopyWith<$Res> implements $OnlineSuitPlayersSnapshotCopyWith<$Res> {
  factory _$OnlineSuitPlayersSnapshotCopyWith(_OnlineSuitPlayersSnapshot value, $Res Function(_OnlineSuitPlayersSnapshot) _then) = __$OnlineSuitPlayersSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int suit, List<int> values
});




}
/// @nodoc
class __$OnlineSuitPlayersSnapshotCopyWithImpl<$Res>
    implements _$OnlineSuitPlayersSnapshotCopyWith<$Res> {
  __$OnlineSuitPlayersSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineSuitPlayersSnapshot _self;
  final $Res Function(_OnlineSuitPlayersSnapshot) _then;

/// Create a copy of OnlineSuitPlayersSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? suit = null,Object? values = null,}) {
  return _then(_OnlineSuitPlayersSnapshot(
suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$OnlineAssignmentSnapshot {

 OnlineEngineCard get card; int get targetSuit;
/// Create a copy of OnlineAssignmentSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineAssignmentSnapshotCopyWith<OnlineAssignmentSnapshot> get copyWith => _$OnlineAssignmentSnapshotCopyWithImpl<OnlineAssignmentSnapshot>(this as OnlineAssignmentSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineAssignmentSnapshot&&(identical(other.card, card) || other.card == card)&&(identical(other.targetSuit, targetSuit) || other.targetSuit == targetSuit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,card,targetSuit);

@override
String toString() {
  return 'OnlineAssignmentSnapshot(card: $card, targetSuit: $targetSuit)';
}


}

/// @nodoc
abstract mixin class $OnlineAssignmentSnapshotCopyWith<$Res>  {
  factory $OnlineAssignmentSnapshotCopyWith(OnlineAssignmentSnapshot value, $Res Function(OnlineAssignmentSnapshot) _then) = _$OnlineAssignmentSnapshotCopyWithImpl;
@useResult
$Res call({
 OnlineEngineCard card, int targetSuit
});


$OnlineEngineCardCopyWith<$Res> get card;

}
/// @nodoc
class _$OnlineAssignmentSnapshotCopyWithImpl<$Res>
    implements $OnlineAssignmentSnapshotCopyWith<$Res> {
  _$OnlineAssignmentSnapshotCopyWithImpl(this._self, this._then);

  final OnlineAssignmentSnapshot _self;
  final $Res Function(OnlineAssignmentSnapshot) _then;

/// Create a copy of OnlineAssignmentSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? card = null,Object? targetSuit = null,}) {
  return _then(_self.copyWith(
card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,targetSuit: null == targetSuit ? _self.targetSuit : targetSuit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of OnlineAssignmentSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineAssignmentSnapshot].
extension OnlineAssignmentSnapshotPatterns on OnlineAssignmentSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineAssignmentSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineAssignmentSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineAssignmentSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineAssignmentSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineAssignmentSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineAssignmentSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OnlineEngineCard card,  int targetSuit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineAssignmentSnapshot() when $default != null:
return $default(_that.card,_that.targetSuit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OnlineEngineCard card,  int targetSuit)  $default,) {final _that = this;
switch (_that) {
case _OnlineAssignmentSnapshot():
return $default(_that.card,_that.targetSuit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OnlineEngineCard card,  int targetSuit)?  $default,) {final _that = this;
switch (_that) {
case _OnlineAssignmentSnapshot() when $default != null:
return $default(_that.card,_that.targetSuit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineAssignmentSnapshot implements OnlineAssignmentSnapshot {
  const _OnlineAssignmentSnapshot({required this.card, required this.targetSuit});
  factory _OnlineAssignmentSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineAssignmentSnapshotFromJson(json);

@override final  OnlineEngineCard card;
@override final  int targetSuit;

/// Create a copy of OnlineAssignmentSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineAssignmentSnapshotCopyWith<_OnlineAssignmentSnapshot> get copyWith => __$OnlineAssignmentSnapshotCopyWithImpl<_OnlineAssignmentSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineAssignmentSnapshot&&(identical(other.card, card) || other.card == card)&&(identical(other.targetSuit, targetSuit) || other.targetSuit == targetSuit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,card,targetSuit);

@override
String toString() {
  return 'OnlineAssignmentSnapshot(card: $card, targetSuit: $targetSuit)';
}


}

/// @nodoc
abstract mixin class _$OnlineAssignmentSnapshotCopyWith<$Res> implements $OnlineAssignmentSnapshotCopyWith<$Res> {
  factory _$OnlineAssignmentSnapshotCopyWith(_OnlineAssignmentSnapshot value, $Res Function(_OnlineAssignmentSnapshot) _then) = __$OnlineAssignmentSnapshotCopyWithImpl;
@override @useResult
$Res call({
 OnlineEngineCard card, int targetSuit
});


@override $OnlineEngineCardCopyWith<$Res> get card;

}
/// @nodoc
class __$OnlineAssignmentSnapshotCopyWithImpl<$Res>
    implements _$OnlineAssignmentSnapshotCopyWith<$Res> {
  __$OnlineAssignmentSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineAssignmentSnapshot _self;
  final $Res Function(_OnlineAssignmentSnapshot) _then;

/// Create a copy of OnlineAssignmentSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? card = null,Object? targetSuit = null,}) {
  return _then(_OnlineAssignmentSnapshot(
card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,targetSuit: null == targetSuit ? _self.targetSuit : targetSuit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of OnlineAssignmentSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}


/// @nodoc
mixin _$OnlineRequisitionSnapshot {

 int get playerID; int get suit; OnlineEngineCard get card; String get message;
/// Create a copy of OnlineRequisitionSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineRequisitionSnapshotCopyWith<OnlineRequisitionSnapshot> get copyWith => _$OnlineRequisitionSnapshotCopyWithImpl<OnlineRequisitionSnapshot>(this as OnlineRequisitionSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineRequisitionSnapshot&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.card, card) || other.card == card)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,suit,card,message);

@override
String toString() {
  return 'OnlineRequisitionSnapshot(playerID: $playerID, suit: $suit, card: $card, message: $message)';
}


}

/// @nodoc
abstract mixin class $OnlineRequisitionSnapshotCopyWith<$Res>  {
  factory $OnlineRequisitionSnapshotCopyWith(OnlineRequisitionSnapshot value, $Res Function(OnlineRequisitionSnapshot) _then) = _$OnlineRequisitionSnapshotCopyWithImpl;
@useResult
$Res call({
 int playerID, int suit, OnlineEngineCard card, String message
});


$OnlineEngineCardCopyWith<$Res> get card;

}
/// @nodoc
class _$OnlineRequisitionSnapshotCopyWithImpl<$Res>
    implements $OnlineRequisitionSnapshotCopyWith<$Res> {
  _$OnlineRequisitionSnapshotCopyWithImpl(this._self, this._then);

  final OnlineRequisitionSnapshot _self;
  final $Res Function(OnlineRequisitionSnapshot) _then;

/// Create a copy of OnlineRequisitionSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerID = null,Object? suit = null,Object? card = null,Object? message = null,}) {
  return _then(_self.copyWith(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of OnlineRequisitionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineRequisitionSnapshot].
extension OnlineRequisitionSnapshotPatterns on OnlineRequisitionSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineRequisitionSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineRequisitionSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineRequisitionSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineRequisitionSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineRequisitionSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineRequisitionSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int playerID,  int suit,  OnlineEngineCard card,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineRequisitionSnapshot() when $default != null:
return $default(_that.playerID,_that.suit,_that.card,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int playerID,  int suit,  OnlineEngineCard card,  String message)  $default,) {final _that = this;
switch (_that) {
case _OnlineRequisitionSnapshot():
return $default(_that.playerID,_that.suit,_that.card,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int playerID,  int suit,  OnlineEngineCard card,  String message)?  $default,) {final _that = this;
switch (_that) {
case _OnlineRequisitionSnapshot() when $default != null:
return $default(_that.playerID,_that.suit,_that.card,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineRequisitionSnapshot implements OnlineRequisitionSnapshot {
  const _OnlineRequisitionSnapshot({required this.playerID, required this.suit, required this.card, required this.message});
  factory _OnlineRequisitionSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineRequisitionSnapshotFromJson(json);

@override final  int playerID;
@override final  int suit;
@override final  OnlineEngineCard card;
@override final  String message;

/// Create a copy of OnlineRequisitionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineRequisitionSnapshotCopyWith<_OnlineRequisitionSnapshot> get copyWith => __$OnlineRequisitionSnapshotCopyWithImpl<_OnlineRequisitionSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineRequisitionSnapshot&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.suit, suit) || other.suit == suit)&&(identical(other.card, card) || other.card == card)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,suit,card,message);

@override
String toString() {
  return 'OnlineRequisitionSnapshot(playerID: $playerID, suit: $suit, card: $card, message: $message)';
}


}

/// @nodoc
abstract mixin class _$OnlineRequisitionSnapshotCopyWith<$Res> implements $OnlineRequisitionSnapshotCopyWith<$Res> {
  factory _$OnlineRequisitionSnapshotCopyWith(_OnlineRequisitionSnapshot value, $Res Function(_OnlineRequisitionSnapshot) _then) = __$OnlineRequisitionSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int playerID, int suit, OnlineEngineCard card, String message
});


@override $OnlineEngineCardCopyWith<$Res> get card;

}
/// @nodoc
class __$OnlineRequisitionSnapshotCopyWithImpl<$Res>
    implements _$OnlineRequisitionSnapshotCopyWith<$Res> {
  __$OnlineRequisitionSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineRequisitionSnapshot _self;
  final $Res Function(_OnlineRequisitionSnapshot) _then;

/// Create a copy of OnlineRequisitionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerID = null,Object? suit = null,Object? card = null,Object? message = null,}) {
  return _then(_OnlineRequisitionSnapshot(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,suit: null == suit ? _self.suit : suit // ignore: cast_nullable_to_non_nullable
as int,card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of OnlineRequisitionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get card {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}


/// @nodoc
mixin _$OnlineScoreSnapshot {

 int get playerID; int get visibleScore; int get finalScore;
/// Create a copy of OnlineScoreSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineScoreSnapshotCopyWith<OnlineScoreSnapshot> get copyWith => _$OnlineScoreSnapshotCopyWithImpl<OnlineScoreSnapshot>(this as OnlineScoreSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineScoreSnapshot&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.visibleScore, visibleScore) || other.visibleScore == visibleScore)&&(identical(other.finalScore, finalScore) || other.finalScore == finalScore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,visibleScore,finalScore);

@override
String toString() {
  return 'OnlineScoreSnapshot(playerID: $playerID, visibleScore: $visibleScore, finalScore: $finalScore)';
}


}

/// @nodoc
abstract mixin class $OnlineScoreSnapshotCopyWith<$Res>  {
  factory $OnlineScoreSnapshotCopyWith(OnlineScoreSnapshot value, $Res Function(OnlineScoreSnapshot) _then) = _$OnlineScoreSnapshotCopyWithImpl;
@useResult
$Res call({
 int playerID, int visibleScore, int finalScore
});




}
/// @nodoc
class _$OnlineScoreSnapshotCopyWithImpl<$Res>
    implements $OnlineScoreSnapshotCopyWith<$Res> {
  _$OnlineScoreSnapshotCopyWithImpl(this._self, this._then);

  final OnlineScoreSnapshot _self;
  final $Res Function(OnlineScoreSnapshot) _then;

/// Create a copy of OnlineScoreSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerID = null,Object? visibleScore = null,Object? finalScore = null,}) {
  return _then(_self.copyWith(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,visibleScore: null == visibleScore ? _self.visibleScore : visibleScore // ignore: cast_nullable_to_non_nullable
as int,finalScore: null == finalScore ? _self.finalScore : finalScore // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineScoreSnapshot].
extension OnlineScoreSnapshotPatterns on OnlineScoreSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineScoreSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineScoreSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineScoreSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineScoreSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineScoreSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineScoreSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int playerID,  int visibleScore,  int finalScore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineScoreSnapshot() when $default != null:
return $default(_that.playerID,_that.visibleScore,_that.finalScore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int playerID,  int visibleScore,  int finalScore)  $default,) {final _that = this;
switch (_that) {
case _OnlineScoreSnapshot():
return $default(_that.playerID,_that.visibleScore,_that.finalScore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int playerID,  int visibleScore,  int finalScore)?  $default,) {final _that = this;
switch (_that) {
case _OnlineScoreSnapshot() when $default != null:
return $default(_that.playerID,_that.visibleScore,_that.finalScore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineScoreSnapshot implements OnlineScoreSnapshot {
  const _OnlineScoreSnapshot({required this.playerID, required this.visibleScore, required this.finalScore});
  factory _OnlineScoreSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineScoreSnapshotFromJson(json);

@override final  int playerID;
@override final  int visibleScore;
@override final  int finalScore;

/// Create a copy of OnlineScoreSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineScoreSnapshotCopyWith<_OnlineScoreSnapshot> get copyWith => __$OnlineScoreSnapshotCopyWithImpl<_OnlineScoreSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineScoreSnapshot&&(identical(other.playerID, playerID) || other.playerID == playerID)&&(identical(other.visibleScore, visibleScore) || other.visibleScore == visibleScore)&&(identical(other.finalScore, finalScore) || other.finalScore == finalScore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerID,visibleScore,finalScore);

@override
String toString() {
  return 'OnlineScoreSnapshot(playerID: $playerID, visibleScore: $visibleScore, finalScore: $finalScore)';
}


}

/// @nodoc
abstract mixin class _$OnlineScoreSnapshotCopyWith<$Res> implements $OnlineScoreSnapshotCopyWith<$Res> {
  factory _$OnlineScoreSnapshotCopyWith(_OnlineScoreSnapshot value, $Res Function(_OnlineScoreSnapshot) _then) = __$OnlineScoreSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int playerID, int visibleScore, int finalScore
});




}
/// @nodoc
class __$OnlineScoreSnapshotCopyWithImpl<$Res>
    implements _$OnlineScoreSnapshotCopyWith<$Res> {
  __$OnlineScoreSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineScoreSnapshot _self;
  final $Res Function(_OnlineScoreSnapshot) _then;

/// Create a copy of OnlineScoreSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerID = null,Object? visibleScore = null,Object? finalScore = null,}) {
  return _then(_OnlineScoreSnapshot(
playerID: null == playerID ? _self.playerID : playerID // ignore: cast_nullable_to_non_nullable
as int,visibleScore: null == visibleScore ? _self.visibleScore : visibleScore // ignore: cast_nullable_to_non_nullable
as int,finalScore: null == finalScore ? _self.finalScore : finalScore // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OnlineEngineSnapshot {

 int get year; int get phase; int get currentPlayer; int get waitingPlayer; bool get waitingForExternalAction; int get lead; int get trumpSelector; int get trump; int get trickCount; bool get isFamine; List<OnlinePlayerSnapshot> get players; List<OnlineSuitCardsSnapshot> get jobPiles; List<OnlineSuitCardsSnapshot> get revealedJobs; List<int> get claimedJobs; List<OnlineSuitValueSnapshot> get workHours; List<OnlineSuitCardsSnapshot> get jobBuckets; List<OnlineSuitCardsSnapshot> get accumulatedJobCards; List<OnlineTrickPlaySnapshot> get currentTrick; List<OnlineTrickPlaySnapshot> get lastTrick; int get lastWinner; List<OnlineSuitCardsSnapshot> get exiled; List<OnlineSuitPlayersSnapshot> get exiledPlayers; List<OnlineAssignmentSnapshot> get pendingAssignments; List<OnlineRequisitionSnapshot> get requisitionEvents; List<OnlineScoreSnapshot> get scores; int get winnerID; List<int> get swapConfirmed; List<int> get swapCount; List<int> get passConfirmed; OnlineEngineCard get finalYearTrumpCard;
/// Create a copy of OnlineEngineSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineEngineSnapshotCopyWith<OnlineEngineSnapshot> get copyWith => _$OnlineEngineSnapshotCopyWithImpl<OnlineEngineSnapshot>(this as OnlineEngineSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineEngineSnapshot&&(identical(other.year, year) || other.year == year)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.currentPlayer, currentPlayer) || other.currentPlayer == currentPlayer)&&(identical(other.waitingPlayer, waitingPlayer) || other.waitingPlayer == waitingPlayer)&&(identical(other.waitingForExternalAction, waitingForExternalAction) || other.waitingForExternalAction == waitingForExternalAction)&&(identical(other.lead, lead) || other.lead == lead)&&(identical(other.trumpSelector, trumpSelector) || other.trumpSelector == trumpSelector)&&(identical(other.trump, trump) || other.trump == trump)&&(identical(other.trickCount, trickCount) || other.trickCount == trickCount)&&(identical(other.isFamine, isFamine) || other.isFamine == isFamine)&&const DeepCollectionEquality().equals(other.players, players)&&const DeepCollectionEquality().equals(other.jobPiles, jobPiles)&&const DeepCollectionEquality().equals(other.revealedJobs, revealedJobs)&&const DeepCollectionEquality().equals(other.claimedJobs, claimedJobs)&&const DeepCollectionEquality().equals(other.workHours, workHours)&&const DeepCollectionEquality().equals(other.jobBuckets, jobBuckets)&&const DeepCollectionEquality().equals(other.accumulatedJobCards, accumulatedJobCards)&&const DeepCollectionEquality().equals(other.currentTrick, currentTrick)&&const DeepCollectionEquality().equals(other.lastTrick, lastTrick)&&(identical(other.lastWinner, lastWinner) || other.lastWinner == lastWinner)&&const DeepCollectionEquality().equals(other.exiled, exiled)&&const DeepCollectionEquality().equals(other.exiledPlayers, exiledPlayers)&&const DeepCollectionEquality().equals(other.pendingAssignments, pendingAssignments)&&const DeepCollectionEquality().equals(other.requisitionEvents, requisitionEvents)&&const DeepCollectionEquality().equals(other.scores, scores)&&(identical(other.winnerID, winnerID) || other.winnerID == winnerID)&&const DeepCollectionEquality().equals(other.swapConfirmed, swapConfirmed)&&const DeepCollectionEquality().equals(other.swapCount, swapCount)&&const DeepCollectionEquality().equals(other.passConfirmed, passConfirmed)&&(identical(other.finalYearTrumpCard, finalYearTrumpCard) || other.finalYearTrumpCard == finalYearTrumpCard));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,year,phase,currentPlayer,waitingPlayer,waitingForExternalAction,lead,trumpSelector,trump,trickCount,isFamine,const DeepCollectionEquality().hash(players),const DeepCollectionEquality().hash(jobPiles),const DeepCollectionEquality().hash(revealedJobs),const DeepCollectionEquality().hash(claimedJobs),const DeepCollectionEquality().hash(workHours),const DeepCollectionEquality().hash(jobBuckets),const DeepCollectionEquality().hash(accumulatedJobCards),const DeepCollectionEquality().hash(currentTrick),const DeepCollectionEquality().hash(lastTrick),lastWinner,const DeepCollectionEquality().hash(exiled),const DeepCollectionEquality().hash(exiledPlayers),const DeepCollectionEquality().hash(pendingAssignments),const DeepCollectionEquality().hash(requisitionEvents),const DeepCollectionEquality().hash(scores),winnerID,const DeepCollectionEquality().hash(swapConfirmed),const DeepCollectionEquality().hash(swapCount),const DeepCollectionEquality().hash(passConfirmed),finalYearTrumpCard]);

@override
String toString() {
  return 'OnlineEngineSnapshot(year: $year, phase: $phase, currentPlayer: $currentPlayer, waitingPlayer: $waitingPlayer, waitingForExternalAction: $waitingForExternalAction, lead: $lead, trumpSelector: $trumpSelector, trump: $trump, trickCount: $trickCount, isFamine: $isFamine, players: $players, jobPiles: $jobPiles, revealedJobs: $revealedJobs, claimedJobs: $claimedJobs, workHours: $workHours, jobBuckets: $jobBuckets, accumulatedJobCards: $accumulatedJobCards, currentTrick: $currentTrick, lastTrick: $lastTrick, lastWinner: $lastWinner, exiled: $exiled, exiledPlayers: $exiledPlayers, pendingAssignments: $pendingAssignments, requisitionEvents: $requisitionEvents, scores: $scores, winnerID: $winnerID, swapConfirmed: $swapConfirmed, swapCount: $swapCount, passConfirmed: $passConfirmed, finalYearTrumpCard: $finalYearTrumpCard)';
}


}

/// @nodoc
abstract mixin class $OnlineEngineSnapshotCopyWith<$Res>  {
  factory $OnlineEngineSnapshotCopyWith(OnlineEngineSnapshot value, $Res Function(OnlineEngineSnapshot) _then) = _$OnlineEngineSnapshotCopyWithImpl;
@useResult
$Res call({
 int year, int phase, int currentPlayer, int waitingPlayer, bool waitingForExternalAction, int lead, int trumpSelector, int trump, int trickCount, bool isFamine, List<OnlinePlayerSnapshot> players, List<OnlineSuitCardsSnapshot> jobPiles, List<OnlineSuitCardsSnapshot> revealedJobs, List<int> claimedJobs, List<OnlineSuitValueSnapshot> workHours, List<OnlineSuitCardsSnapshot> jobBuckets, List<OnlineSuitCardsSnapshot> accumulatedJobCards, List<OnlineTrickPlaySnapshot> currentTrick, List<OnlineTrickPlaySnapshot> lastTrick, int lastWinner, List<OnlineSuitCardsSnapshot> exiled, List<OnlineSuitPlayersSnapshot> exiledPlayers, List<OnlineAssignmentSnapshot> pendingAssignments, List<OnlineRequisitionSnapshot> requisitionEvents, List<OnlineScoreSnapshot> scores, int winnerID, List<int> swapConfirmed, List<int> swapCount, List<int> passConfirmed, OnlineEngineCard finalYearTrumpCard
});


$OnlineEngineCardCopyWith<$Res> get finalYearTrumpCard;

}
/// @nodoc
class _$OnlineEngineSnapshotCopyWithImpl<$Res>
    implements $OnlineEngineSnapshotCopyWith<$Res> {
  _$OnlineEngineSnapshotCopyWithImpl(this._self, this._then);

  final OnlineEngineSnapshot _self;
  final $Res Function(OnlineEngineSnapshot) _then;

/// Create a copy of OnlineEngineSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? year = null,Object? phase = null,Object? currentPlayer = null,Object? waitingPlayer = null,Object? waitingForExternalAction = null,Object? lead = null,Object? trumpSelector = null,Object? trump = null,Object? trickCount = null,Object? isFamine = null,Object? players = null,Object? jobPiles = null,Object? revealedJobs = null,Object? claimedJobs = null,Object? workHours = null,Object? jobBuckets = null,Object? accumulatedJobCards = null,Object? currentTrick = null,Object? lastTrick = null,Object? lastWinner = null,Object? exiled = null,Object? exiledPlayers = null,Object? pendingAssignments = null,Object? requisitionEvents = null,Object? scores = null,Object? winnerID = null,Object? swapConfirmed = null,Object? swapCount = null,Object? passConfirmed = null,Object? finalYearTrumpCard = null,}) {
  return _then(_self.copyWith(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as int,currentPlayer: null == currentPlayer ? _self.currentPlayer : currentPlayer // ignore: cast_nullable_to_non_nullable
as int,waitingPlayer: null == waitingPlayer ? _self.waitingPlayer : waitingPlayer // ignore: cast_nullable_to_non_nullable
as int,waitingForExternalAction: null == waitingForExternalAction ? _self.waitingForExternalAction : waitingForExternalAction // ignore: cast_nullable_to_non_nullable
as bool,lead: null == lead ? _self.lead : lead // ignore: cast_nullable_to_non_nullable
as int,trumpSelector: null == trumpSelector ? _self.trumpSelector : trumpSelector // ignore: cast_nullable_to_non_nullable
as int,trump: null == trump ? _self.trump : trump // ignore: cast_nullable_to_non_nullable
as int,trickCount: null == trickCount ? _self.trickCount : trickCount // ignore: cast_nullable_to_non_nullable
as int,isFamine: null == isFamine ? _self.isFamine : isFamine // ignore: cast_nullable_to_non_nullable
as bool,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerSnapshot>,jobPiles: null == jobPiles ? _self.jobPiles : jobPiles // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,revealedJobs: null == revealedJobs ? _self.revealedJobs : revealedJobs // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,claimedJobs: null == claimedJobs ? _self.claimedJobs : claimedJobs // ignore: cast_nullable_to_non_nullable
as List<int>,workHours: null == workHours ? _self.workHours : workHours // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitValueSnapshot>,jobBuckets: null == jobBuckets ? _self.jobBuckets : jobBuckets // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,accumulatedJobCards: null == accumulatedJobCards ? _self.accumulatedJobCards : accumulatedJobCards // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,currentTrick: null == currentTrick ? _self.currentTrick : currentTrick // ignore: cast_nullable_to_non_nullable
as List<OnlineTrickPlaySnapshot>,lastTrick: null == lastTrick ? _self.lastTrick : lastTrick // ignore: cast_nullable_to_non_nullable
as List<OnlineTrickPlaySnapshot>,lastWinner: null == lastWinner ? _self.lastWinner : lastWinner // ignore: cast_nullable_to_non_nullable
as int,exiled: null == exiled ? _self.exiled : exiled // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,exiledPlayers: null == exiledPlayers ? _self.exiledPlayers : exiledPlayers // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitPlayersSnapshot>,pendingAssignments: null == pendingAssignments ? _self.pendingAssignments : pendingAssignments // ignore: cast_nullable_to_non_nullable
as List<OnlineAssignmentSnapshot>,requisitionEvents: null == requisitionEvents ? _self.requisitionEvents : requisitionEvents // ignore: cast_nullable_to_non_nullable
as List<OnlineRequisitionSnapshot>,scores: null == scores ? _self.scores : scores // ignore: cast_nullable_to_non_nullable
as List<OnlineScoreSnapshot>,winnerID: null == winnerID ? _self.winnerID : winnerID // ignore: cast_nullable_to_non_nullable
as int,swapConfirmed: null == swapConfirmed ? _self.swapConfirmed : swapConfirmed // ignore: cast_nullable_to_non_nullable
as List<int>,swapCount: null == swapCount ? _self.swapCount : swapCount // ignore: cast_nullable_to_non_nullable
as List<int>,passConfirmed: null == passConfirmed ? _self.passConfirmed : passConfirmed // ignore: cast_nullable_to_non_nullable
as List<int>,finalYearTrumpCard: null == finalYearTrumpCard ? _self.finalYearTrumpCard : finalYearTrumpCard // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,
  ));
}
/// Create a copy of OnlineEngineSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get finalYearTrumpCard {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.finalYearTrumpCard, (value) {
    return _then(_self.copyWith(finalYearTrumpCard: value));
  });
}
}


/// Adds pattern-matching-related methods to [OnlineEngineSnapshot].
extension OnlineEngineSnapshotPatterns on OnlineEngineSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineEngineSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineEngineSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineEngineSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OnlineEngineSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineEngineSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineEngineSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int year,  int phase,  int currentPlayer,  int waitingPlayer,  bool waitingForExternalAction,  int lead,  int trumpSelector,  int trump,  int trickCount,  bool isFamine,  List<OnlinePlayerSnapshot> players,  List<OnlineSuitCardsSnapshot> jobPiles,  List<OnlineSuitCardsSnapshot> revealedJobs,  List<int> claimedJobs,  List<OnlineSuitValueSnapshot> workHours,  List<OnlineSuitCardsSnapshot> jobBuckets,  List<OnlineSuitCardsSnapshot> accumulatedJobCards,  List<OnlineTrickPlaySnapshot> currentTrick,  List<OnlineTrickPlaySnapshot> lastTrick,  int lastWinner,  List<OnlineSuitCardsSnapshot> exiled,  List<OnlineSuitPlayersSnapshot> exiledPlayers,  List<OnlineAssignmentSnapshot> pendingAssignments,  List<OnlineRequisitionSnapshot> requisitionEvents,  List<OnlineScoreSnapshot> scores,  int winnerID,  List<int> swapConfirmed,  List<int> swapCount,  List<int> passConfirmed,  OnlineEngineCard finalYearTrumpCard)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineEngineSnapshot() when $default != null:
return $default(_that.year,_that.phase,_that.currentPlayer,_that.waitingPlayer,_that.waitingForExternalAction,_that.lead,_that.trumpSelector,_that.trump,_that.trickCount,_that.isFamine,_that.players,_that.jobPiles,_that.revealedJobs,_that.claimedJobs,_that.workHours,_that.jobBuckets,_that.accumulatedJobCards,_that.currentTrick,_that.lastTrick,_that.lastWinner,_that.exiled,_that.exiledPlayers,_that.pendingAssignments,_that.requisitionEvents,_that.scores,_that.winnerID,_that.swapConfirmed,_that.swapCount,_that.passConfirmed,_that.finalYearTrumpCard);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int year,  int phase,  int currentPlayer,  int waitingPlayer,  bool waitingForExternalAction,  int lead,  int trumpSelector,  int trump,  int trickCount,  bool isFamine,  List<OnlinePlayerSnapshot> players,  List<OnlineSuitCardsSnapshot> jobPiles,  List<OnlineSuitCardsSnapshot> revealedJobs,  List<int> claimedJobs,  List<OnlineSuitValueSnapshot> workHours,  List<OnlineSuitCardsSnapshot> jobBuckets,  List<OnlineSuitCardsSnapshot> accumulatedJobCards,  List<OnlineTrickPlaySnapshot> currentTrick,  List<OnlineTrickPlaySnapshot> lastTrick,  int lastWinner,  List<OnlineSuitCardsSnapshot> exiled,  List<OnlineSuitPlayersSnapshot> exiledPlayers,  List<OnlineAssignmentSnapshot> pendingAssignments,  List<OnlineRequisitionSnapshot> requisitionEvents,  List<OnlineScoreSnapshot> scores,  int winnerID,  List<int> swapConfirmed,  List<int> swapCount,  List<int> passConfirmed,  OnlineEngineCard finalYearTrumpCard)  $default,) {final _that = this;
switch (_that) {
case _OnlineEngineSnapshot():
return $default(_that.year,_that.phase,_that.currentPlayer,_that.waitingPlayer,_that.waitingForExternalAction,_that.lead,_that.trumpSelector,_that.trump,_that.trickCount,_that.isFamine,_that.players,_that.jobPiles,_that.revealedJobs,_that.claimedJobs,_that.workHours,_that.jobBuckets,_that.accumulatedJobCards,_that.currentTrick,_that.lastTrick,_that.lastWinner,_that.exiled,_that.exiledPlayers,_that.pendingAssignments,_that.requisitionEvents,_that.scores,_that.winnerID,_that.swapConfirmed,_that.swapCount,_that.passConfirmed,_that.finalYearTrumpCard);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int year,  int phase,  int currentPlayer,  int waitingPlayer,  bool waitingForExternalAction,  int lead,  int trumpSelector,  int trump,  int trickCount,  bool isFamine,  List<OnlinePlayerSnapshot> players,  List<OnlineSuitCardsSnapshot> jobPiles,  List<OnlineSuitCardsSnapshot> revealedJobs,  List<int> claimedJobs,  List<OnlineSuitValueSnapshot> workHours,  List<OnlineSuitCardsSnapshot> jobBuckets,  List<OnlineSuitCardsSnapshot> accumulatedJobCards,  List<OnlineTrickPlaySnapshot> currentTrick,  List<OnlineTrickPlaySnapshot> lastTrick,  int lastWinner,  List<OnlineSuitCardsSnapshot> exiled,  List<OnlineSuitPlayersSnapshot> exiledPlayers,  List<OnlineAssignmentSnapshot> pendingAssignments,  List<OnlineRequisitionSnapshot> requisitionEvents,  List<OnlineScoreSnapshot> scores,  int winnerID,  List<int> swapConfirmed,  List<int> swapCount,  List<int> passConfirmed,  OnlineEngineCard finalYearTrumpCard)?  $default,) {final _that = this;
switch (_that) {
case _OnlineEngineSnapshot() when $default != null:
return $default(_that.year,_that.phase,_that.currentPlayer,_that.waitingPlayer,_that.waitingForExternalAction,_that.lead,_that.trumpSelector,_that.trump,_that.trickCount,_that.isFamine,_that.players,_that.jobPiles,_that.revealedJobs,_that.claimedJobs,_that.workHours,_that.jobBuckets,_that.accumulatedJobCards,_that.currentTrick,_that.lastTrick,_that.lastWinner,_that.exiled,_that.exiledPlayers,_that.pendingAssignments,_that.requisitionEvents,_that.scores,_that.winnerID,_that.swapConfirmed,_that.swapCount,_that.passConfirmed,_that.finalYearTrumpCard);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(createToJson: false)

class _OnlineEngineSnapshot implements OnlineEngineSnapshot {
  const _OnlineEngineSnapshot({required this.year, required this.phase, required this.currentPlayer, required this.waitingPlayer, required this.waitingForExternalAction, required this.lead, required this.trumpSelector, required this.trump, required this.trickCount, required this.isFamine, required final  List<OnlinePlayerSnapshot> players, required final  List<OnlineSuitCardsSnapshot> jobPiles, required final  List<OnlineSuitCardsSnapshot> revealedJobs, required final  List<int> claimedJobs, required final  List<OnlineSuitValueSnapshot> workHours, required final  List<OnlineSuitCardsSnapshot> jobBuckets, required final  List<OnlineSuitCardsSnapshot> accumulatedJobCards, required final  List<OnlineTrickPlaySnapshot> currentTrick, required final  List<OnlineTrickPlaySnapshot> lastTrick, required this.lastWinner, required final  List<OnlineSuitCardsSnapshot> exiled, final  List<OnlineSuitPlayersSnapshot> exiledPlayers = const [], required final  List<OnlineAssignmentSnapshot> pendingAssignments, required final  List<OnlineRequisitionSnapshot> requisitionEvents, required final  List<OnlineScoreSnapshot> scores, required this.winnerID, required final  List<int> swapConfirmed, required final  List<int> swapCount, final  List<int> passConfirmed = const [], this.finalYearTrumpCard = const OnlineEngineCard(suit: -1, value: 0)}): _players = players,_jobPiles = jobPiles,_revealedJobs = revealedJobs,_claimedJobs = claimedJobs,_workHours = workHours,_jobBuckets = jobBuckets,_accumulatedJobCards = accumulatedJobCards,_currentTrick = currentTrick,_lastTrick = lastTrick,_exiled = exiled,_exiledPlayers = exiledPlayers,_pendingAssignments = pendingAssignments,_requisitionEvents = requisitionEvents,_scores = scores,_swapConfirmed = swapConfirmed,_swapCount = swapCount,_passConfirmed = passConfirmed;
  factory _OnlineEngineSnapshot.fromJson(Map<String, dynamic> json) => _$OnlineEngineSnapshotFromJson(json);

@override final  int year;
@override final  int phase;
@override final  int currentPlayer;
@override final  int waitingPlayer;
@override final  bool waitingForExternalAction;
@override final  int lead;
@override final  int trumpSelector;
@override final  int trump;
@override final  int trickCount;
@override final  bool isFamine;
 final  List<OnlinePlayerSnapshot> _players;
@override List<OnlinePlayerSnapshot> get players {
  if (_players is EqualUnmodifiableListView) return _players;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_players);
}

 final  List<OnlineSuitCardsSnapshot> _jobPiles;
@override List<OnlineSuitCardsSnapshot> get jobPiles {
  if (_jobPiles is EqualUnmodifiableListView) return _jobPiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_jobPiles);
}

 final  List<OnlineSuitCardsSnapshot> _revealedJobs;
@override List<OnlineSuitCardsSnapshot> get revealedJobs {
  if (_revealedJobs is EqualUnmodifiableListView) return _revealedJobs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revealedJobs);
}

 final  List<int> _claimedJobs;
@override List<int> get claimedJobs {
  if (_claimedJobs is EqualUnmodifiableListView) return _claimedJobs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_claimedJobs);
}

 final  List<OnlineSuitValueSnapshot> _workHours;
@override List<OnlineSuitValueSnapshot> get workHours {
  if (_workHours is EqualUnmodifiableListView) return _workHours;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_workHours);
}

 final  List<OnlineSuitCardsSnapshot> _jobBuckets;
@override List<OnlineSuitCardsSnapshot> get jobBuckets {
  if (_jobBuckets is EqualUnmodifiableListView) return _jobBuckets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_jobBuckets);
}

 final  List<OnlineSuitCardsSnapshot> _accumulatedJobCards;
@override List<OnlineSuitCardsSnapshot> get accumulatedJobCards {
  if (_accumulatedJobCards is EqualUnmodifiableListView) return _accumulatedJobCards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accumulatedJobCards);
}

 final  List<OnlineTrickPlaySnapshot> _currentTrick;
@override List<OnlineTrickPlaySnapshot> get currentTrick {
  if (_currentTrick is EqualUnmodifiableListView) return _currentTrick;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_currentTrick);
}

 final  List<OnlineTrickPlaySnapshot> _lastTrick;
@override List<OnlineTrickPlaySnapshot> get lastTrick {
  if (_lastTrick is EqualUnmodifiableListView) return _lastTrick;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lastTrick);
}

@override final  int lastWinner;
 final  List<OnlineSuitCardsSnapshot> _exiled;
@override List<OnlineSuitCardsSnapshot> get exiled {
  if (_exiled is EqualUnmodifiableListView) return _exiled;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exiled);
}

 final  List<OnlineSuitPlayersSnapshot> _exiledPlayers;
@override@JsonKey() List<OnlineSuitPlayersSnapshot> get exiledPlayers {
  if (_exiledPlayers is EqualUnmodifiableListView) return _exiledPlayers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exiledPlayers);
}

 final  List<OnlineAssignmentSnapshot> _pendingAssignments;
@override List<OnlineAssignmentSnapshot> get pendingAssignments {
  if (_pendingAssignments is EqualUnmodifiableListView) return _pendingAssignments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingAssignments);
}

 final  List<OnlineRequisitionSnapshot> _requisitionEvents;
@override List<OnlineRequisitionSnapshot> get requisitionEvents {
  if (_requisitionEvents is EqualUnmodifiableListView) return _requisitionEvents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requisitionEvents);
}

 final  List<OnlineScoreSnapshot> _scores;
@override List<OnlineScoreSnapshot> get scores {
  if (_scores is EqualUnmodifiableListView) return _scores;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_scores);
}

@override final  int winnerID;
 final  List<int> _swapConfirmed;
@override List<int> get swapConfirmed {
  if (_swapConfirmed is EqualUnmodifiableListView) return _swapConfirmed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_swapConfirmed);
}

 final  List<int> _swapCount;
@override List<int> get swapCount {
  if (_swapCount is EqualUnmodifiableListView) return _swapCount;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_swapCount);
}

 final  List<int> _passConfirmed;
@override@JsonKey() List<int> get passConfirmed {
  if (_passConfirmed is EqualUnmodifiableListView) return _passConfirmed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_passConfirmed);
}

@override@JsonKey() final  OnlineEngineCard finalYearTrumpCard;

/// Create a copy of OnlineEngineSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineEngineSnapshotCopyWith<_OnlineEngineSnapshot> get copyWith => __$OnlineEngineSnapshotCopyWithImpl<_OnlineEngineSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineEngineSnapshot&&(identical(other.year, year) || other.year == year)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.currentPlayer, currentPlayer) || other.currentPlayer == currentPlayer)&&(identical(other.waitingPlayer, waitingPlayer) || other.waitingPlayer == waitingPlayer)&&(identical(other.waitingForExternalAction, waitingForExternalAction) || other.waitingForExternalAction == waitingForExternalAction)&&(identical(other.lead, lead) || other.lead == lead)&&(identical(other.trumpSelector, trumpSelector) || other.trumpSelector == trumpSelector)&&(identical(other.trump, trump) || other.trump == trump)&&(identical(other.trickCount, trickCount) || other.trickCount == trickCount)&&(identical(other.isFamine, isFamine) || other.isFamine == isFamine)&&const DeepCollectionEquality().equals(other._players, _players)&&const DeepCollectionEquality().equals(other._jobPiles, _jobPiles)&&const DeepCollectionEquality().equals(other._revealedJobs, _revealedJobs)&&const DeepCollectionEquality().equals(other._claimedJobs, _claimedJobs)&&const DeepCollectionEquality().equals(other._workHours, _workHours)&&const DeepCollectionEquality().equals(other._jobBuckets, _jobBuckets)&&const DeepCollectionEquality().equals(other._accumulatedJobCards, _accumulatedJobCards)&&const DeepCollectionEquality().equals(other._currentTrick, _currentTrick)&&const DeepCollectionEquality().equals(other._lastTrick, _lastTrick)&&(identical(other.lastWinner, lastWinner) || other.lastWinner == lastWinner)&&const DeepCollectionEquality().equals(other._exiled, _exiled)&&const DeepCollectionEquality().equals(other._exiledPlayers, _exiledPlayers)&&const DeepCollectionEquality().equals(other._pendingAssignments, _pendingAssignments)&&const DeepCollectionEquality().equals(other._requisitionEvents, _requisitionEvents)&&const DeepCollectionEquality().equals(other._scores, _scores)&&(identical(other.winnerID, winnerID) || other.winnerID == winnerID)&&const DeepCollectionEquality().equals(other._swapConfirmed, _swapConfirmed)&&const DeepCollectionEquality().equals(other._swapCount, _swapCount)&&const DeepCollectionEquality().equals(other._passConfirmed, _passConfirmed)&&(identical(other.finalYearTrumpCard, finalYearTrumpCard) || other.finalYearTrumpCard == finalYearTrumpCard));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,year,phase,currentPlayer,waitingPlayer,waitingForExternalAction,lead,trumpSelector,trump,trickCount,isFamine,const DeepCollectionEquality().hash(_players),const DeepCollectionEquality().hash(_jobPiles),const DeepCollectionEquality().hash(_revealedJobs),const DeepCollectionEquality().hash(_claimedJobs),const DeepCollectionEquality().hash(_workHours),const DeepCollectionEquality().hash(_jobBuckets),const DeepCollectionEquality().hash(_accumulatedJobCards),const DeepCollectionEquality().hash(_currentTrick),const DeepCollectionEquality().hash(_lastTrick),lastWinner,const DeepCollectionEquality().hash(_exiled),const DeepCollectionEquality().hash(_exiledPlayers),const DeepCollectionEquality().hash(_pendingAssignments),const DeepCollectionEquality().hash(_requisitionEvents),const DeepCollectionEquality().hash(_scores),winnerID,const DeepCollectionEquality().hash(_swapConfirmed),const DeepCollectionEquality().hash(_swapCount),const DeepCollectionEquality().hash(_passConfirmed),finalYearTrumpCard]);

@override
String toString() {
  return 'OnlineEngineSnapshot(year: $year, phase: $phase, currentPlayer: $currentPlayer, waitingPlayer: $waitingPlayer, waitingForExternalAction: $waitingForExternalAction, lead: $lead, trumpSelector: $trumpSelector, trump: $trump, trickCount: $trickCount, isFamine: $isFamine, players: $players, jobPiles: $jobPiles, revealedJobs: $revealedJobs, claimedJobs: $claimedJobs, workHours: $workHours, jobBuckets: $jobBuckets, accumulatedJobCards: $accumulatedJobCards, currentTrick: $currentTrick, lastTrick: $lastTrick, lastWinner: $lastWinner, exiled: $exiled, exiledPlayers: $exiledPlayers, pendingAssignments: $pendingAssignments, requisitionEvents: $requisitionEvents, scores: $scores, winnerID: $winnerID, swapConfirmed: $swapConfirmed, swapCount: $swapCount, passConfirmed: $passConfirmed, finalYearTrumpCard: $finalYearTrumpCard)';
}


}

/// @nodoc
abstract mixin class _$OnlineEngineSnapshotCopyWith<$Res> implements $OnlineEngineSnapshotCopyWith<$Res> {
  factory _$OnlineEngineSnapshotCopyWith(_OnlineEngineSnapshot value, $Res Function(_OnlineEngineSnapshot) _then) = __$OnlineEngineSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int year, int phase, int currentPlayer, int waitingPlayer, bool waitingForExternalAction, int lead, int trumpSelector, int trump, int trickCount, bool isFamine, List<OnlinePlayerSnapshot> players, List<OnlineSuitCardsSnapshot> jobPiles, List<OnlineSuitCardsSnapshot> revealedJobs, List<int> claimedJobs, List<OnlineSuitValueSnapshot> workHours, List<OnlineSuitCardsSnapshot> jobBuckets, List<OnlineSuitCardsSnapshot> accumulatedJobCards, List<OnlineTrickPlaySnapshot> currentTrick, List<OnlineTrickPlaySnapshot> lastTrick, int lastWinner, List<OnlineSuitCardsSnapshot> exiled, List<OnlineSuitPlayersSnapshot> exiledPlayers, List<OnlineAssignmentSnapshot> pendingAssignments, List<OnlineRequisitionSnapshot> requisitionEvents, List<OnlineScoreSnapshot> scores, int winnerID, List<int> swapConfirmed, List<int> swapCount, List<int> passConfirmed, OnlineEngineCard finalYearTrumpCard
});


@override $OnlineEngineCardCopyWith<$Res> get finalYearTrumpCard;

}
/// @nodoc
class __$OnlineEngineSnapshotCopyWithImpl<$Res>
    implements _$OnlineEngineSnapshotCopyWith<$Res> {
  __$OnlineEngineSnapshotCopyWithImpl(this._self, this._then);

  final _OnlineEngineSnapshot _self;
  final $Res Function(_OnlineEngineSnapshot) _then;

/// Create a copy of OnlineEngineSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? year = null,Object? phase = null,Object? currentPlayer = null,Object? waitingPlayer = null,Object? waitingForExternalAction = null,Object? lead = null,Object? trumpSelector = null,Object? trump = null,Object? trickCount = null,Object? isFamine = null,Object? players = null,Object? jobPiles = null,Object? revealedJobs = null,Object? claimedJobs = null,Object? workHours = null,Object? jobBuckets = null,Object? accumulatedJobCards = null,Object? currentTrick = null,Object? lastTrick = null,Object? lastWinner = null,Object? exiled = null,Object? exiledPlayers = null,Object? pendingAssignments = null,Object? requisitionEvents = null,Object? scores = null,Object? winnerID = null,Object? swapConfirmed = null,Object? swapCount = null,Object? passConfirmed = null,Object? finalYearTrumpCard = null,}) {
  return _then(_OnlineEngineSnapshot(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as int,currentPlayer: null == currentPlayer ? _self.currentPlayer : currentPlayer // ignore: cast_nullable_to_non_nullable
as int,waitingPlayer: null == waitingPlayer ? _self.waitingPlayer : waitingPlayer // ignore: cast_nullable_to_non_nullable
as int,waitingForExternalAction: null == waitingForExternalAction ? _self.waitingForExternalAction : waitingForExternalAction // ignore: cast_nullable_to_non_nullable
as bool,lead: null == lead ? _self.lead : lead // ignore: cast_nullable_to_non_nullable
as int,trumpSelector: null == trumpSelector ? _self.trumpSelector : trumpSelector // ignore: cast_nullable_to_non_nullable
as int,trump: null == trump ? _self.trump : trump // ignore: cast_nullable_to_non_nullable
as int,trickCount: null == trickCount ? _self.trickCount : trickCount // ignore: cast_nullable_to_non_nullable
as int,isFamine: null == isFamine ? _self.isFamine : isFamine // ignore: cast_nullable_to_non_nullable
as bool,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<OnlinePlayerSnapshot>,jobPiles: null == jobPiles ? _self._jobPiles : jobPiles // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,revealedJobs: null == revealedJobs ? _self._revealedJobs : revealedJobs // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,claimedJobs: null == claimedJobs ? _self._claimedJobs : claimedJobs // ignore: cast_nullable_to_non_nullable
as List<int>,workHours: null == workHours ? _self._workHours : workHours // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitValueSnapshot>,jobBuckets: null == jobBuckets ? _self._jobBuckets : jobBuckets // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,accumulatedJobCards: null == accumulatedJobCards ? _self._accumulatedJobCards : accumulatedJobCards // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,currentTrick: null == currentTrick ? _self._currentTrick : currentTrick // ignore: cast_nullable_to_non_nullable
as List<OnlineTrickPlaySnapshot>,lastTrick: null == lastTrick ? _self._lastTrick : lastTrick // ignore: cast_nullable_to_non_nullable
as List<OnlineTrickPlaySnapshot>,lastWinner: null == lastWinner ? _self.lastWinner : lastWinner // ignore: cast_nullable_to_non_nullable
as int,exiled: null == exiled ? _self._exiled : exiled // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitCardsSnapshot>,exiledPlayers: null == exiledPlayers ? _self._exiledPlayers : exiledPlayers // ignore: cast_nullable_to_non_nullable
as List<OnlineSuitPlayersSnapshot>,pendingAssignments: null == pendingAssignments ? _self._pendingAssignments : pendingAssignments // ignore: cast_nullable_to_non_nullable
as List<OnlineAssignmentSnapshot>,requisitionEvents: null == requisitionEvents ? _self._requisitionEvents : requisitionEvents // ignore: cast_nullable_to_non_nullable
as List<OnlineRequisitionSnapshot>,scores: null == scores ? _self._scores : scores // ignore: cast_nullable_to_non_nullable
as List<OnlineScoreSnapshot>,winnerID: null == winnerID ? _self.winnerID : winnerID // ignore: cast_nullable_to_non_nullable
as int,swapConfirmed: null == swapConfirmed ? _self._swapConfirmed : swapConfirmed // ignore: cast_nullable_to_non_nullable
as List<int>,swapCount: null == swapCount ? _self._swapCount : swapCount // ignore: cast_nullable_to_non_nullable
as List<int>,passConfirmed: null == passConfirmed ? _self._passConfirmed : passConfirmed // ignore: cast_nullable_to_non_nullable
as List<int>,finalYearTrumpCard: null == finalYearTrumpCard ? _self.finalYearTrumpCard : finalYearTrumpCard // ignore: cast_nullable_to_non_nullable
as OnlineEngineCard,
  ));
}

/// Create a copy of OnlineEngineSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineEngineCardCopyWith<$Res> get finalYearTrumpCard {
  
  return $OnlineEngineCardCopyWith<$Res>(_self.finalYearTrumpCard, (value) {
    return _then(_self.copyWith(finalYearTrumpCard: value));
  });
}
}

// dart format on
