// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_link_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InviteLinkResponse {

 int get albumId; String get token; String get link;
/// Create a copy of InviteLinkResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteLinkResponseCopyWith<InviteLinkResponse> get copyWith => _$InviteLinkResponseCopyWithImpl<InviteLinkResponse>(this as InviteLinkResponse, _$identity);

  /// Serializes this InviteLinkResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteLinkResponse&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.token, token) || other.token == token)&&(identical(other.link, link) || other.link == link));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,albumId,token,link);

@override
String toString() {
  return 'InviteLinkResponse(albumId: $albumId, token: $token, link: $link)';
}


}

/// @nodoc
abstract mixin class $InviteLinkResponseCopyWith<$Res>  {
  factory $InviteLinkResponseCopyWith(InviteLinkResponse value, $Res Function(InviteLinkResponse) _then) = _$InviteLinkResponseCopyWithImpl;
@useResult
$Res call({
 int albumId, String token, String link
});




}
/// @nodoc
class _$InviteLinkResponseCopyWithImpl<$Res>
    implements $InviteLinkResponseCopyWith<$Res> {
  _$InviteLinkResponseCopyWithImpl(this._self, this._then);

  final InviteLinkResponse _self;
  final $Res Function(InviteLinkResponse) _then;

/// Create a copy of InviteLinkResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? albumId = null,Object? token = null,Object? link = null,}) {
  return _then(_self.copyWith(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteLinkResponse].
extension InviteLinkResponsePatterns on InviteLinkResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteLinkResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteLinkResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteLinkResponse value)  $default,){
final _that = this;
switch (_that) {
case _InviteLinkResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteLinkResponse value)?  $default,){
final _that = this;
switch (_that) {
case _InviteLinkResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int albumId,  String token,  String link)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteLinkResponse() when $default != null:
return $default(_that.albumId,_that.token,_that.link);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int albumId,  String token,  String link)  $default,) {final _that = this;
switch (_that) {
case _InviteLinkResponse():
return $default(_that.albumId,_that.token,_that.link);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int albumId,  String token,  String link)?  $default,) {final _that = this;
switch (_that) {
case _InviteLinkResponse() when $default != null:
return $default(_that.albumId,_that.token,_that.link);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InviteLinkResponse implements InviteLinkResponse {
  const _InviteLinkResponse({required this.albumId, required this.token, required this.link});
  factory _InviteLinkResponse.fromJson(Map<String, dynamic> json) => _$InviteLinkResponseFromJson(json);

@override final  int albumId;
@override final  String token;
@override final  String link;

/// Create a copy of InviteLinkResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteLinkResponseCopyWith<_InviteLinkResponse> get copyWith => __$InviteLinkResponseCopyWithImpl<_InviteLinkResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteLinkResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteLinkResponse&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.token, token) || other.token == token)&&(identical(other.link, link) || other.link == link));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,albumId,token,link);

@override
String toString() {
  return 'InviteLinkResponse(albumId: $albumId, token: $token, link: $link)';
}


}

/// @nodoc
abstract mixin class _$InviteLinkResponseCopyWith<$Res> implements $InviteLinkResponseCopyWith<$Res> {
  factory _$InviteLinkResponseCopyWith(_InviteLinkResponse value, $Res Function(_InviteLinkResponse) _then) = __$InviteLinkResponseCopyWithImpl;
@override @useResult
$Res call({
 int albumId, String token, String link
});




}
/// @nodoc
class __$InviteLinkResponseCopyWithImpl<$Res>
    implements _$InviteLinkResponseCopyWith<$Res> {
  __$InviteLinkResponseCopyWithImpl(this._self, this._then);

  final _InviteLinkResponse _self;
  final $Res Function(_InviteLinkResponse) _then;

/// Create a copy of InviteLinkResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? albumId = null,Object? token = null,Object? link = null,}) {
  return _then(_InviteLinkResponse(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
