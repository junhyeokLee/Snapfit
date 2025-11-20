import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/layer.dart';
import '../../viewmodels/album_view_model.dart';

class EditToolbar extends StatelessWidget {
  final AlbumViewModel vm;
  final LayerModel? selected;
  final VoidCallback onAddText;
  final VoidCallback onAddPhoto;
  final VoidCallback onOpenCoverSelector;

  const EditToolbar({
    super.key,
    required this.vm,
    this.selected,
    required this.onAddText,
    required this.onAddPhoto,
    required this.onOpenCoverSelector,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _toolbarButton(Icons.book_outlined, "커버", onOpenCoverSelector),
          _toolbarButton(Icons.text_fields, "텍스트", onAddText),
          _toolbarButton(Icons.photo, "오버레이", onAddPhoto),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30.sp, color: Colors.white),
          Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.white)),
        ],
      ),
    );
  }
}