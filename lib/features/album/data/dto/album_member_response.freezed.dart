// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'album_member_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AlbumMemberResponse {

 int get id; int get userId; String? get userName; String? get userEmail; String? get profileImageUrl; String get role; String get status;
/// Create a copy of AlbumMemberResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumMemberResponseCopyWith<AlbumMemberResponse> get copyWith => _$AlbumMemberResponseCopyWithImpl<AlbumMemberResponse>(this as AlbumMemberResponse, _$identity);

  /// Serializes this AlbumMemberResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlbumMemberResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userEmail, userEmail) || other.userEmail == userEmail)&&(identical(other.profileImageUrl, profileImageUrl) || other.profileImageUrl == profileImageUrl)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,userName,userEmail,profileImageUrl,role,status);

@override
String toString() {
  return 'AlbumMemberResponse(id: $id, userId: $userId, userName: $userName, userEmail: $userEmail, profileImageUrl: $profileImageUrl, role: $role, status: $status)';
}


}

/// @nodoc
abstract mixin class $AlbumMemberResponseCopyWith<$Res>  {
  factory $AlbumMemberResponseCopyWith(AlbumMemberResponse value, $Res Function(AlbumMemberResponse) _then) = _$AlbumMemberResponseCopyWithImpl;
@useResult
$Res call({
 int id, int userId, String? userName, String? userEmail, String? profileImageUrl, String role, String status
});




}
/// @nodoc
class _$AlbumMemberResponseCopyWithImpl<$Res>
    implements $AlbumMemberResponseCopyWith<$Res> {
  _$AlbumMemberResponseCopyWithImpl(this._self, this._then);

  final AlbumMemberResponse _self;
  final $Res Function(AlbumMemberResponse) _then;

/// Create a copy of AlbumMemberResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? userName = freezed,Object? userEmail = freezed,Object? profileImageUrl = freezed,Object? role = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,userEmail: freezed == userEmail ? _self.userEmail : userEmail // ignore: cast_nullable_to_non_nullable
as String?,profileImageUrl: freezed == profileImageUrl ? _self.profileImageUrl : profileImageUrl // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AlbumMemberResponse].
extension AlbumMemberResponsePatterns on AlbumMemberResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlbumMemberResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlbumMemberResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlbumMemberResponse value)  $default,){
final _that = this;
switch (_that) {
case _AlbumMemberResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlbumMemberResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AlbumMemberResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  String? userName,  String? userEmail,  String? profileImageUrl,  String role,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlbumMemberResponse() when $default != null:
return $default(_that.id,_that.userId,_that.userName,_that.userEmail,_that.profileImageUrl,_that.role,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  String? userName,  String? userEmail,  String? profileImageUrl,  String role,  String status)  $default,) {final _that = this;
switch (_that) {
case _AlbumMemberResponse():
return $default(_that.id,_that.userId,_that.userName,_that.userEmail,_that.profileImageUrl,_that.role,_that.status);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  String? userName,  String? userEmail,  String? profileImageUrl,  String role,  String status)?  $default,) {final _that = this;
switch (_that) {
case _AlbumMemberResponse() when $default != null:
return $default(_that.id,_that.userId,_that.userName,_that.userEmail,_that.profileImageUrl,_that.role,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlbumMemberResponse implements AlbumMemberResponse {
  const _AlbumMemberResponse({required this.id, required this.userId, this.userName, this.userEmail, this.profileImageUrl, required this.role, required this.status});
  factory _AlbumMemberResponse.fromJson(Map<String, dynamic> json) => _$AlbumMemberResponseFromJson(json);

@override final  int id;
@override final  int userId;
@override final  String? userName;
@override final  String? userEmail;
@override final  String? profileImageUrl;
@override final  String role;
@override final  String status;

/// Create a copy of AlbumMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumMemberResponseCopyWith<_AlbumMemberResponse> get copyWith => __$AlbumMemberResponseCopyWithImpl<_AlbumMemberResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlbumMemberResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlbumMemberResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userEmail, userEmail) || other.userEmail == userEmail)&&(identical(other.profileImageUrl, profileImageUrl) || other.profileImageUrl == profileImageUrl)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,userName,userEmail,profileImageUrl,role,status);

@override
String toString() {
  return 'AlbumMemberResponse(id: $id, userId: $userId, userName: $userName, userEmail: $userEmail, profileImageUrl: $profileImageUrl, role: $role, status: $status)';
}


}

/// @nodoc
abstract mixin class _$AlbumMemberResponseCopyWith<$Res> implements $AlbumMemberResponseCopyWith<$Res> {
  factory _$AlbumMemberResponseCopyWith(_AlbumMemberResponse value, $Res Function(_AlbumMemberResponse) _then) = __$AlbumMemberResponseCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, String? userName, String? userEmail, String? profileImageUrl, String role, String status
});




}
/// @nodoc
class __$AlbumMemberResponseCopyWithImpl<$Res>
    implements _$AlbumMemberResponseCopyWith<$Res> {
  __$AlbumMemberResponseCopyWithImpl(this._self, this._then);

  final _AlbumMemberResponse _self;
  final $Res Function(_AlbumMemberResponse) _then;

/// Create a copy of AlbumMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? userName = freezed,Object? userEmail = freezed,Object? profileImageUrl = freezed,Object? role = null,Object? status = null,}) {
  return _then(_AlbumMemberResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,userEmail: freezed == userEmail ? _self.userEmail : userEmail // ignore: cast_nullable_to_non_nullable
as String?,profileImageUrl: freezed == profileImageUrl ? _self.profileImageUrl : profileImageUrl // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
