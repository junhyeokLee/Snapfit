// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gallery_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GalleryState {

 List<AssetPathEntity> get albums; AssetPathEntity? get selectedAlbum; List<AssetEntity> get images; int get currentPage; bool get hasMore; bool get isLoading; Object? get error;
/// Create a copy of GalleryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GalleryStateCopyWith<GalleryState> get copyWith => _$GalleryStateCopyWithImpl<GalleryState>(this as GalleryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GalleryState&&const DeepCollectionEquality().equals(other.albums, albums)&&(identical(other.selectedAlbum, selectedAlbum) || other.selectedAlbum == selectedAlbum)&&const DeepCollectionEquality().equals(other.images, images)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(albums),selectedAlbum,const DeepCollectionEquality().hash(images),currentPage,hasMore,isLoading,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'GalleryState(albums: $albums, selectedAlbum: $selectedAlbum, images: $images, currentPage: $currentPage, hasMore: $hasMore, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $GalleryStateCopyWith<$Res>  {
  factory $GalleryStateCopyWith(GalleryState value, $Res Function(GalleryState) _then) = _$GalleryStateCopyWithImpl;
@useResult
$Res call({
 List<AssetPathEntity> albums, AssetPathEntity? selectedAlbum, List<AssetEntity> images, int currentPage, bool hasMore, bool isLoading, Object? error
});




}
/// @nodoc
class _$GalleryStateCopyWithImpl<$Res>
    implements $GalleryStateCopyWith<$Res> {
  _$GalleryStateCopyWithImpl(this._self, this._then);

  final GalleryState _self;
  final $Res Function(GalleryState) _then;

/// Create a copy of GalleryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? albums = null,Object? selectedAlbum = freezed,Object? images = null,Object? currentPage = null,Object? hasMore = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
albums: null == albums ? _self.albums : albums // ignore: cast_nullable_to_non_nullable
as List<AssetPathEntity>,selectedAlbum: freezed == selectedAlbum ? _self.selectedAlbum : selectedAlbum // ignore: cast_nullable_to_non_nullable
as AssetPathEntity?,images: null == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<AssetEntity>,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [GalleryState].
extension GalleryStatePatterns on GalleryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GalleryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GalleryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GalleryState value)  $default,){
final _that = this;
switch (_that) {
case _GalleryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GalleryState value)?  $default,){
final _that = this;
switch (_that) {
case _GalleryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AssetPathEntity> albums,  AssetPathEntity? selectedAlbum,  List<AssetEntity> images,  int currentPage,  bool hasMore,  bool isLoading,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GalleryState() when $default != null:
return $default(_that.albums,_that.selectedAlbum,_that.images,_that.currentPage,_that.hasMore,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AssetPathEntity> albums,  AssetPathEntity? selectedAlbum,  List<AssetEntity> images,  int currentPage,  bool hasMore,  bool isLoading,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _GalleryState():
return $default(_that.albums,_that.selectedAlbum,_that.images,_that.currentPage,_that.hasMore,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AssetPathEntity> albums,  AssetPathEntity? selectedAlbum,  List<AssetEntity> images,  int currentPage,  bool hasMore,  bool isLoading,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _GalleryState() when $default != null:
return $default(_that.albums,_that.selectedAlbum,_that.images,_that.currentPage,_that.hasMore,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _GalleryState implements GalleryState {
  const _GalleryState({final  List<AssetPathEntity> albums = const [], this.selectedAlbum, final  List<AssetEntity> images = const [], this.currentPage = 0, this.hasMore = true, this.isLoading = false, this.error}): _albums = albums,_images = images;
  

 final  List<AssetPathEntity> _albums;
@override@JsonKey() List<AssetPathEntity> get albums {
  if (_albums is EqualUnmodifiableListView) return _albums;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_albums);
}

@override final  AssetPathEntity? selectedAlbum;
 final  List<AssetEntity> _images;
@override@JsonKey() List<AssetEntity> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}

@override@JsonKey() final  int currentPage;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool isLoading;
@override final  Object? error;

/// Create a copy of GalleryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GalleryStateCopyWith<_GalleryState> get copyWith => __$GalleryStateCopyWithImpl<_GalleryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GalleryState&&const DeepCollectionEquality().equals(other._albums, _albums)&&(identical(other.selectedAlbum, selectedAlbum) || other.selectedAlbum == selectedAlbum)&&const DeepCollectionEquality().equals(other._images, _images)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_albums),selectedAlbum,const DeepCollectionEquality().hash(_images),currentPage,hasMore,isLoading,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'GalleryState(albums: $albums, selectedAlbum: $selectedAlbum, images: $images, currentPage: $currentPage, hasMore: $hasMore, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$GalleryStateCopyWith<$Res> implements $GalleryStateCopyWith<$Res> {
  factory _$GalleryStateCopyWith(_GalleryState value, $Res Function(_GalleryState) _then) = __$GalleryStateCopyWithImpl;
@override @useResult
$Res call({
 List<AssetPathEntity> albums, AssetPathEntity? selectedAlbum, List<AssetEntity> images, int currentPage, bool hasMore, bool isLoading, Object? error
});




}
/// @nodoc
class __$GalleryStateCopyWithImpl<$Res>
    implements _$GalleryStateCopyWith<$Res> {
  __$GalleryStateCopyWithImpl(this._self, this._then);

  final _GalleryState _self;
  final $Res Function(_GalleryState) _then;

/// Create a copy of GalleryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? albums = null,Object? selectedAlbum = freezed,Object? images = null,Object? currentPage = null,Object? hasMore = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_GalleryState(
albums: null == albums ? _self._albums : albums // ignore: cast_nullable_to_non_nullable
as List<AssetPathEntity>,selectedAlbum: freezed == selectedAlbum ? _self.selectedAlbum : selectedAlbum // ignore: cast_nullable_to_non_nullable
as AssetPathEntity?,images: null == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<AssetEntity>,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
