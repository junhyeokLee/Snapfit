// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cover_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoverState {

 CoverSize get selectedCover; CoverTheme get selectedTheme;
/// Create a copy of CoverState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoverStateCopyWith<CoverState> get copyWith => _$CoverStateCopyWithImpl<CoverState>(this as CoverState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoverState&&const DeepCollectionEquality().equals(other.selectedCover, selectedCover)&&const DeepCollectionEquality().equals(other.selectedTheme, selectedTheme));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(selectedCover),const DeepCollectionEquality().hash(selectedTheme));

@override
String toString() {
  return 'CoverState(selectedCover: $selectedCover, selectedTheme: $selectedTheme)';
}


}

/// @nodoc
abstract mixin class $CoverStateCopyWith<$Res>  {
  factory $CoverStateCopyWith(CoverState value, $Res Function(CoverState) _then) = _$CoverStateCopyWithImpl;
@useResult
$Res call({
 CoverSize selectedCover, CoverTheme selectedTheme
});




}
/// @nodoc
class _$CoverStateCopyWithImpl<$Res>
    implements $CoverStateCopyWith<$Res> {
  _$CoverStateCopyWithImpl(this._self, this._then);

  final CoverState _self;
  final $Res Function(CoverState) _then;

/// Create a copy of CoverState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedCover = freezed,Object? selectedTheme = freezed,}) {
  return _then(_self.copyWith(
selectedCover: freezed == selectedCover ? _self.selectedCover : selectedCover // ignore: cast_nullable_to_non_nullable
as CoverSize,selectedTheme: freezed == selectedTheme ? _self.selectedTheme : selectedTheme // ignore: cast_nullable_to_non_nullable
as CoverTheme,
  ));
}

}


/// Adds pattern-matching-related methods to [CoverState].
extension CoverStatePatterns on CoverState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoverState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoverState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoverState value)  $default,){
final _that = this;
switch (_that) {
case _CoverState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoverState value)?  $default,){
final _that = this;
switch (_that) {
case _CoverState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CoverSize selectedCover,  CoverTheme selectedTheme)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoverState() when $default != null:
return $default(_that.selectedCover,_that.selectedTheme);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CoverSize selectedCover,  CoverTheme selectedTheme)  $default,) {final _that = this;
switch (_that) {
case _CoverState():
return $default(_that.selectedCover,_that.selectedTheme);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CoverSize selectedCover,  CoverTheme selectedTheme)?  $default,) {final _that = this;
switch (_that) {
case _CoverState() when $default != null:
return $default(_that.selectedCover,_that.selectedTheme);case _:
  return null;

}
}

}

/// @nodoc


class _CoverState implements CoverState {
  const _CoverState({this.selectedCover = const CoverSize(name: '세로형', ratio: 6 / 8, realSize: Size(14.5, 19.4)), this.selectedTheme = CoverTheme.classic});
  

@override@JsonKey() final  CoverSize selectedCover;
@override@JsonKey() final  CoverTheme selectedTheme;

/// Create a copy of CoverState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoverStateCopyWith<_CoverState> get copyWith => __$CoverStateCopyWithImpl<_CoverState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoverState&&const DeepCollectionEquality().equals(other.selectedCover, selectedCover)&&const DeepCollectionEquality().equals(other.selectedTheme, selectedTheme));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(selectedCover),const DeepCollectionEquality().hash(selectedTheme));

@override
String toString() {
  return 'CoverState(selectedCover: $selectedCover, selectedTheme: $selectedTheme)';
}


}

/// @nodoc
abstract mixin class _$CoverStateCopyWith<$Res> implements $CoverStateCopyWith<$Res> {
  factory _$CoverStateCopyWith(_CoverState value, $Res Function(_CoverState) _then) = __$CoverStateCopyWithImpl;
@override @useResult
$Res call({
 CoverSize selectedCover, CoverTheme selectedTheme
});




}
/// @nodoc
class __$CoverStateCopyWithImpl<$Res>
    implements _$CoverStateCopyWith<$Res> {
  __$CoverStateCopyWithImpl(this._self, this._then);

  final _CoverState _self;
  final $Res Function(_CoverState) _then;

/// Create a copy of CoverState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedCover = freezed,Object? selectedTheme = freezed,}) {
  return _then(_CoverState(
selectedCover: freezed == selectedCover ? _self.selectedCover : selectedCover // ignore: cast_nullable_to_non_nullable
as CoverSize,selectedTheme: freezed == selectedTheme ? _self.selectedTheme : selectedTheme // ignore: cast_nullable_to_non_nullable
as CoverTheme,
  ));
}


}

// dart format on
