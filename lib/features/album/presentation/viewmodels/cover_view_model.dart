import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/cover_size.dart';
import '../../domain/entities/cover_theme.dart';
part 'cover_view_model.g.dart';
part 'cover_view_model.freezed.dart';

@freezed
abstract class CoverState with _$CoverState {
  const factory CoverState({
    @Default(
      CoverSize(
        name: '세로형',
        ratio: 6 / 8,
        realSize: Size(14.5, 19.4),
      ),
    )
    CoverSize selectedCover,

    @Default(CoverTheme.classic) CoverTheme selectedTheme,
  }) = _CoverState;
}

@Riverpod(keepAlive: true)
class CoverViewModel extends _$CoverViewModel {
  final List<AssetEntity> _files = [];
  final List<AssetPathEntity> _albums = [];
  CoverSize _cover = coverSizes.first;
  CoverTheme _selectedTheme = CoverTheme.classic;

  // ===== Selected getters =====
  CoverSize get selectedCover => _cover;
  CoverTheme get selectedTheme => _selectedTheme;



  @override
  FutureOr<CoverState> build() async {

    return CoverState(
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
    );
  }


  /// 커버 선택 (+ 선택적으로 Variant 지정)
  void selectCover(
      CoverSize cover) {
    _cover = cover;
    _emit();
  }

  /// 커버 테마 변경
  void updateTheme(CoverTheme theme) {
    if (_selectedTheme == theme) return; // 동일 테마면 무시
    _selectedTheme = theme;
    _emit();
  }

  /// emit (현재 커버 반영)
  void _emit() {
    final prev = state.value ?? const CoverState();

    state = AsyncData(prev.copyWith(
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
    ));
  }

}