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

/// 서버 식별자 (로그인 없이도 설치 단위로 고정)
/// - Repository에서 자동 주입하므로 호출부에서는 비워둬도 됨
// ignore: invalid_annotation_target
@JsonKey(name: 'userId') String get userId; String get ratio; String get coverLayersJson; String get coverImageUrl; String get coverThumbnailUrl;/// 운영급: 커버 원본/미리보기 URL (하위 호환: 없으면 coverImageUrl을 preview로 간주)
 String? get coverOriginalUrl; String? get coverPreviewUrl; String get coverTheme;
/// Create a copy of CreateAlbumRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateAlbumRequestCopyWith<CreateAlbumRequest> get copyWith => _$CreateAlbumRequestCopyWithImpl<CreateAlbumRequest>(this as CreateAlbumRequest, _$identity);

  /// Serializes this CreateAlbumRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateAlbumRequest&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.ratio, ratio) || other.ratio == ratio)&&(identical(other.coverLayersJson, coverLayersJson) || other.coverLayersJson == coverLayersJson)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.coverThumbnailUrl, coverThumbnailUrl) || other.coverThumbnailUrl == coverThumbnailUrl)&&(identical(other.coverOriginalUrl, coverOriginalUrl) || other.coverOriginalUrl == coverOriginalUrl)&&(identical(other.coverPreviewUrl, coverPreviewUrl) || other.coverPreviewUrl == coverPreviewUrl)&&(identical(other.coverTheme, coverTheme) || other.coverTheme == coverTheme));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,ratio,coverLayersJson,coverImageUrl,coverThumbnailUrl,coverOriginalUrl,coverPreviewUrl,coverTheme);

@override
String toString() {
  return 'CreateAlbumRequest(userId: $userId, ratio: $ratio, coverLayersJson: $coverLayersJson, coverImageUrl: $coverImageUrl, coverThumbnailUrl: $coverThumbnailUrl, coverOriginalUrl: $coverOriginalUrl, coverPreviewUrl: $coverPreviewUrl, coverTheme: $coverTheme)';
}


}

/// @nodoc
abstract mixin class $CreateAlbumRequestCopyWith<$Res>  {
  factory $CreateAlbumRequestCopyWith(CreateAlbumRequest value, $Res Function(CreateAlbumRequest) _then) = _$CreateAlbumRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'userId') String userId, String ratio, String coverLayersJson, String coverImageUrl, String coverThumbnailUrl, String? coverOriginalUrl, String? coverPreviewUrl, String coverTheme
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
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? ratio = null,Object? coverLayersJson = null,Object? coverImageUrl = null,Object? coverThumbnailUrl = null,Object? coverOriginalUrl = freezed,Object? coverPreviewUrl = freezed,Object? coverTheme = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as String,coverLayersJson: null == coverLayersJson ? _self.coverLayersJson : coverLayersJson // ignore: cast_nullable_to_non_nullable
as String,coverImageUrl: null == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String,coverThumbnailUrl: null == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,coverOriginalUrl: freezed == coverOriginalUrl ? _self.coverOriginalUrl : coverOriginalUrl // ignore: cast_nullable_to_non_nullable
as String?,coverPreviewUrl: freezed == coverPreviewUrl ? _self.coverPreviewUrl : coverPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,coverTheme: null == coverTheme ? _self.coverTheme : coverTheme // ignore: cast_nullable_to_non_nullable
as String,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'userId')  String userId,  String ratio,  String coverLayersJson,  String coverImageUrl,  String coverThumbnailUrl,  String? coverOriginalUrl,  String? coverPreviewUrl,  String coverTheme)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateAlbumRequest() when $default != null:
return $default(_that.userId,_that.ratio,_that.coverLayersJson,_that.coverImageUrl,_that.coverThumbnailUrl,_that.coverOriginalUrl,_that.coverPreviewUrl,_that.coverTheme);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'userId')  String userId,  String ratio,  String coverLayersJson,  String coverImageUrl,  String coverThumbnailUrl,  String? coverOriginalUrl,  String? coverPreviewUrl,  String coverTheme)  $default,) {final _that = this;
switch (_that) {
case _CreateAlbumRequest():
return $default(_that.userId,_that.ratio,_that.coverLayersJson,_that.coverImageUrl,_that.coverThumbnailUrl,_that.coverOriginalUrl,_that.coverPreviewUrl,_that.coverTheme);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'userId')  String userId,  String ratio,  String coverLayersJson,  String coverImageUrl,  String coverThumbnailUrl,  String? coverOriginalUrl,  String? coverPreviewUrl,  String coverTheme)?  $default,) {final _that = this;
switch (_that) {
case _CreateAlbumRequest() when $default != null:
return $default(_that.userId,_that.ratio,_that.coverLayersJson,_that.coverImageUrl,_that.coverThumbnailUrl,_that.coverOriginalUrl,_that.coverPreviewUrl,_that.coverTheme);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateAlbumRequest implements CreateAlbumRequest {
  const _CreateAlbumRequest({@JsonKey(name: 'userId') this.userId = '', required this.ratio, required this.coverLayersJson, required this.coverImageUrl, required this.coverThumbnailUrl, this.coverOriginalUrl, this.coverPreviewUrl, this.coverTheme = ''});
  factory _CreateAlbumRequest.fromJson(Map<String, dynamic> json) => _$CreateAlbumRequestFromJson(json);

/// 서버 식별자 (로그인 없이도 설치 단위로 고정)
/// - Repository에서 자동 주입하므로 호출부에서는 비워둬도 됨
// ignore: invalid_annotation_target
@override@JsonKey(name: 'userId') final  String userId;
@override final  String ratio;
@override final  String coverLayersJson;
@override final  String coverImageUrl;
@override final  String coverThumbnailUrl;
/// 운영급: 커버 원본/미리보기 URL (하위 호환: 없으면 coverImageUrl을 preview로 간주)
@override final  String? coverOriginalUrl;
@override final  String? coverPreviewUrl;
@override@JsonKey() final  String coverTheme;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateAlbumRequest&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.ratio, ratio) || other.ratio == ratio)&&(identical(other.coverLayersJson, coverLayersJson) || other.coverLayersJson == coverLayersJson)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.coverThumbnailUrl, coverThumbnailUrl) || other.coverThumbnailUrl == coverThumbnailUrl)&&(identical(other.coverOriginalUrl, coverOriginalUrl) || other.coverOriginalUrl == coverOriginalUrl)&&(identical(other.coverPreviewUrl, coverPreviewUrl) || other.coverPreviewUrl == coverPreviewUrl)&&(identical(other.coverTheme, coverTheme) || other.coverTheme == coverTheme));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,ratio,coverLayersJson,coverImageUrl,coverThumbnailUrl,coverOriginalUrl,coverPreviewUrl,coverTheme);

@override
String toString() {
  return 'CreateAlbumRequest(userId: $userId, ratio: $ratio, coverLayersJson: $coverLayersJson, coverImageUrl: $coverImageUrl, coverThumbnailUrl: $coverThumbnailUrl, coverOriginalUrl: $coverOriginalUrl, coverPreviewUrl: $coverPreviewUrl, coverTheme: $coverTheme)';
}


}

/// @nodoc
abstract mixin class _$CreateAlbumRequestCopyWith<$Res> implements $CreateAlbumRequestCopyWith<$Res> {
  factory _$CreateAlbumRequestCopyWith(_CreateAlbumRequest value, $Res Function(_CreateAlbumRequest) _then) = __$CreateAlbumRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'userId') String userId, String ratio, String coverLayersJson, String coverImageUrl, String coverThumbnailUrl, String? coverOriginalUrl, String? coverPreviewUrl, String coverTheme
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
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? ratio = null,Object? coverLayersJson = null,Object? coverImageUrl = null,Object? coverThumbnailUrl = null,Object? coverOriginalUrl = freezed,Object? coverPreviewUrl = freezed,Object? coverTheme = null,}) {
  return _then(_CreateAlbumRequest(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as String,coverLayersJson: null == coverLayersJson ? _self.coverLayersJson : coverLayersJson // ignore: cast_nullable_to_non_nullable
as String,coverImageUrl: null == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String,coverThumbnailUrl: null == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,coverOriginalUrl: freezed == coverOriginalUrl ? _self.coverOriginalUrl : coverOriginalUrl // ignore: cast_nullable_to_non_nullable
as String?,coverPreviewUrl: freezed == coverPreviewUrl ? _self.coverPreviewUrl : coverPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,coverTheme: null == coverTheme ? _self.coverTheme : coverTheme // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
