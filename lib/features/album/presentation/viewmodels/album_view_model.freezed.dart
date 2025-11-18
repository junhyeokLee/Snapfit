// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'album_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AlbumState {

 List<AssetEntity> get files; List<AssetPathEntity> get albums; AssetPathEntity? get currentAlbum; List<LayerModel> get layers; CoverSize get selectedCover; CoverTheme get selectedTheme;
/// Create a copy of AlbumState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumStateCopyWith<AlbumState> get copyWith => _$AlbumStateCopyWithImpl<AlbumState>(this as AlbumState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlbumState&&const DeepCollectionEquality().equals(other.files, files)&&const DeepCollectionEquality().equals(other.albums, albums)&&(identical(other.currentAlbum, currentAlbum) || other.currentAlbum == currentAlbum)&&const DeepCollectionEquality().equals(other.layers, layers)&&const DeepCollectionEquality().equals(other.selectedCover, selectedCover)&&const DeepCollectionEquality().equals(other.selectedTheme, selectedTheme));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(files),const DeepCollectionEquality().hash(albums),currentAlbum,const DeepCollectionEquality().hash(layers),const DeepCollectionEquality().hash(selectedCover),const DeepCollectionEquality().hash(selectedTheme));

@override
String toString() {
  return 'AlbumState(files: $files, albums: $albums, currentAlbum: $currentAlbum, layers: $layers, selectedCover: $selectedCover, selectedTheme: $selectedTheme)';
}


}

/// @nodoc
abstract mixin class $AlbumStateCopyWith<$Res>  {
  factory $AlbumStateCopyWith(AlbumState value, $Res Function(AlbumState) _then) = _$AlbumStateCopyWithImpl;
@useResult
$Res call({
 List<AssetEntity> files, List<AssetPathEntity> albums, AssetPathEntity? currentAlbum, List<LayerModel> layers, CoverSize selectedCover, CoverTheme selectedTheme
});




}
/// @nodoc
class _$AlbumStateCopyWithImpl<$Res>
    implements $AlbumStateCopyWith<$Res> {
  _$AlbumStateCopyWithImpl(this._self, this._then);

  final AlbumState _self;
  final $Res Function(AlbumState) _then;

/// Create a copy of AlbumState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? files = null,Object? albums = null,Object? currentAlbum = freezed,Object? layers = null,Object? selectedCover = freezed,Object? selectedTheme = freezed,}) {
  return _then(_self.copyWith(
files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<AssetEntity>,albums: null == albums ? _self.albums : albums // ignore: cast_nullable_to_non_nullable
as List<AssetPathEntity>,currentAlbum: freezed == currentAlbum ? _self.currentAlbum : currentAlbum // ignore: cast_nullable_to_non_nullable
as AssetPathEntity?,layers: null == layers ? _self.layers : layers // ignore: cast_nullable_to_non_nullable
as List<LayerModel>,selectedCover: freezed == selectedCover ? _self.selectedCover : selectedCover // ignore: cast_nullable_to_non_nullable
as CoverSize,selectedTheme: freezed == selectedTheme ? _self.selectedTheme : selectedTheme // ignore: cast_nullable_to_non_nullable
as CoverTheme,
  ));
}

}


/// Adds pattern-matching-related methods to [AlbumState].
extension AlbumStatePatterns on AlbumState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlbumState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlbumState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlbumState value)  $default,){
final _that = this;
switch (_that) {
case _AlbumState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlbumState value)?  $default,){
final _that = this;
switch (_that) {
case _AlbumState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AssetEntity> files,  List<AssetPathEntity> albums,  AssetPathEntity? currentAlbum,  List<LayerModel> layers,  CoverSize selectedCover,  CoverTheme selectedTheme)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlbumState() when $default != null:
return $default(_that.files,_that.albums,_that.currentAlbum,_that.layers,_that.selectedCover,_that.selectedTheme);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AssetEntity> files,  List<AssetPathEntity> albums,  AssetPathEntity? currentAlbum,  List<LayerModel> layers,  CoverSize selectedCover,  CoverTheme selectedTheme)  $default,) {final _that = this;
switch (_that) {
case _AlbumState():
return $default(_that.files,_that.albums,_that.currentAlbum,_that.layers,_that.selectedCover,_that.selectedTheme);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AssetEntity> files,  List<AssetPathEntity> albums,  AssetPathEntity? currentAlbum,  List<LayerModel> layers,  CoverSize selectedCover,  CoverTheme selectedTheme)?  $default,) {final _that = this;
switch (_that) {
case _AlbumState() when $default != null:
return $default(_that.files,_that.albums,_that.currentAlbum,_that.layers,_that.selectedCover,_that.selectedTheme);case _:
  return null;

}
}

}

/// @nodoc


class _AlbumState implements AlbumState {
  const _AlbumState({final  List<AssetEntity> files = const [], final  List<AssetPathEntity> albums = const [], this.currentAlbum, final  List<LayerModel> layers = const [], this.selectedCover = const CoverSize(name: '세로형', ratio: 6 / 8, realSize: Size(14.5, 19.4)), this.selectedTheme = CoverTheme.classic}): _files = files,_albums = albums,_layers = layers;
  

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
 final  List<LayerModel> _layers;
@override@JsonKey() List<LayerModel> get layers {
  if (_layers is EqualUnmodifiableListView) return _layers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_layers);
}

@override@JsonKey() final  CoverSize selectedCover;
@override@JsonKey() final  CoverTheme selectedTheme;

/// Create a copy of AlbumState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumStateCopyWith<_AlbumState> get copyWith => __$AlbumStateCopyWithImpl<_AlbumState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlbumState&&const DeepCollectionEquality().equals(other._files, _files)&&const DeepCollectionEquality().equals(other._albums, _albums)&&(identical(other.currentAlbum, currentAlbum) || other.currentAlbum == currentAlbum)&&const DeepCollectionEquality().equals(other._layers, _layers)&&const DeepCollectionEquality().equals(other.selectedCover, selectedCover)&&const DeepCollectionEquality().equals(other.selectedTheme, selectedTheme));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_files),const DeepCollectionEquality().hash(_albums),currentAlbum,const DeepCollectionEquality().hash(_layers),const DeepCollectionEquality().hash(selectedCover),const DeepCollectionEquality().hash(selectedTheme));

@override
String toString() {
  return 'AlbumState(files: $files, albums: $albums, currentAlbum: $currentAlbum, layers: $layers, selectedCover: $selectedCover, selectedTheme: $selectedTheme)';
}


}

/// @nodoc
abstract mixin class _$AlbumStateCopyWith<$Res> implements $AlbumStateCopyWith<$Res> {
  factory _$AlbumStateCopyWith(_AlbumState value, $Res Function(_AlbumState) _then) = __$AlbumStateCopyWithImpl;
@override @useResult
$Res call({
 List<AssetEntity> files, List<AssetPathEntity> albums, AssetPathEntity? currentAlbum, List<LayerModel> layers, CoverSize selectedCover, CoverTheme selectedTheme
});




}
/// @nodoc
class __$AlbumStateCopyWithImpl<$Res>
    implements _$AlbumStateCopyWith<$Res> {
  __$AlbumStateCopyWithImpl(this._self, this._then);

  final _AlbumState _self;
  final $Res Function(_AlbumState) _then;

/// Create a copy of AlbumState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? files = null,Object? albums = null,Object? currentAlbum = freezed,Object? layers = null,Object? selectedCover = freezed,Object? selectedTheme = freezed,}) {
  return _then(_AlbumState(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<AssetEntity>,albums: null == albums ? _self._albums : albums // ignore: cast_nullable_to_non_nullable
as List<AssetPathEntity>,currentAlbum: freezed == currentAlbum ? _self.currentAlbum : currentAlbum // ignore: cast_nullable_to_non_nullable
as AssetPathEntity?,layers: null == layers ? _self._layers : layers // ignore: cast_nullable_to_non_nullable
as List<LayerModel>,selectedCover: freezed == selectedCover ? _self.selectedCover : selectedCover // ignore: cast_nullable_to_non_nullable
as CoverSize,selectedTheme: freezed == selectedTheme ? _self.selectedTheme : selectedTheme // ignore: cast_nullable_to_non_nullable
as CoverTheme,
  ));
}


}

// dart format on
