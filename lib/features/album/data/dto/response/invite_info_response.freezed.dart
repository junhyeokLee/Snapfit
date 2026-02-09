// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_info_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InviteInfoResponse {

 int get albumId; String get albumTitle; String get inviterName; String get role;
/// Create a copy of InviteInfoResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteInfoResponseCopyWith<InviteInfoResponse> get copyWith => _$InviteInfoResponseCopyWithImpl<InviteInfoResponse>(this as InviteInfoResponse, _$identity);

  /// Serializes this InviteInfoResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteInfoResponse&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.albumTitle, albumTitle) || other.albumTitle == albumTitle)&&(identical(other.inviterName, inviterName) || other.inviterName == inviterName)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,albumId,albumTitle,inviterName,role);

@override
String toString() {
  return 'InviteInfoResponse(albumId: $albumId, albumTitle: $albumTitle, inviterName: $inviterName, role: $role)';
}


}

/// @nodoc
abstract mixin class $InviteInfoResponseCopyWith<$Res>  {
  factory $InviteInfoResponseCopyWith(InviteInfoResponse value, $Res Function(InviteInfoResponse) _then) = _$InviteInfoResponseCopyWithImpl;
@useResult
$Res call({
 int albumId, String albumTitle, String inviterName, String role
});




}
/// @nodoc
class _$InviteInfoResponseCopyWithImpl<$Res>
    implements $InviteInfoResponseCopyWith<$Res> {
  _$InviteInfoResponseCopyWithImpl(this._self, this._then);

  final InviteInfoResponse _self;
  final $Res Function(InviteInfoResponse) _then;

/// Create a copy of InviteInfoResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? albumId = null,Object? albumTitle = null,Object? inviterName = null,Object? role = null,}) {
  return _then(_self.copyWith(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as int,albumTitle: null == albumTitle ? _self.albumTitle : albumTitle // ignore: cast_nullable_to_non_nullable
as String,inviterName: null == inviterName ? _self.inviterName : inviterName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteInfoResponse].
extension InviteInfoResponsePatterns on InviteInfoResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteInfoResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteInfoResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteInfoResponse value)  $default,){
final _that = this;
switch (_that) {
case _InviteInfoResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteInfoResponse value)?  $default,){
final _that = this;
switch (_that) {
case _InviteInfoResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int albumId,  String albumTitle,  String inviterName,  String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteInfoResponse() when $default != null:
return $default(_that.albumId,_that.albumTitle,_that.inviterName,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int albumId,  String albumTitle,  String inviterName,  String role)  $default,) {final _that = this;
switch (_that) {
case _InviteInfoResponse():
return $default(_that.albumId,_that.albumTitle,_that.inviterName,_that.role);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int albumId,  String albumTitle,  String inviterName,  String role)?  $default,) {final _that = this;
switch (_that) {
case _InviteInfoResponse() when $default != null:
return $default(_that.albumId,_that.albumTitle,_that.inviterName,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InviteInfoResponse implements InviteInfoResponse {
  const _InviteInfoResponse({required this.albumId, required this.albumTitle, required this.inviterName, required this.role});
  factory _InviteInfoResponse.fromJson(Map<String, dynamic> json) => _$InviteInfoResponseFromJson(json);

@override final  int albumId;
@override final  String albumTitle;
@override final  String inviterName;
@override final  String role;

/// Create a copy of InviteInfoResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteInfoResponseCopyWith<_InviteInfoResponse> get copyWith => __$InviteInfoResponseCopyWithImpl<_InviteInfoResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteInfoResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteInfoResponse&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.albumTitle, albumTitle) || other.albumTitle == albumTitle)&&(identical(other.inviterName, inviterName) || other.inviterName == inviterName)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,albumId,albumTitle,inviterName,role);

@override
String toString() {
  return 'InviteInfoResponse(albumId: $albumId, albumTitle: $albumTitle, inviterName: $inviterName, role: $role)';
}


}

/// @nodoc
abstract mixin class _$InviteInfoResponseCopyWith<$Res> implements $InviteInfoResponseCopyWith<$Res> {
  factory _$InviteInfoResponseCopyWith(_InviteInfoResponse value, $Res Function(_InviteInfoResponse) _then) = __$InviteInfoResponseCopyWithImpl;
@override @useResult
$Res call({
 int albumId, String albumTitle, String inviterName, String role
});




}
/// @nodoc
class __$InviteInfoResponseCopyWithImpl<$Res>
    implements _$InviteInfoResponseCopyWith<$Res> {
  __$InviteInfoResponseCopyWithImpl(this._self, this._then);

  final _InviteInfoResponse _self;
  final $Res Function(_InviteInfoResponse) _then;

/// Create a copy of InviteInfoResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? albumId = null,Object? albumTitle = null,Object? inviterName = null,Object? role = null,}) {
  return _then(_InviteInfoResponse(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as int,albumTitle: null == albumTitle ? _self.albumTitle : albumTitle // ignore: cast_nullable_to_non_nullable
as String,inviterName: null == inviterName ? _self.inviterName : inviterName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
