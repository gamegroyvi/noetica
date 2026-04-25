import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Strict black-and-white theme. No gradients, sharp edges, thin lines.
class AppTheme {
  static const _radius = 8.0;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: const Color(0xFFFFFFFF),
        surface: const Color(0xFFF5F5F5),
        fg: const Color(0xFF000000),
        muted: const Color(0xFF6B6B6B),
        line: const Color(0xFFE5E5E5),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: const Color(0xFF000000),
        surface: const Color(0xFF0A0A0A),
        fg: const Color(0xFFFFFFFF),
        muted: const Color(0xFF8A8A8A),
        line: const Color(0xFF1F1F1F),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color fg,
    required Color muted,
    required Color line,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: fg,
      displayColor: fg,
    );
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: fg,
        onPrimary: bg,
        secondary: fg,
        onSecondary: bg,
        error: fg,
        onError: bg,
        surface: surface,
        onSurface: fg,
      ),
      textTheme: textTheme,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: line, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fg,
          foregroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: line, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: fg, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: fg,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: fg),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: bg),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: fg,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: surface,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? fg : muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? fg : muted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fg,
        foregroundColor: bg,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius * 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: fg,
        textColor: fg,
        tileColor: bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius * 1.5),
          side: BorderSide(color: line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: fg,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: bg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: <ThemeExtension<dynamic>>[
        NoeticaPalette(
          fg: fg,
          bg: bg,
          surface: surface,
          muted: muted,
          line: line,
        ),
      ],
    );
  }
}

class NoeticaPalette extends ThemeExtension<NoeticaPalette> {
  const NoeticaPalette({
    required this.fg,
    required this.bg,
    required this.surface,
    required this.muted,
    required this.line,
  });

  final Color fg;
  final Color bg;
  final Color surface;
  final Color muted;
  final Color line;

  @override
  NoeticaPalette copyWith({
    Color? fg,
    Color? bg,
    Color? surface,
    Color? muted,
    Color? line,
  }) =>
      NoeticaPalette(
        fg: fg ?? this.fg,
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        muted: muted ?? this.muted,
        line: line ?? this.line,
      );

  @override
  NoeticaPalette lerp(ThemeExtension<NoeticaPalette>? other, double t) {
    if (other is! NoeticaPalette) return this;
    return NoeticaPalette(
      fg: Color.lerp(fg, other.fg, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension NoeticaPaletteX on BuildContext {
  NoeticaPalette get palette =>
      Theme.of(this).extension<NoeticaPalette>() ??
      const NoeticaPalette(
        fg: Colors.white,
        bg: Colors.black,
        surface: Color(0xFF0A0A0A),
        muted: Color(0xFF8A8A8A),
        line: Color(0xFF1F1F1F),
      );
}
