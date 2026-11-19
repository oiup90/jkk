import 'package:flutter/material.dart';

import 'design.dart';
import 'user_tokens.dart';

export 'user_tokens.dart';

ThemeData userAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: growthPurple,
    primary: growthPurple,
    secondary: userTeal,
    surface: Colors.white,
    onSurface: userInk,
    outline: const Color(0xff8b869e),
    outlineVariant: userLine,
    error: const Color(0xffb3364d),
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    colorScheme: scheme,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: userLine),
  );
  return base.copyWith(
    scaffoldBackgroundColor: userCanvas,
    textTheme: base.textTheme
        .apply(bodyColor: userInk, displayColor: userInk)
        .copyWith(
          headlineSmall: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: userInk,
            letterSpacing: -.6,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 21,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: userInk,
            letterSpacing: -.4,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: userInk,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.6,
            color: userInk,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            height: 1.55,
            color: userInk,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            height: 1.5,
            color: userMuted,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: userCanvas,
      foregroundColor: userInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: userInk,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: 64,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: userInk,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        height: 1.5,
        color: userMuted,
      ),
      iconColor: growthPurple,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: growthPurple,
        backgroundColor: const Color(0xffeeebf8),
        minimumSize: const Size(48, 48),
        iconSize: 21,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: shape.copyWith(side: const BorderSide(color: userLine)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: const TextStyle(color: userMuted, fontSize: 13),
      hintStyle: const TextStyle(color: userMuted, fontSize: 12),
      helperMaxLines: 4,
      errorMaxLines: 4,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: growthPurple, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: Color(0xffd6ccef)),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: userInk,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xffede7ff),
      side: const BorderSide(color: userLine),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: userInk,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(
      color: userLine,
      thickness: 1,
      space: 24,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: growthPurple,
      collapsedIconColor: userMuted,
      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: growthPurple,
      foregroundColor: Colors.white,
      elevation: 1,
      shape: shape,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: growthPurple,
      linearTrackColor: Color(0xffe9e3f7),
      strokeWidth: 3,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: userInk,
      shape: shape,
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
      ),
    ),
  );
}
