// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'create_album_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateAlbumRequest {

 String get coverLayersJson; double get coverRatio;
/// Create a copy of CreateAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateAlbumRequestCopyWith<CreateAlbumRequest> get copyWith => _$CreateAlbumRequestCopyWithImpl<CreateAlbumRequest>(this as CreateAlbumRequest, _$identity);

  /// Serializes this CreateAlbumRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateAlbumRequest&&(identical(other.coverLayersJson, coverLayersJson) || other.coverLayersJson == coverLayersJson)&&(identical(other.coverRatio, coverRatio) || other.coverRatio == coverRatio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,coverLayersJson,coverRatio);

@override
String toString() {
  return 'CreateAlbumRequest(coverLayersJson: $coverLayersJson, coverRatio: $coverRatio)';
}


}

/// @nodoc
abstract mixin class $CreateAlbumRequestCopyWith<$Res>  {
  factory $CreateAlbumRequestCopyWith(CreateAlbumRequest value, $Res Function(CreateAlbumRequest) _then) = _$CreateAlbumRequestCopyWithImpl;
@useResult
$Res call({
 String coverLayersJson, double coverRatio
});




}
/// @nodoc
class _$CreateAlbumRequestCopyWithImpl<$Res>
    implements $CreateAlbumRequestCopyWith<$Res> {
  _$CreateAlbumRequestCopyWithImpl(this._self, this._then);

  final CreateAlbumRequest _self;
  final $Res Function(CreateAlbumRequest) _then;

/// Create a copy of CreateAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? coverLayersJson = null,Object? coverRatio = null,}) {
  return _then(_self.copyWith(
coverLayersJson: null == coverLayersJson ? _self.coverLayersJson : coverLayersJson // ignore: cast_nullable_to_non_nullable
as String,coverRatio: null == coverRatio ? _self.coverRatio : coverRatio // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateAlbumRequest].
extension CreateAlbumRequestPatterns on CreateAlbumRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateAlbumRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateAlbumRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateAlbumRequest value)  $default,){
final _that = this;
switch (_that) {
case _CreateAlbumRequest():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateAlbumRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CreateAlbumRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String coverLayersJson,  double coverRatio)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateAlbumRequest() when $default != null:
return $default(_that.coverLayersJson,_that.coverRatio);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String coverLayersJson,  double coverRatio)  $default,) {final _that = this;
switch (_that) {
case _CreateAlbumRequest():
return $default(_that.coverLayersJson,_that.coverRatio);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String coverLayersJson,  double coverRatio)?  $default,) {final _that = this;
switch (_that) {
case _CreateAlbumRequest() when $default != null:
return $default(_that.coverLayersJson,_that.coverRatio);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateAlbumRequest implements CreateAlbumRequest {
  const _CreateAlbumRequest({required this.coverLayersJson, required this.coverRatio});
  factory _CreateAlbumRequest.fromJson(Map<String, dynamic> json) => _$CreateAlbumRequestFromJson(json);

@override final  String coverLayersJson;
@override final  double coverRatio;

/// Create a copy of CreateAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateAlbumRequestCopyWith<_CreateAlbumRequest> get copyWith => __$CreateAlbumRequestCopyWithImpl<_CreateAlbumRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateAlbumRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateAlbumRequest&&(identical(other.coverLayersJson, coverLayersJson) || other.coverLayersJson == coverLayersJson)&&(identical(other.coverRatio, coverRatio) || other.coverRatio == coverRatio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,coverLayersJson,coverRatio);

@override
String toString() {
  return 'CreateAlbumRequest(coverLayersJson: $coverLayersJson, coverRatio: $coverRatio)';
}


}

/// @nodoc
abstract mixin class _$CreateAlbumRequestCopyWith<$Res> implements $CreateAlbumRequestCopyWith<$Res> {
  factory _$CreateAlbumRequestCopyWith(_CreateAlbumRequest value, $Res Function(_CreateAlbumRequest) _then) = __$CreateAlbumRequestCopyWithImpl;
@override @useResult
$Res call({
 String coverLayersJson, double coverRatio
});




}
/// @nodoc
class __$CreateAlbumRequestCopyWithImpl<$Res>
    implements _$CreateAlbumRequestCopyWith<$Res> {
  __$CreateAlbumRequestCopyWithImpl(this._self, this._then);

  final _CreateAlbumRequest _self;
  final $Res Function(_CreateAlbumRequest) _then;

/// Create a copy of CreateAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? coverLayersJson = null,Object? coverRatio = null,}) {
  return _then(_CreateAlbumRequest(
coverLayersJson: null == coverLayersJson ? _self.coverLayersJson : coverLayersJson // ignore: cast_nullable_to_non_nullable
as String,coverRatio: null == coverRatio ? _self.coverRatio : coverRatio // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
