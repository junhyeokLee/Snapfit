// model/cover_theme.dart
import 'package:flutter/material.dart';

enum CoverTheme {
  classic,
  classic2,
  nature1,
  nature2,
  nature3,
  nature4,
  architecture1,
  architecture2,
  abstract1,
  abstract2,
  abstract3,
  abstract4,
  abstract5,
  abstract6,
  texture1,
  texture2,
}

extension CoverThemeStyle on CoverTheme {
  String get label {
    switch (this) {
      case CoverTheme.classic: return "classic";
      case CoverTheme.classic2: return "classic2";
      case CoverTheme.nature1: return "nature1";
      case CoverTheme.nature2: return "nature2";
      case CoverTheme.nature3: return "nature3";
      case CoverTheme.nature4: return "nature4";
      case CoverTheme.architecture1: return "architecture1";
      case CoverTheme.architecture2: return "architecture2";
      case CoverTheme.abstract1: return "abstract";
      case CoverTheme.abstract2: return "abstract2";
      case CoverTheme.abstract3: return "abstract3";
      case CoverTheme.abstract4: return "abstract4";
      case CoverTheme.abstract5: return "abstract5";
      case CoverTheme.abstract6: return "abstract6";
      case CoverTheme.texture1: return "texture1";
      case CoverTheme.texture2: return "texture2";
    }
  }

  String? get imageAsset {
    switch (this) {
      case CoverTheme.nature1:
        return 'assets/cover/cover9.png';
      case CoverTheme.abstract1:
        return 'assets/cover/cover10.png';
      case CoverTheme.nature2:
        return 'assets/cover/cover12.png';
      case CoverTheme.nature3:
        return 'assets/cover/cover13.png';
      case CoverTheme.nature4:
        return 'assets/cover/cover11.png';
      case CoverTheme.texture1:
        return 'assets/cover/cover15.png';
      case CoverTheme.abstract2:
        return 'assets/cover/cover16.png';
      case CoverTheme.architecture1:
        return 'assets/cover/cover1.png';
      case CoverTheme.architecture2:
        return 'assets/cover/cover2.png';
      case CoverTheme.abstract4:
        return 'assets/cover/cover5.png';
      case CoverTheme.abstract5:
        return 'assets/cover/cover6.png';
      case CoverTheme.abstract6:
        return 'assets/cover/cover7.png';
      case CoverTheme.texture2:
        return 'assets/cover/cover8.png';
      case CoverTheme.classic:
      case CoverTheme.classic2:
      default:
        return null;
    }
  }


  LinearGradient get gradient {
    switch (this) {
      case CoverTheme.classic:
        return const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.classic2:
        return const LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF232526)],
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

      case CoverTheme.nature3:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.nature4:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.architecture1:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.architecture2:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.abstract1:
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
      case CoverTheme.abstract5:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.abstract6:
        return const LinearGradient(
          colors: [Color(0xFFEEE8DF), Color(0xFFD6D0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case CoverTheme.texture1:
        return const LinearGradient(
          colors: [Color(0xFFD7D2CC), Color(0xFF304352)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CoverTheme.texture2:
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