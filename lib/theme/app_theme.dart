import 'package:flutter/material.dart';

/// Semantic colors for scientific evidence presentation across light and dark modes.
@immutable
class EvidenceThemeColors extends ThemeExtension<EvidenceThemeColors> {
  const EvidenceThemeColors({
    required this.opposesInk,
    required this.opposesSurface,
    required this.opposesBorder,
    required this.reinforcesInk,
    required this.reinforcesSurface,
    required this.reinforcesBorder,
    required this.strongAssociationInk,
    required this.strongAssociationSurface,
    required this.strongAssociationBorder,
    required this.weakAssociationInk,
    required this.weakAssociationSurface,
    required this.weakAssociationBorder,
    required this.strongReversalInk,
    required this.strongReversalSurface,
    required this.strongReversalBorder,
    required this.moderateReversalInk,
    required this.moderateReversalSurface,
    required this.moderateReversalBorder,
    required this.nominalReversalInk,
    required this.nominalReversalSurface,
    required this.nominalReversalBorder,
    required this.mimicInk,
    required this.mimicSurface,
    required this.mimicBorder,
    required this.neutralInk,
    required this.neutralSurface,
    required this.neutralBorder,
  });

  final Color opposesInk;
  final Color opposesSurface;
  final Color opposesBorder;

  final Color reinforcesInk;
  final Color reinforcesSurface;
  final Color reinforcesBorder;

  final Color strongAssociationInk;
  final Color strongAssociationSurface;
  final Color strongAssociationBorder;

  final Color weakAssociationInk;
  final Color weakAssociationSurface;
  final Color weakAssociationBorder;

  final Color strongReversalInk;
  final Color strongReversalSurface;
  final Color strongReversalBorder;

  final Color moderateReversalInk;
  final Color moderateReversalSurface;
  final Color moderateReversalBorder;

  final Color nominalReversalInk;
  final Color nominalReversalSurface;
  final Color nominalReversalBorder;

  final Color mimicInk;
  final Color mimicSurface;
  final Color mimicBorder;

  final Color neutralInk;
  final Color neutralSurface;
  final Color neutralBorder;

  static const light = EvidenceThemeColors(
    opposesInk: Color(0xFF00695C),
    opposesSurface: Color(0xFFE0F2F1),
    opposesBorder: Color(0xFF80CBC4),
    reinforcesInk: Color(0xFFC62828),
    reinforcesSurface: Color(0xFFFFEBEE),
    reinforcesBorder: Color(0xFFFFCDD2),
    strongAssociationInk: Color(0xFF1B5E20),
    strongAssociationSurface: Color(0xFFE8F5E9),
    strongAssociationBorder: Color(0xFFA5D6A7),
    weakAssociationInk: Color(0xFF827717),
    weakAssociationSurface: Color(0xFFF9FBE7),
    weakAssociationBorder: Color(0xFFE6EE9C),
    strongReversalInk: Color(0xFF4A148C),
    strongReversalSurface: Color(0xFFEDE7F6),
    strongReversalBorder: Color(0xFFD1C4E9),
    moderateReversalInk: Color(0xFF1565C0),
    moderateReversalSurface: Color(0xFFE3F2FD),
    moderateReversalBorder: Color(0xFFBBDEFB),
    nominalReversalInk: Color(0xFF00838F),
    nominalReversalSurface: Color(0xFFE0F7FA),
    nominalReversalBorder: Color(0xFF80DEEA),
    mimicInk: Color(0xFFD84315),
    mimicSurface: Color(0xFFFBE9E7),
    mimicBorder: Color(0xFFFFCCBC),
    neutralInk: Color(0xFF475569),
    neutralSurface: Color(0xFFF1F5F9),
    neutralBorder: Color(0xFFCBD5E1),
  );

  static const dark = EvidenceThemeColors(
    opposesInk: Color(0xFF2DD4BF),
    opposesSurface: Color(0xFF0A2B26),
    opposesBorder: Color(0xFF134E48),
    reinforcesInk: Color(0xFFF87171),
    reinforcesSurface: Color(0xFF381014),
    reinforcesBorder: Color(0xFF7F1D1D),
    strongAssociationInk: Color(0xFF4ADE80),
    strongAssociationSurface: Color(0xFF0E3019),
    strongAssociationBorder: Color(0xFF166534),
    weakAssociationInk: Color(0xFFFACC15),
    weakAssociationSurface: Color(0xFF2C2808),
    weakAssociationBorder: Color(0xFF713F12),
    strongReversalInk: Color(0xFFC084FC),
    strongReversalSurface: Color(0xFF2A1046),
    strongReversalBorder: Color(0xFF6B21A8),
    moderateReversalInk: Color(0xFF60A5FA),
    moderateReversalSurface: Color(0xFF0F264A),
    moderateReversalBorder: Color(0xFF1E40AF),
    nominalReversalInk: Color(0xFF38BDF8),
    nominalReversalSurface: Color(0xFF0C2B38),
    nominalReversalBorder: Color(0xFF075985),
    mimicInk: Color(0xFFFB923C),
    mimicSurface: Color(0xFF36180C),
    mimicBorder: Color(0xFF9A3412),
    neutralInk: Color(0xFF94A3B8),
    neutralSurface: Color(0xFF1E293B),
    neutralBorder: Color(0xFF334155),
  );

  @override
  ThemeExtension<EvidenceThemeColors> copyWith({
    Color? opposesInk,
    Color? opposesSurface,
    Color? opposesBorder,
    Color? reinforcesInk,
    Color? reinforcesSurface,
    Color? reinforcesBorder,
    Color? strongAssociationInk,
    Color? strongAssociationSurface,
    Color? strongAssociationBorder,
    Color? weakAssociationInk,
    Color? weakAssociationSurface,
    Color? weakAssociationBorder,
    Color? strongReversalInk,
    Color? strongReversalSurface,
    Color? strongReversalBorder,
    Color? moderateReversalInk,
    Color? moderateReversalSurface,
    Color? moderateReversalBorder,
    Color? nominalReversalInk,
    Color? nominalReversalSurface,
    Color? nominalReversalBorder,
    Color? mimicInk,
    Color? mimicSurface,
    Color? mimicBorder,
    Color? neutralInk,
    Color? neutralSurface,
    Color? neutralBorder,
  }) {
    return EvidenceThemeColors(
      opposesInk: opposesInk ?? this.opposesInk,
      opposesSurface: opposesSurface ?? this.opposesSurface,
      opposesBorder: opposesBorder ?? this.opposesBorder,
      reinforcesInk: reinforcesInk ?? this.reinforcesInk,
      reinforcesSurface: reinforcesSurface ?? this.reinforcesSurface,
      reinforcesBorder: reinforcesBorder ?? this.reinforcesBorder,
      strongAssociationInk: strongAssociationInk ?? this.strongAssociationInk,
      strongAssociationSurface:
          strongAssociationSurface ?? this.strongAssociationSurface,
      strongAssociationBorder:
          strongAssociationBorder ?? this.strongAssociationBorder,
      weakAssociationInk: weakAssociationInk ?? this.weakAssociationInk,
      weakAssociationSurface:
          weakAssociationSurface ?? this.weakAssociationSurface,
      weakAssociationBorder:
          weakAssociationBorder ?? this.weakAssociationBorder,
      strongReversalInk: strongReversalInk ?? this.strongReversalInk,
      strongReversalSurface:
          strongReversalSurface ?? this.strongReversalSurface,
      strongReversalBorder: strongReversalBorder ?? this.strongReversalBorder,
      moderateReversalInk: moderateReversalInk ?? this.moderateReversalInk,
      moderateReversalSurface:
          moderateReversalSurface ?? this.moderateReversalSurface,
      moderateReversalBorder:
          moderateReversalBorder ?? this.moderateReversalBorder,
      nominalReversalInk: nominalReversalInk ?? this.nominalReversalInk,
      nominalReversalSurface:
          nominalReversalSurface ?? this.nominalReversalSurface,
      nominalReversalBorder: nominalReversalBorder ?? this.nominalReversalBorder,
      mimicInk: mimicInk ?? this.mimicInk,
      mimicSurface: mimicSurface ?? this.mimicSurface,
      mimicBorder: mimicBorder ?? this.mimicBorder,
      neutralInk: neutralInk ?? this.neutralInk,
      neutralSurface: neutralSurface ?? this.neutralSurface,
      neutralBorder: neutralBorder ?? this.neutralBorder,
    );
  }

  @override
  ThemeExtension<EvidenceThemeColors> lerp(
    covariant ThemeExtension<EvidenceThemeColors>? other,
    double t,
  ) {
    if (other is! EvidenceThemeColors) return this;
    return EvidenceThemeColors(
      opposesInk: Color.lerp(opposesInk, other.opposesInk, t)!,
      opposesSurface: Color.lerp(opposesSurface, other.opposesSurface, t)!,
      opposesBorder: Color.lerp(opposesBorder, other.opposesBorder, t)!,
      reinforcesInk: Color.lerp(reinforcesInk, other.reinforcesInk, t)!,
      reinforcesSurface:
          Color.lerp(reinforcesSurface, other.reinforcesSurface, t)!,
      reinforcesBorder: Color.lerp(reinforcesBorder, other.reinforcesBorder, t)!,
      strongAssociationInk:
          Color.lerp(strongAssociationInk, other.strongAssociationInk, t)!,
      strongAssociationSurface: Color.lerp(
          strongAssociationSurface, other.strongAssociationSurface, t)!,
      strongAssociationBorder: Color.lerp(
          strongAssociationBorder, other.strongAssociationBorder, t)!,
      weakAssociationInk:
          Color.lerp(weakAssociationInk, other.weakAssociationInk, t)!,
      weakAssociationSurface:
          Color.lerp(weakAssociationSurface, other.weakAssociationSurface, t)!,
      weakAssociationBorder:
          Color.lerp(weakAssociationBorder, other.weakAssociationBorder, t)!,
      strongReversalInk:
          Color.lerp(strongReversalInk, other.strongReversalInk, t)!,
      strongReversalSurface:
          Color.lerp(strongReversalSurface, other.strongReversalSurface, t)!,
      strongReversalBorder:
          Color.lerp(strongReversalBorder, other.strongReversalBorder, t)!,
      moderateReversalInk:
          Color.lerp(moderateReversalInk, other.moderateReversalInk, t)!,
      moderateReversalSurface: Color.lerp(
          moderateReversalSurface, other.moderateReversalSurface, t)!,
      moderateReversalBorder:
          Color.lerp(moderateReversalBorder, other.moderateReversalBorder, t)!,
      nominalReversalInk:
          Color.lerp(nominalReversalInk, other.nominalReversalInk, t)!,
      nominalReversalSurface:
          Color.lerp(nominalReversalSurface, other.nominalReversalSurface, t)!,
      nominalReversalBorder:
          Color.lerp(nominalReversalBorder, other.nominalReversalBorder, t)!,
      mimicInk: Color.lerp(mimicInk, other.mimicInk, t)!,
      mimicSurface: Color.lerp(mimicSurface, other.mimicSurface, t)!,
      mimicBorder: Color.lerp(mimicBorder, other.mimicBorder, t)!,
      neutralInk: Color.lerp(neutralInk, other.neutralInk, t)!,
      neutralSurface: Color.lerp(neutralSurface, other.neutralSurface, t)!,
      neutralBorder: Color.lerp(neutralBorder, other.neutralBorder, t)!,
    );
  }
}

/// Central design system configuring Light and Dark themes for OncoRepurpose.
abstract final class AppTheme {
  // Light Palette
  static const Color lightPrimary = Color(0xFFE11D48); // Rose 600
  static const Color lightPrimaryDark = Color(0xFFBE123C); // Rose 700
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextMuted = Color(0xFF64748B); // Slate 500

  // Dark Palette (OLED Midnight Slate)
  static const Color darkPrimary = Color(0xFFFB7185); // Rose 400
  static const Color darkPrimaryDark = Color(0xFFF43F5E); // Rose 500
  static const Color darkBackground = Color(0xFF0B0F19); // Midnight Abyss
  static const Color darkSurface = Color(0xFF131B2E); // Deep Slate
  static const Color darkCardSurface = Color(0xFF172033);
  static const Color darkBorder = Color(0xFF2E3A52);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFE4E6),
      onPrimaryContainer: lightPrimaryDark,
      secondary: Color(0xFF0284C7), // Sky 600
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: Color(0xFFF1F5F9),
      outline: lightBorder,
      outlineVariant: Color(0xFFCBD5E1),
      error: Color(0xFFDC2626),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      extensions: const [EvidenceThemeColors.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: lightCardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCardSurface,
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: lightTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCardSurface,
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 1.8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightPrimary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: darkPrimary,
      onPrimary: Color(0xFF0F172A),
      primaryContainer: darkPrimaryDark,
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF38BDF8),
      onSecondary: Color(0xFF0F172A),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkCardSurface,
      outline: darkBorder,
      outlineVariant: Color(0xFF3B4863),
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      extensions: const [EvidenceThemeColors.dark],
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: darkTextPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkBorder, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 1.8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
