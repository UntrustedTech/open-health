import 'package:flutter/cupertino.dart';

import 'package:health_app/theme/skin.dart';

/// The "Soft" design (see DESIGN.md): a polished, Apple Health-like look.
/// A soft off-white canvas (or deep graphite), white cards with gentle
/// depth, Inter type, pastel icon chips, colourful rings and charts, and
/// one accent for what's selected.
abstract final class AppTheme {
  /// The default tint, iris. Widgets use `context.tint`, which follows the
  /// user's chosen accent.
  static const accent = Palette.iris;

  /// Corner radius of cards.
  static const radius = 24.0;

  /// Corner radius of a screen's hero card.
  static const heroRadius = 28.0;

  /// Space between cards.
  static const gap = 12.0;

  /// Text below 20 pt.
  static const textFamily = 'Inter';

  /// Inter's Display cut, for text of 20 pt and up (as SF Pro Display).
  static const displayFamily = 'InterDisplay';

  /// The family for [size]: Display cut from 20 pt.
  static String familyFor(double size) =>
      size >= 20 ? displayFamily : textFamily;

  /// Letter spacing for [size]: a touch open at small sizes, pulled in at
  /// heading sizes, as Apple's text styles do.
  static double tracking(double size) =>
      size >= 20 ? size * -0.02 : size * (0.006 - 0.0012 * (size - 11));

  /// Text style with the right family and tracking for [size].
  static TextStyle type(
    double size,
    FontWeight weight, {
    Color? color,
    bool tabular = false,
    String? family,
  }) => TextStyle(
    inherit: false,
    fontFamily: family ?? familyFor(size),
    fontSize: size,
    fontWeight: weight,
    // A theme's own font may be variable: its weight is an axis.
    fontVariations: family == null
        ? null
        : [FontVariation.weight(weight.value.toDouble())],
    letterSpacing: family == null ? tracking(size) : 0,
    color: color,
    textBaseline: TextBaseline.alphabetic,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );

  /// Soft-cornered shape for cards and tiles.
  static RoundedRectangleBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: side,
  );

  /// Corner radius of inset-grouped list sections.
  static const listRadius = 22.0;

  /// Height of the floating tab bar, including its margin.
  static const tabBarHeight = 64.0 + 12.0;

  /// Leading/trailing margin of page content.
  static const margin = 16.0;

  /// Minimum tap target from the HIG.
  static const minTapTarget = 44.0;

  /// The soft shadow under cards in light mode: one faint lift, kept to a
  /// single 16 px blur so long lists scroll smoothly on slower phones.
  /// Dark mode uses none.
  static const cardShadow = [
    BoxShadow(color: Color(0x12101828), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// The app's theme, or [skin]'s look over it.
  static CupertinoThemeData theme(
    Brightness? brightness, {
    Color accent = AppTheme.accent,
    Skin? skin,
  }) {
    final label = skin?.label ?? Palette.label;
    final f = skin?.fontFamily;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: accent,
      // Text on filled accent buttons.
      primaryContrastingColor: const CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF0D0E12),
      ),
      scaffoldBackgroundColor: skin?.background ?? Palette.background,
      barBackgroundColor: skin?.background ?? _barBackground,
      applyThemeToAll: true,
      textTheme: CupertinoTextThemeData(
        primaryColor: accent,
        textStyle: type(16, FontWeight.w500, color: label, family: f),
        actionTextStyle: type(16, FontWeight.w600, color: accent, family: f),
        navTitleTextStyle: type(17, FontWeight.w700, color: label, family: f),
        navLargeTitleTextStyle: type(
          32,
          FontWeight.w800,
          color: label,
          family: f,
        ),
        navActionTextStyle: type(16, FontWeight.w600, color: accent, family: f),
        tabLabelTextStyle: type(
          10,
          FontWeight.w600,
          color: skin?.tertiaryLabel ?? Palette.tertiaryLabel,
          family: f,
        ),
        pickerTextStyle: type(21, FontWeight.w500, color: label, family: f),
        dateTimePickerTextStyle: type(
          21,
          FontWeight.w500,
          color: label,
          family: f,
        ),
      ),
    );
  }

  /// Bars are opaque page colour: a translucent bar makes Cupertino blur
  /// whatever scrolls under it, which costs frames on Android.
  static const _barBackground = Palette.background;
}

/// The colour palette. Each colour adapts to light and dark mode: deep
/// enough in light mode for text on white (about 4.5:1), and brighter in
/// dark mode so data reads clearly on graphite.
abstract final class Palette {
  // Accents.
  static const iris = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF5850EC),
    darkColor: Color(0xFF8E88FF),
  );
  static const lime = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF4A7A00),
    darkColor: Color(0xFFCFF26A),
  );
  static const aurora = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF087565),
    darkColor: Color(0xFF45DCC0),
  );
  static const violet = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF7B3FE4),
    darkColor: Color(0xFFB79BFF),
  );

  // Surfaces.
  static const background = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF3F4F8),
    darkColor: Color(0xFF0D0E12),
  );
  static const card = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1A1B21),
  );
  static const cardRaised = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF3F4F8),
    darkColor: Color(0xFF25262E),
  );
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0x140F172A),
    darkColor: Color(0x17FFFFFF),
  );
  static const fill = CupertinoDynamicColor.withBrightness(
    color: Color(0x0D0F172A),
    darkColor: Color(0x14FFFFFF),
  );

  // Text.
  static const label = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0F1115),
    darkColor: Color(0xFFF4F5F7),
  );
  static const secondaryLabel = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF5B6170),
    darkColor: Color(0xFFA3A7B3),
  );
  static const tertiaryLabel = CupertinoDynamicColor.withBrightness(
    // AA (4.5:1) on cards and raised tiles in both modes.
    color: Color(0xFF636978),
    darkColor: Color(0xFF8F94A1),
  );

  // Data colours.
  static const red = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE0244A),
    darkColor: Color(0xFFFF5A73),
  );
  static const orange = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD0560A),
    darkColor: Color(0xFFFF9447),
  );
  static const yellow = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF9A6B00),
    darkColor: Color(0xFFFFD25A),
  );
  static const green = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF12824F),
    darkColor: Color(0xFF4CD98A),
  );
  static const mint = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF00806F),
    darkColor: Color(0xFF4FE0C4),
  );
  static const teal = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0A7D8C),
    darkColor: Color(0xFF4FD0E2),
  );
  static const cyan = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0A72A8),
    darkColor: Color(0xFF5CC4FA),
  );
  static const blue = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2563EB),
    darkColor: Color(0xFF7AA5FF),
  );
  static const indigo = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF4F46E5),
    darkColor: Color(0xFF9790FF),
  );
  static const purple = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A3FD6),
    darkColor: Color(0xFFC387FF),
  );
  static const pink = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD02A7A),
    darkColor: Color(0xFFFF77B4),
  );
  static const brown = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A6240),
    darkColor: Color(0xFFD1A47A),
  );
  static const grey = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6B7080),
    darkColor: Color(0xFF8F94A1),
  );
}

/// Shorthand for the app's text styles and colours, resolved for the
/// current brightness. Sizes scale with the user's text-size setting.
extension IosStyle on BuildContext {
  /// [color] for the current brightness, or the style's version of
  /// it for the app's surface and text colours.
  Color resolve(Color color) {
    final skin = SkinScope.of(this);
    if (skin != null) {
      final own = skin.replace(color, isDark);
      if (own != null) return own;
    }
    return CupertinoDynamicColor.resolve(color, this);
  }

  Color get labelColor => resolve(Palette.label);
  Color get secondaryLabel => resolve(Palette.secondaryLabel);
  Color get tertiaryLabel => resolve(Palette.tertiaryLabel);
  Color get separatorColor => resolve(Palette.separator);
  Color get groupedBackground => resolve(Palette.background);
  Color get cardBackground => resolve(Palette.card);
  Color get cardRaised => resolve(Palette.cardRaised);
  Color get fillColor => resolve(Palette.fill);

  /// The accent colour the user picked, resolved for the brightness.
  Color get tint => CupertinoTheme.of(this).primaryColor;
  bool get isDark => CupertinoTheme.brightnessOf(this) == Brightness.dark;

  /// Text and icons on a [labelColor] fill (the inverted, selected state
  /// of tabs and chips, and the black buttons).
  Color get onLabel =>
      isDark ? const Color(0xFF0D0E12) : const Color(0xFFFFFFFF);

  /// Ink or white, whichever reads better on [fill].
  Color onColor(Color fill) => fill.computeLuminance() > 0.45
      ? const Color(0xFF0D0E12)
      : const Color(0xFFFFFFFF);

  /// A soft pastel of [color] for icon chips and selected states: about
  /// 12% of the colour over the card in light mode, 18% in dark.
  Color pastel(Color color) => Color.alphaBlend(
    resolve(color).withValues(alpha: isDark ? 0.18 : 0.12),
    cardBackground,
  );

  Color get destructive => resolve(Palette.red);

  TextStyle get _base => CupertinoTheme.of(this).textTheme.textStyle;

  TextStyle _style(double size, FontWeight weight) {
    final family = SkinScope.of(this)?.fontFamily;
    return _base.copyWith(
      fontFamily: family ?? AppTheme.familyFor(size),
      fontSize: size,
      fontWeight: weight,
      fontVariations: family == null
          ? null
          : [FontVariation.weight(weight.value.toDouble())],
      letterSpacing: family == null ? AppTheme.tracking(size) : 0,
    );
  }

  /// Big numbers (values, timers): tabular figures so digits don't jitter
  /// as they change.
  TextStyle number(double size, {FontWeight weight = FontWeight.w700}) =>
      _style(
        size,
        weight,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  TextStyle get largeTitle => _style(32, FontWeight.w800);
  TextStyle get title1 => _style(26, FontWeight.w700);
  TextStyle get title2 => _style(22, FontWeight.w700);
  TextStyle get title3 => _style(20, FontWeight.w600);
  TextStyle get headline => _style(16, FontWeight.w600);
  TextStyle get body => _style(16, FontWeight.w500);
  TextStyle get subheadline => _style(14, FontWeight.w500);
  TextStyle get footnote => _style(13, FontWeight.w500);
  TextStyle get caption1 => _style(12, FontWeight.w500);
  TextStyle get caption2 => _style(11, FontWeight.w600);

  /// Small spaced capitals used as labels over values ("STEPS").
  TextStyle get overline => _style(
    11,
    FontWeight.w600,
  ).copyWith(letterSpacing: 0.6, color: secondaryLabel);
}
