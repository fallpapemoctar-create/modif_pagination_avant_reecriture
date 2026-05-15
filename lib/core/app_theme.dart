import 'package:flutter/material.dart';
import 'app_text_styles.dart';

/// Identifiants des thèmes disponibles
enum AmiThemeId { bleuOfficiel, ardoise, nuit }

/// Système de thèmes pour AMI.
/// Utilisation : ThemeData t = AmiTheme.of(AmiThemeId.nuit);
abstract class AmiTheme {
  // ── Couleurs primaires par thème ──────────────────────────────────────────

  /// Bleu officiel Marianne
  static const Color bleuOfficielPrimary   = Color(0xFF000091);
  static const Color bleuOfficielSecondary = Color(0xFFE1000F);

  /// Ardoise — bleu‑gris chaleureux
  static const Color ardoisePrimary        = Color(0xFF1E3A5F);
  static const Color ardoiseSecondary      = Color(0xFF2D9CDB);

  /// Nuit — identique à FMI
  static const Color nuitPrimary           = Color(0xFF1B3A8C);
  static const Color nuitSecondary         = Color(0xFF0D1B47);

  // ── Couleurs communes ─────────────────────────────────────────────────────
  static const Color surfaceWhite  = Colors.white;
  static const Color bgLight       = Color(0xFFF6F7FB);   // fond page
  static const Color border        = Color(0xFFE5E7EB);
  static const Color textPrimary   = Color(0xFF161616);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color errorRed      = Color(0xFFE1000F);

  // ── Constructeur de ThemeData ─────────────────────────────────────────────
  static ThemeData of(AmiThemeId id) {
    final primary = _primary(id);
    final secondary = _secondary(id);

    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        error: errorRed,
        surface: surfaceWhite,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bgLight,
      fontFamily: 'Marianne',

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: primary,
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: primary, size: 20),
        titleTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: AppTextStyles.bodySmall,
        hintStyle: AppTextStyles.bodySmall,
        errorStyle: const TextStyle(fontSize: 11),
      ),

      // ── Boutons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(80, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(80, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          minimumSize: const Size(40, 36),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(80, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFFCFCFD3), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // ── TabBar ────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicator: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            bottom: BorderSide(color: primary, width: 2.5),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),

      // ── DataTable ─────────────────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        headingRowHeight: 40,
        columnSpacing: 16,
        horizontalMargin: 12,
        dividerThickness: 1,
        headingTextStyle: AppTextStyles.tableHeader,
        dataTextStyle: AppTextStyles.tableCell,
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: primary.withValues(alpha: 0.12),
        checkmarkColor: primary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
        side: const BorderSide(color: border),
      ),

      // ── Tooltip ───────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(5),
        ),
        textStyle: const TextStyle(fontSize: 11, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ── PopupMenu ────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceWhite,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        textStyle: AppTextStyles.body,
      ),

      // ── TextTheme (centralisé) ────────────────────────────────────────────
      textTheme: const TextTheme(
        bodyLarge:   AppTextStyles.body,
        bodyMedium:  AppTextStyles.body,
        bodySmall:   AppTextStyles.bodySmall,
        titleLarge:  AppTextStyles.pageTitle,
        titleMedium: AppTextStyles.sectionTitle,
        titleSmall:  AppTextStyles.subTitle,
        labelLarge:  AppTextStyles.fieldLabel,
        labelMedium: AppTextStyles.tableHeader,
        labelSmall:  AppTextStyles.badge,
      ),
    );
  }

  static Color _primary(AmiThemeId id) {
    switch (id) {
      case AmiThemeId.bleuOfficiel: return bleuOfficielPrimary;
      case AmiThemeId.ardoise:      return ardoisePrimary;
      case AmiThemeId.nuit:         return nuitPrimary;
    }
  }

  static Color _secondary(AmiThemeId id) {
    switch (id) {
      case AmiThemeId.bleuOfficiel: return bleuOfficielSecondary;
      case AmiThemeId.ardoise:      return ardoiseSecondary;
      case AmiThemeId.nuit:         return nuitSecondary;
    }
  }

  /// Gradient hero du thème (login, splash…)
  static LinearGradient heroGradient(AmiThemeId id) {
    switch (id) {
      case AmiThemeId.bleuOfficiel:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF000091), Color(0xFF0010C8)],
        );
      case AmiThemeId.ardoise:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2D6A9F)],
        );
      case AmiThemeId.nuit:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B47), Color(0xFF1B3A8C)],
        );
    }
  }
}
