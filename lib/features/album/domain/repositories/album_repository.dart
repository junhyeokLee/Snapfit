import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageRepository {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  }
}