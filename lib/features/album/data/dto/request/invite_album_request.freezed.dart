// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_album_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InviteAlbumRequest {

 String get role;
/// Create a copy of InviteAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteAlbumRequestCopyWith<InviteAlbumRequest> get copyWith => _$InviteAlbumRequestCopyWithImpl<InviteAlbumRequest>(this as InviteAlbumRequest, _$identity);

  /// Serializes this InviteAlbumRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteAlbumRequest&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role);

@override
String toString() {
  return 'InviteAlbumRequest(role: $role)';
}


}

/// @nodoc
abstract mixin class $InviteAlbumRequestCopyWith<$Res>  {
  factory $InviteAlbumRequestCopyWith(InviteAlbumRequest value, $Res Function(InviteAlbumRequest) _then) = _$InviteAlbumRequestCopyWithImpl;
@useResult
$Res call({
 String role
});




}
/// @nodoc
class _$InviteAlbumRequestCopyWithImpl<$Res>
    implements $InviteAlbumRequestCopyWith<$Res> {
  _$InviteAlbumRequestCopyWithImpl(this._self, this._then);

  final InviteAlbumRequest _self;
  final $Res Function(InviteAlbumRequest) _then;

/// Create a copy of InviteAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteAlbumRequest].
extension InviteAlbumRequestPatterns on InviteAlbumRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteAlbumRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteAlbumRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteAlbumRequest value)  $default,){
final _that = this;
switch (_that) {
case _InviteAlbumRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteAlbumRequest value)?  $default,){
final _that = this;
switch (_that) {
case _InviteAlbumRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteAlbumRequest() when $default != null:
return $default(_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String role)  $default,) {final _that = this;
switch (_that) {
case _InviteAlbumRequest():
return $default(_that.role);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String role)?  $default,) {final _that = this;
switch (_that) {
case _InviteAlbumRequest() when $default != null:
return $default(_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InviteAlbumRequest implements InviteAlbumRequest {
  const _InviteAlbumRequest({this.role = 'EDITOR'});
  factory _InviteAlbumRequest.fromJson(Map<String, dynamic> json) => _$InviteAlbumRequestFromJson(json);

@override@JsonKey() final  String role;

/// Create a copy of InviteAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteAlbumRequestCopyWith<_InviteAlbumRequest> get copyWith => __$InviteAlbumRequestCopyWithImpl<_InviteAlbumRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteAlbumRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteAlbumRequest&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role);

@override
String toString() {
  return 'InviteAlbumRequest(role: $role)';
}


}

/// @nodoc
abstract mixin class _$InviteAlbumRequestCopyWith<$Res> implements $InviteAlbumRequestCopyWith<$Res> {
  factory _$InviteAlbumRequestCopyWith(_InviteAlbumRequest value, $Res Function(_InviteAlbumRequest) _then) = __$InviteAlbumRequestCopyWithImpl;
@override @useResult
$Res call({
 String role
});




}
/// @nodoc
class __$InviteAlbumRequestCopyWithImpl<$Res>
    implements _$InviteAlbumRequestCopyWith<$Res> {
  __$InviteAlbumRequestCopyWithImpl(this._self, this._then);

  final _InviteAlbumRequest _self;
  final $Res Function(_InviteAlbumRequest) _then;

/// Create a copy of InviteAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,}) {
  return _then(_InviteAlbumRequest(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
