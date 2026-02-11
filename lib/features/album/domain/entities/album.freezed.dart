// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'album.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Album {

/// 백엔드의 albumId(int)와 매핑
/// 생성 API 응답에 albumId가 없을 수도 있어 기본값 허용
@JsonKey(name: 'albumId') int get id;/// 커버 레이어 전체 상태(JSON) - 있을 경우 홈에서도 에디터와 동일하게 렌더링
 String get coverLayersJson;/// 서버에서 null 이 와도 안전하게 처리하기 위해 기본값 사용
 String get ratio; String? get coverImageUrl; String? get coverThumbnailUrl;/// 운영급: 커버 원본/미리보기 URL (없으면 coverImageUrl을 preview로 간주)
 String? get coverOriginalUrl; String? get coverPreviewUrl;/// 커버 테마 (예: classic, nature1) - 서버에서 저장/반환 시 편집 화면에서 복원
 String? get coverTheme; int get totalPages;/// 목표 페이지 수 (완성 기준)
 int get targetPages; String get createdAt; String get updatedAt;
/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumCopyWith<Album> get copyWith => _$AlbumCopyWithImpl<Album>(this as Album, _$identity);

  /// Serializes this Album to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Album&&(identical(other.id, id) || other.id == id)&&(identical(other.coverLayersJson, coverLayersJson) || other.coverLayersJson == coverLayersJson)&&(identical(other.ratio, ratio) || other.ratio == ratio)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.coverThumbnailUrl, coverThumbnailUrl) || other.coverThumbnailUrl == coverThumbnailUrl)&&(identical(other.coverOriginalUrl, coverOriginalUrl) || other.coverOriginalUrl == coverOriginalUrl)&&(identical(other.coverPreviewUrl, coverPreviewUrl) || other.coverPreviewUrl == coverPreviewUrl)&&(identical(other.coverTheme, coverTheme) || other.coverTheme == coverTheme)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.targetPages, targetPages) || other.targetPages == targetPages)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,coverLayersJson,ratio,coverImageUrl,coverThumbnailUrl,coverOriginalUrl,coverPreviewUrl,coverTheme,totalPages,targetPages,createdAt,updatedAt);

@override
String toString() {
  return 'Album(id: $id, coverLayersJson: $coverLayersJson, ratio: $ratio, coverImageUrl: $coverImageUrl, coverThumbnailUrl: $coverThumbnailUrl, coverOriginalUrl: $coverOriginalUrl, coverPreviewUrl: $coverPreviewUrl, coverTheme: $coverTheme, totalPages: $totalPages, targetPages: $targetPages, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AlbumCopyWith<$Res>  {
  factory $AlbumCopyWith(Album value, $Res Function(Album) _then) = _$AlbumCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'albumId') int id, String coverLayersJson, String ratio, String? coverImageUrl, String? coverThumbnailUrl, String? coverOriginalUrl, String? coverPreviewUrl, String? coverTheme, int totalPages, int targetPages, String createdAt, String updatedAt
});




}
/// @nodoc
class _$AlbumCopyWithImpl<$Res>
    implements $AlbumCopyWith<$Res> {
  _$AlbumCopyWithImpl(this._self, this._then);

  final Album _self;
  final $Res Function(Album) _then;

/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? coverLayersJson = null,Object? ratio = null,Object? coverImageUrl = freezed,Object? coverThumbnailUrl = freezed,Object? coverOriginalUrl = freezed,Object? coverPreviewUrl = freezed,Object? coverTheme = freezed,Object? totalPages = null,Object? targetPages = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,coverLayersJson: null == coverLayersJson ? _self.coverLayersJson : coverLayersJson // ignore: cast_nullable_to_non_nullable
as String,ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as String,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailUrl: freezed == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,coverOriginalUrl: freezed == coverOriginalUrl ? _self.coverOriginalUrl : coverOriginalUrl // ignore: cast_nullable_to_non_nullable
as String?,coverPreviewUrl: freezed == coverPreviewUrl ? _self.coverPreviewUrl : coverPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,coverTheme: freezed == coverTheme ? _self.coverTheme : coverTheme // ignore: cast_nullable_to_non_nullable
as String?,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,targetPages: null == targetPages ? _self.targetPages : targetPages // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Album].
extension AlbumPatterns on Album {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Album value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Album() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Album value)  $default,){
final _that = this;
switch (_that) {
case _Album():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Album value)?  $default,){
final _that = this;
switch (_that) {
case _Album() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'albumId')  int id,  String coverLayersJson,  String ratio,  String? coverImageUrl,  String? coverThumbnailUrl,  String? coverOriginalUrl,  String? coverPreviewUrl,  String? coverTheme,  int totalPages,  int targetPages,  String createdAt,  String updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Album() when $default != null:
return $default(_that.id,_that.coverLayersJson,_that.ratio,_that.coverImageUrl,_that.coverThumbnailUrl,_that.coverOriginalUrl,_that.coverPreviewUrl,_that.coverTheme,_that.totalPages,_that.targetPages,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'albumId')  int id,  String coverLayersJson,  String ratio,  String? coverImageUrl,  String? coverThumbnailUrl,  String? coverOriginalUrl,  String? coverPreviewUrl,  String? coverTheme,  int totalPages,  int targetPages,  String createdAt,  String updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Album():
return $default(_that.id,_that.coverLayersJson,_that.ratio,_that.coverImageUrl,_that.coverThumbnailUrl,_that.coverOriginalUrl,_that.coverPreviewUrl,_that.coverTheme,_that.totalPages,_that.targetPages,_that.createdAt,_that.updatedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'albumId')  int id,  String coverLayersJson,  String ratio,  String? coverImageUrl,  String? coverThumbnailUrl,  String? coverOriginalUrl,  String? coverPreviewUrl,  String? coverTheme,  int totalPages,  int targetPages,  String createdAt,  String updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Album() when $default != null:
return $default(_that.id,_that.coverLayersJson,_that.ratio,_that.coverImageUrl,_that.coverThumbnailUrl,_that.coverOriginalUrl,_that.coverPreviewUrl,_that.coverTheme,_that.totalPages,_that.targetPages,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Album implements Album {
  const _Album({@JsonKey(name: 'albumId') this.id = 0, this.coverLayersJson = '', this.ratio = '', this.coverImageUrl, this.coverThumbnailUrl, this.coverOriginalUrl, this.coverPreviewUrl, this.coverTheme, this.totalPages = 0, this.targetPages = 0, this.createdAt = '', this.updatedAt = ''});
  factory _Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);

/// 백엔드의 albumId(int)와 매핑
/// 생성 API 응답에 albumId가 없을 수도 있어 기본값 허용
@override@JsonKey(name: 'albumId') final  int id;
/// 커버 레이어 전체 상태(JSON) - 있을 경우 홈에서도 에디터와 동일하게 렌더링
@override@JsonKey() final  String coverLayersJson;
/// 서버에서 null 이 와도 안전하게 처리하기 위해 기본값 사용
@override@JsonKey() final  String ratio;
@override final  String? coverImageUrl;
@override final  String? coverThumbnailUrl;
/// 운영급: 커버 원본/미리보기 URL (없으면 coverImageUrl을 preview로 간주)
@override final  String? coverOriginalUrl;
@override final  String? coverPreviewUrl;
/// 커버 테마 (예: classic, nature1) - 서버에서 저장/반환 시 편집 화면에서 복원
@override final  String? coverTheme;
@override@JsonKey() final  int totalPages;
/// 목표 페이지 수 (완성 기준)
@override@JsonKey() final  int targetPages;
@override@JsonKey() final  String createdAt;
@override@JsonKey() final  String updatedAt;

/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumCopyWith<_Album> get copyWith => __$AlbumCopyWithImpl<_Album>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlbumToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Album&&(identical(other.id, id) || other.id == id)&&(identical(other.coverLayersJson, coverLayersJson) || other.coverLayersJson == coverLayersJson)&&(identical(other.ratio, ratio) || other.ratio == ratio)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.coverThumbnailUrl, coverThumbnailUrl) || other.coverThumbnailUrl == coverThumbnailUrl)&&(identical(other.coverOriginalUrl, coverOriginalUrl) || other.coverOriginalUrl == coverOriginalUrl)&&(identical(other.coverPreviewUrl, coverPreviewUrl) || other.coverPreviewUrl == coverPreviewUrl)&&(identical(other.coverTheme, coverTheme) || other.coverTheme == coverTheme)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.targetPages, targetPages) || other.targetPages == targetPages)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,coverLayersJson,ratio,coverImageUrl,coverThumbnailUrl,coverOriginalUrl,coverPreviewUrl,coverTheme,totalPages,targetPages,createdAt,updatedAt);

@override
String toString() {
  return 'Album(id: $id, coverLayersJson: $coverLayersJson, ratio: $ratio, coverImageUrl: $coverImageUrl, coverThumbnailUrl: $coverThumbnailUrl, coverOriginalUrl: $coverOriginalUrl, coverPreviewUrl: $coverPreviewUrl, coverTheme: $coverTheme, totalPages: $totalPages, targetPages: $targetPages, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AlbumCopyWith<$Res> implements $AlbumCopyWith<$Res> {
  factory _$AlbumCopyWith(_Album value, $Res Function(_Album) _then) = __$AlbumCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'albumId') int id, String coverLayersJson, String ratio, String? coverImageUrl, String? coverThumbnailUrl, String? coverOriginalUrl, String? coverPreviewUrl, String? coverTheme, int totalPages, int targetPages, String createdAt, String updatedAt
});




}
/// @nodoc
class __$AlbumCopyWithImpl<$Res>
    implements _$AlbumCopyWith<$Res> {
  __$AlbumCopyWithImpl(this._self, this._then);

  final _Album _self;
  final $Res Function(_Album) _then;

/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? coverLayersJson = null,Object? ratio = null,Object? coverImageUrl = freezed,Object? coverThumbnailUrl = freezed,Object? coverOriginalUrl = freezed,Object? coverPreviewUrl = freezed,Object? coverTheme = freezed,Object? totalPages = null,Object? targetPages = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Album(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,coverLayersJson: null == coverLayersJson ? _self.coverLayersJson : coverLayersJson // ignore: cast_nullable_to_non_nullable
as String,ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as String,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailUrl: freezed == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,coverOriginalUrl: freezed == coverOriginalUrl ? _self.coverOriginalUrl : coverOriginalUrl // ignore: cast_nullable_to_non_nullable
as String?,coverPreviewUrl: freezed == coverPreviewUrl ? _self.coverPreviewUrl : coverPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,coverTheme: freezed == coverTheme ? _self.coverTheme : coverTheme // ignore: cast_nullable_to_non_nullable
as String?,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,targetPages: null == targetPages ? _self.targetPages : targetPages // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
