// model/cover_theme.dart
import 'package:flutter/material.dart';

enum CoverTheme {
  classic,
  architecture,
  nature1,
  nature2,
  abstract,
  abstract2,
  abstract3,
  abstract4,
  texture,
  dark,
}

extension CoverThemeStyle on CoverTheme {
  String get label {
    switch (this) {
      case CoverTheme.classic: return "classic";
      case CoverTheme.architecture: return "architecture";
      case CoverTheme.nature1: return "nature1";
      case CoverTheme.nature2: return "nature2";
      case CoverTheme.abstract: return "abstract";
      case CoverTheme.abstract2: return "abstract2";
      case CoverTheme.abstract3: return "abstract3";
      case CoverTheme.abstract4: return "abstract4";
      case CoverTheme.texture: return "texture";
      case CoverTheme.dark: return "dark";
    }
  }

  String? get imageAsset {
    switch (this) {
      case CoverTheme.architecture:
        return 'assets/cover/cover1.png';
      case CoverTheme.nature1:
        return 'assets/cover/cover2.png';
      case CoverTheme.nature2:
        return 'assets/cover/cover3.png';
      case CoverTheme.abstract:
        return 'assets/cover/cover4.png';
      case CoverTheme.abstract2:
        return 'assets/cover/cover5.png';
      case CoverTheme.abstract3:
        return 'assets/cover/cover6.png';
      case CoverTheme.abstract4:
        return 'assets/cover/cover7.png';
      case CoverTheme.texture:
        return 'assets/cover/cover8.png';
      case CoverTheme.classic:
      case CoverTheme.dark:
      default:
        return null;
    }
  }


  LinearGradient get gradient {
    switch (this) {
      case CoverTheme.classic:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.architecture:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.nature1:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.nature2:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.abstract:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.abstract2:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.abstract3:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.abstract4:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.dark:
        return const LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF414345)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.texture:
        return const LinearGradient(
          colors: [Color(0xFFD7D2CC), Color(0xFF304352)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  BoxDecoration get backgroundDecoration {
    return BoxDecoration(
      image: imageAsset != null
          ? DecorationImage(
              image: AssetImage(imageAsset!),
              fit: BoxFit.cover,
            )
          : null,
      gradient: imageAsset == null ? gradient : null,
    );
  }
}