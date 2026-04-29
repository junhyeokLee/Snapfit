import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeUiState {
  const HomeUiState({this.bottomNavIndex = 0, this.albumTabIndex = 0});

  final int bottomNavIndex;
  final int albumTabIndex;

  HomeUiState copyWith({int? bottomNavIndex, int? albumTabIndex}) {
    return HomeUiState(
      bottomNavIndex: bottomNavIndex ?? this.bottomNavIndex,
      albumTabIndex: albumTabIndex ?? this.albumTabIndex,
    );
  }
}

class HomeUiStateNotifier extends Notifier<HomeUiState> {
  @override
  HomeUiState build() => const HomeUiState();

  void setBottomNavIndex(int index) {
    if (state.bottomNavIndex == index) return;
    state = state.copyWith(bottomNavIndex: index);
  }

  void setAlbumTabIndex(int index) {
    if (state.albumTabIndex == index) return;
    state = state.copyWith(albumTabIndex: index);
  }
}

final homeUiStateProvider = NotifierProvider<HomeUiStateNotifier, HomeUiState>(
  HomeUiStateNotifier.new,
);
