// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'album_editor_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AlbumEditorState {

 List<AssetEntity> get files; List<AssetPathEntity> get albums; AssetPathEntity? get currentAlbum;/// 현재 페이지의 레이어들(UI가 바로 그릴 데이터)
 List<LayerModel> get layers; CoverSize get selectedCover; CoverTheme get selectedTheme;/// 에디터 커버 캔버스 크기 (레이어 좌표 기준). 썸네일/스프레드 배치용.
 Size? get coverCanvasSize;
/// Create a copy of AlbumEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumEditorStateCopyWith<AlbumEditorState> get copyWith => _$AlbumEditorStateCopyWithImpl<AlbumEditorState>(this as AlbumEditorState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlbumEditorState&&const DeepCollectionEquality().equals(other.files, files)&&const DeepCollectionEquality().equals(other.albums, albums)&&(identical(other.currentAlbum, currentAlbum) || other.currentAlbum == currentAlbum)&&const DeepCollectionEquality().equals(other.layers, layers)&&(identical(other.selectedCover, selectedCover) || other.selectedCover == selectedCover)&&(identical(other.selectedTheme, selectedTheme) || other.selectedTheme == selectedTheme)&&(identical(other.coverCanvasSize, coverCanvasSize) || other.coverCanvasSize == coverCanvasSize));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(files),const DeepCollectionEquality().hash(albums),currentAlbum,const DeepCollectionEquality().hash(layers),selectedCover,selectedTheme,coverCanvasSize);

@override
String toString() {
  return 'AlbumEditorState(files: $files, albums: $albums, currentAlbum: $currentAlbum, layers: $layers, selectedCover: $selectedCover, selectedTheme: $selectedTheme, coverCanvasSize: $coverCanvasSize)';
}


}

/// @nodoc
abstract mixin class $AlbumEditorStateCopyWith<$Res>  {
  factory $AlbumEditorStateCopyWith(AlbumEditorState value, $Res Function(AlbumEditorState) _then) = _$AlbumEditorStateCopyWithImpl;
@useResult
$Res call({
 List<AssetEntity> files, List<AssetPathEntity> albums, AssetPathEntity? currentAlbum, List<LayerModel> layers, CoverSize selectedCover, CoverTheme selectedTheme, Size? coverCanvasSize
});




}
/// @nodoc
class _$AlbumEditorStateCopyWithImpl<$Res>
    implements $AlbumEditorStateCopyWith<$Res> {
  _$AlbumEditorStateCopyWithImpl(this._self, this._then);

  final AlbumEditorState _self;
  final $Res Function(AlbumEditorState) _then;

/// Create a copy of AlbumEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? files = null,Object? albums = null,Object? currentAlbum = freezed,Object? layers = null,Object? selectedCover = null,Object? selectedTheme = null,Object? coverCanvasSize = freezed,}) {
  return _then(_self.copyWith(
files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<AssetEntity>,albums: null == albums ? _self.albums : albums // ignore: cast_nullable_to_non_nullable
as List<AssetPathEntity>,currentAlbum: freezed == currentAlbum ? _self.currentAlbum : currentAlbum // ignore: cast_nullable_to_non_nullable
as AssetPathEntity?,layers: null == layers ? _self.layers : layers // ignore: cast_nullable_to_non_nullable
as List<LayerModel>,selectedCover: null == selectedCover ? _self.selectedCover : selectedCover // ignore: cast_nullable_to_non_nullable
as CoverSize,selectedTheme: null == selectedTheme ? _self.selectedTheme : selectedTheme // ignore: cast_nullable_to_non_nullable
as CoverTheme,coverCanvasSize: freezed == coverCanvasSize ? _self.coverCanvasSize : coverCanvasSize // ignore: cast_nullable_to_non_nullable
as Size?,
  ));
}

}


/// Adds pattern-matching-related methods to [AlbumEditorState].
extension AlbumEditorStatePatterns on AlbumEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlbumEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlbumEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlbumEditorState value)  $default,){
final _that = this;
switch (_that) {
case _AlbumEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlbumEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _AlbumEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AssetEntity> files,  List<AssetPathEntity> albums,  AssetPathEntity? currentAlbum,  List<LayerModel> layers,  CoverSize selectedCover,  CoverTheme selectedTheme,  Size? coverCanvasSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlbumEditorState() when $default != null:
return $default(_that.files,_that.albums,_that.currentAlbum,_that.layers,_that.selectedCover,_that.selectedTheme,_that.coverCanvasSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AssetEntity> files,  List<AssetPathEntity> albums,  AssetPathEntity? currentAlbum,  List<LayerModel> layers,  CoverSize selectedCover,  CoverTheme selectedTheme,  Size? coverCanvasSize)  $default,) {final _that = this;
switch (_that) {
case _AlbumEditorState():
return $default(_that.files,_that.albums,_that.currentAlbum,_that.layers,_that.selectedCover,_that.selectedTheme,_that.coverCanvasSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AssetEntity> files,  List<AssetPathEntity> albums,  AssetPathEntity? currentAlbum,  List<LayerModel> layers,  CoverSize selectedCover,  CoverTheme selectedTheme,  Size? coverCanvasSize)?  $default,) {final _that = this;
switch (_that) {
case _AlbumEditorState() when $default != null:
return $default(_that.files,_that.albums,_that.currentAlbum,_that.layers,_that.selectedCover,_that.selectedTheme,_that.coverCanvasSize);case _:
  return null;

}
}

}

/// @nodoc


class _AlbumEditorState implements AlbumEditorState {
  const _AlbumEditorState({final  List<AssetEntity> files = const [], final  List<AssetPathEntity> albums = const [], this.currentAlbum, final  List<LayerModel> layers = const [], this.selectedCover = const CoverSize(name: '세로형', ratio: 6 / 8, realSize: Size(14.5, 19.4)), this.selectedTheme = CoverTheme.classic, this.coverCanvasSize}): _files = files,_albums = albums,_layers = layers;
  

 final  List<AssetEntity> _files;
@override@JsonKey() List<AssetEntity> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}

 final  List<AssetPathEntity> _albums;
@override@JsonKey() List<AssetPathEntity> get albums {
  if (_albums is EqualUnmodifiableListView) return _albums;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_albums);
}

@override final  AssetPathEntity? currentAlbum;
/// 현재 페이지의 레이어들(UI가 바로 그릴 데이터)
 final  List<LayerModel> _layers;
/// 현재 페이지의 레이어들(UI가 바로 그릴 데이터)
@override@JsonKey() List<LayerModel> get layers {
  if (_layers is EqualUnmodifiableListView) return _layers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_layers);
}

@override@JsonKey() final  CoverSize selectedCover;
@override@JsonKey() final  CoverTheme selectedTheme;
/// 에디터 커버 캔버스 크기 (레이어 좌표 기준). 썸네일/스프레드 배치용.
@override final  Size? coverCanvasSize;

/// Create a copy of AlbumEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumEditorStateCopyWith<_AlbumEditorState> get copyWith => __$AlbumEditorStateCopyWithImpl<_AlbumEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlbumEditorState&&const DeepCollectionEquality().equals(other._files, _files)&&const DeepCollectionEquality().equals(other._albums, _albums)&&(identical(other.currentAlbum, currentAlbum) || other.currentAlbum == currentAlbum)&&const DeepCollectionEquality().equals(other._layers, _layers)&&(identical(other.selectedCover, selectedCover) || other.selectedCover == selectedCover)&&(identical(other.selectedTheme, selectedTheme) || other.selectedTheme == selectedTheme)&&(identical(other.coverCanvasSize, coverCanvasSize) || other.coverCanvasSize == coverCanvasSize));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_files),const DeepCollectionEquality().hash(_albums),currentAlbum,const DeepCollectionEquality().hash(_layers),selectedCover,selectedTheme,coverCanvasSize);

@override
String toString() {
  return 'AlbumEditorState(files: $files, albums: $albums, currentAlbum: $currentAlbum, layers: $layers, selectedCover: $selectedCover, selectedTheme: $selectedTheme, coverCanvasSize: $coverCanvasSize)';
}


}

/// @nodoc
abstract mixin class _$AlbumEditorStateCopyWith<$Res> implements $AlbumEditorStateCopyWith<$Res> {
  factory _$AlbumEditorStateCopyWith(_AlbumEditorState value, $Res Function(_AlbumEditorState) _then) = __$AlbumEditorStateCopyWithImpl;
@override @useResult
$Res call({
 List<AssetEntity> files, List<AssetPathEntity> albums, AssetPathEntity? currentAlbum, List<LayerModel> layers, CoverSize selectedCover, CoverTheme selectedTheme, Size? coverCanvasSize
});




}
/// @nodoc
class __$AlbumEditorStateCopyWithImpl<$Res>
    implements _$AlbumEditorStateCopyWith<$Res> {
  __$AlbumEditorStateCopyWithImpl(this._self, this._then);

  final _AlbumEditorState _self;
  final $Res Function(_AlbumEditorState) _then;

/// Create a copy of AlbumEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? files = null,Object? albums = null,Object? currentAlbum = freezed,Object? layers = null,Object? selectedCover = null,Object? selectedTheme = null,Object? coverCanvasSize = freezed,}) {
  return _then(_AlbumEditorState(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<AssetEntity>,albums: null == albums ? _self._albums : albums // ignore: cast_nullable_to_non_nullable
as List<AssetPathEntity>,currentAlbum: freezed == currentAlbum ? _self.currentAlbum : currentAlbum // ignore: cast_nullable_to_non_nullable
as AssetPathEntity?,layers: null == layers ? _self._layers : layers // ignore: cast_nullable_to_non_nullable
as List<LayerModel>,selectedCover: null == selectedCover ? _self.selectedCover : selectedCover // ignore: cast_nullable_to_non_nullable
as CoverSize,selectedTheme: null == selectedTheme ? _self.selectedTheme : selectedTheme // ignore: cast_nullable_to_non_nullable
as CoverTheme,coverCanvasSize: freezed == coverCanvasSize ? _self.coverCanvasSize : coverCanvasSize // ignore: cast_nullable_to_non_nullable
as Size?,
  ));
}


}

// dart format on
