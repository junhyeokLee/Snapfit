// Controllers/edit_cover_state_manager.dart
class EditCoverStateManager {
  bool openEditText = false;
  bool openCoverTheme = false;
  bool initialized = false;
  String? selectedLayerId;
  String? editingLayerId;

  void clearSelection() {
    selectedLayerId = null;
    editingLayerId = null;
  }

  void startEditing(String id) {
    editingLayerId = id;
  }

  void setThemeOpen(bool v) {
    openCoverTheme = v;
  }

  void setTextOpen(bool v) {
    openEditText = v;
  }
}