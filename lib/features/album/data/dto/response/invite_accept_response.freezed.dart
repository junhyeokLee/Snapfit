// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_accept_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InviteAcceptResponse {

 int get albumId; String get role; bool get success;
/// Create a copy of InviteAcceptResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteAcceptResponseCopyWith<InviteAcceptResponse> get copyWith => _$InviteAcceptResponseCopyWithImpl<InviteAcceptResponse>(this as InviteAcceptResponse, _$identity);

  /// Serializes this InviteAcceptResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteAcceptResponse&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.role, role) || other.role == role)&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,albumId,role,success);

@override
String toString() {
  return 'InviteAcceptResponse(albumId: $albumId, role: $role, success: $success)';
}


}

/// @nodoc
abstract mixin class $InviteAcceptResponseCopyWith<$Res>  {
  factory $InviteAcceptResponseCopyWith(InviteAcceptResponse value, $Res Function(InviteAcceptResponse) _then) = _$InviteAcceptResponseCopyWithImpl;
@useResult
$Res call({
 int albumId, String role, bool success
});




}
/// @nodoc
class _$InviteAcceptResponseCopyWithImpl<$Res>
    implements $InviteAcceptResponseCopyWith<$Res> {
  _$InviteAcceptResponseCopyWithImpl(this._self, this._then);

  final InviteAcceptResponse _self;
  final $Res Function(InviteAcceptResponse) _then;

/// Create a copy of InviteAcceptResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? albumId = null,Object? role = null,Object? success = null,}) {
  return _then(_self.copyWith(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as int,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteAcceptResponse].
extension InviteAcceptResponsePatterns on InviteAcceptResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteAcceptResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteAcceptResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteAcceptResponse value)  $default,){
final _that = this;
switch (_that) {
case _InviteAcceptResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteAcceptResponse value)?  $default,){
final _that = this;
switch (_that) {
case _InviteAcceptResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int albumId,  String role,  bool success)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteAcceptResponse() when $default != null:
return $default(_that.albumId,_that.role,_that.success);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int albumId,  String role,  bool success)  $default,) {final _that = this;
switch (_that) {
case _InviteAcceptResponse():
return $default(_that.albumId,_that.role,_that.success);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int albumId,  String role,  bool success)?  $default,) {final _that = this;
switch (_that) {
case _InviteAcceptResponse() when $default != null:
return $default(_that.albumId,_that.role,_that.success);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InviteAcceptResponse implements InviteAcceptResponse {
  const _InviteAcceptResponse({required this.albumId, required this.role, required this.success});
  factory _InviteAcceptResponse.fromJson(Map<String, dynamic> json) => _$InviteAcceptResponseFromJson(json);

@override final  int albumId;
@override final  String role;
@override final  bool success;

/// Create a copy of InviteAcceptResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteAcceptResponseCopyWith<_InviteAcceptResponse> get copyWith => __$InviteAcceptResponseCopyWithImpl<_InviteAcceptResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteAcceptResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteAcceptResponse&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.role, role) || other.role == role)&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,albumId,role,success);

@override
String toString() {
  return 'InviteAcceptResponse(albumId: $albumId, role: $role, success: $success)';
}


}

/// @nodoc
abstract mixin class _$InviteAcceptResponseCopyWith<$Res> implements $InviteAcceptResponseCopyWith<$Res> {
  factory _$InviteAcceptResponseCopyWith(_InviteAcceptResponse value, $Res Function(_InviteAcceptResponse) _then) = __$InviteAcceptResponseCopyWithImpl;
@override @useResult
$Res call({
 int albumId, String role, bool success
});




}
/// @nodoc
class __$InviteAcceptResponseCopyWithImpl<$Res>
    implements _$InviteAcceptResponseCopyWith<$Res> {
  __$InviteAcceptResponseCopyWithImpl(this._self, this._then);

  final _InviteAcceptResponse _self;
  final $Res Function(_InviteAcceptResponse) _then;

/// Create a copy of InviteAcceptResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? albumId = null,Object? role = null,Object? success = null,}) {
  return _then(_InviteAcceptResponse(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as int,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
