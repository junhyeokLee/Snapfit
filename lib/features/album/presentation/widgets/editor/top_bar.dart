import 'package:flutter/material.dart';

/// 상단 바
class TopBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onDone;
  const TopBar({super.key, required this.onCancel, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [_pillBtn('완료', onDone)],
      ),
    );
  }

  Widget _pillBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
