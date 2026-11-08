import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/motion.dart';

/// A screen with an iOS large title that collapses into the navigation bar
/// as the content scrolls, on the grouped background.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onRefresh,
    this.absorbing = false,
  });

  /// Ignores taps on the content (not the bar) while work is in progress.
  final bool absorbing;

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Enables iOS pull-to-refresh.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final refresh = onRefresh;
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(
            context.skin?.upperTitles ?? false ? title.toUpperCase() : title,
          ),
          trailing: trailing,
          border: null,
          // Opaque, and invisible until content scrolls under it (as on
          // iOS), so there's never a line under the title. No blur: it
          // costs frames on every scroll.
          backgroundColor: context.groupedBackground,
          automaticBackgroundVisibility: true,
          enableBackgroundFilterBlur: false,
        ),
        if (refresh != null) CupertinoSliverRefreshControl(onRefresh: refresh),
        SliverIgnorePointer(
          ignoring: absorbing,
          sliver: SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.margin,
                4,
                AppTheme.margin,
                32,
              ),
              // Sections fade and rise in, one after another, on first show.
              sliver: SliverList.list(
                children: [
                  for (final (i, c) in children.indexed)
                    c is Appear || c is SizedBox
                        ? c
                        : Appear(index: i, child: c),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    // The page colour is painted beneath the content rather than by the
    // scaffold, so the large-title bar stays clear until content scrolls
    // under it (as on iOS).
    return CupertinoPageScaffold(
      // Same colour at zero opacity, so the bar's fade-in never tints.
      backgroundColor: context.groupedBackground.withValues(alpha: 0),
      child: Stack(
        children: [
          const Positioned.fill(child: PageBackground()),
          scroll,
        ],
      ),
    );
  }
}

/// The card surface: the card colour with a soft lift in light mode (no
/// border or gradient), and an optional faint wash of [tint] from the top
/// corner. Shared by cards, tiles and list sections so they match.
ShapeDecoration cardSurface(
  BuildContext context, {
  Color? tint,
  Color? color,
  double radius = AppTheme.radius,
}) {
  final base = color ?? context.cardBackground;
  final t = tint;
  return ShapeDecoration(
    shape: context.outlinedShape(
      context.cardRadius(radius),
      context.cardOutline,
    ),
    color: t == null ? base : null,
    gradient: t == null
        ? null
        : RadialGradient(
            center: Alignment.topLeft,
            radius: 1.3,
            colors: [
              Color.alphaBlend(
                context
                    .resolve(t)
                    .withValues(alpha: context.isDark ? 0.10 : 0.06),
                base,
              ),
              base,
            ],
          ),
    shadows: context.cardShadows,
  );
}

/// A rounded content card. With [onTap] it shrinks slightly while pressed
/// and springs back.
class IosCard extends StatelessWidget {
  const IosCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Replaces the plain card colour, e.g. [IosStyle.cardRaised] for a card
  /// inside a sheet.
  final Color? color;

  /// Washes the card faintly in this colour from the top corner.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: cardSurface(context, tint: tint, color: color),
        child: child,
      ),
    );
  }
}

/// A round icon button for a page's header: a white disc with a soft lift
/// (raised graphite in dark mode), inside a full-size tap target.
class HeaderButton extends StatelessWidget {
  const HeaderButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: semanticLabel,
    onTap: onTap,
    scale: 0.9,
    child: SizedBox.square(
      dimension: AppTheme.minTapTarget + 4,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: ShapeDecoration(
            // A circle, drawn like the cards (by hand in a sketch skin).
            shape: context.outlinedShape(20, context.cardOutline),
            color: context.isDark ? context.cardRaised : context.cardBackground,
            shadows: context.cardShadows,
          ),
          child: Icon(icon, size: 20, color: context.labelColor),
        ),
      ),
    ),
  );
}

/// Section title with an optional trailing action ("Pinned · Edit").
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.top = 26,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  /// Space above the title: less inside a board widget, which sits in its
  /// own spaced slot.
  final double top;

  @override
  Widget build(BuildContext context) {
    final label = action;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.title3.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (label != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size.square(AppTheme.minTapTarget),
              onPressed: onAction,
              child: Text(
                label,
                style: context.subheadline.copyWith(
                  color: context.tint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded square in a soft pastel of [color], with the glyph in
/// [color]. Pass [solid] for a tile filled with [color] (a page's hero
/// glyph).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
    this.solid = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: AppTheme.squircle(size * 0.32),
        color: solid ? c : context.pastel(c),
      ),
      child: Icon(
        icon,
        color: solid ? context.onColor(c) : c,
        size: size * 0.56,
      ),
    );
  }
}

/// A rounded list section that lines up with the page margins, with a
/// spaced-capitals header.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.hasLeading = true,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final bool hasLeading;

  // Spacing as CupertinoListSection.insetGrouped, whose look this keeps.
  static const _headerPadding = EdgeInsetsDirectional.fromSTEB(20, 16, 20, 6);
  static const _footerPadding = EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10);
  static const _dividerStart = 14.0;
  static const _dividerLeading = 42.0;

  @override
  Widget build(BuildContext context) {
    final h = header;
    final f = footer;
    // Not CupertinoListSection: it clips rows to a fixed 10 pt corner,
    // which cut themed outlines and shadows in half.
    final divider = Container(
      margin: EdgeInsetsDirectional.only(
        start: _dividerStart + (hasLeading ? _dividerLeading : 0),
      ),
      color: context.separatorColor,
      height: 1 / MediaQuery.devicePixelRatioOf(context),
    );
    final rows = <Widget>[
      for (final (i, child) in children.indexed) ...[if (i > 0) divider, child],
    ];
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (h != null)
          Padding(
            padding: _headerPadding,
            child: Text(
              h.toUpperCase(),
              style: context.overline.copyWith(
                color: context.secondaryLabel,
                letterSpacing: 0.6,
              ),
            ),
          ),
        if (rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClippedCard(
              child: DefaultTextStyle(
                style: base,
                child: Column(children: rows),
              ),
            ),
          ),
        if (f != null)
          Padding(
            padding: _footerPadding,
            child: Text(
              f,
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
      ],
    );
  }
}

/// A list card: [child] clipped to the card's shape, with the card's
/// colour and shadow behind and its outline drawn on top, so pressed rows
/// and row backgrounds never cover or cut the corners.
class ClippedCard extends StatelessWidget {
  const ClippedCard({
    super.key,
    required this.child,
    this.radius = AppTheme.listRadius,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = context.outlinedShape(
      context.cardRadius(radius),
      BorderSide.none,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: context.cardBackground,
        shadows: context.cardShadows,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: shape.copyWith(side: context.cardOutline),
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: child,
        ),
      ),
    );
  }
}

/// Capsule progress bar used for goals and water.
class CapsuleProgress extends StatelessWidget {
  const CapsuleProgress({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: color.withValues(alpha: 0.18)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0.0, 1.0)),
                duration: Motion.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: ColoredBox(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS action sheet asking to confirm a destructive action.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String message,
  required String action,
  String? title,
}) async {
  final t = title;
  final ok = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: t == null ? null : Text(t),
      message: Text(message),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
    ),
  );
  return ok ?? false;
}

/// Simple iOS alert with an OK button.
Future<void> showMessage(
  BuildContext context, {
  required String title,
  required String message,
}) => showCupertinoDialog<void>(
  context: context,
  builder: (context) => CupertinoAlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);

/// A list row with a title and a value on the right ("Blood Type  O+").
/// The value is truncated if needed, and at large text sizes it moves under
/// the title, as iOS does at accessibility sizes.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.titleColor,
  });

  /// Text scale above which values stack under the title.
  static const _stackScale = 1.3;

  final String title;
  final String? value;

  /// Secondary line under the title.
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > _stackScale;
    final maxValueWidth = MediaQuery.sizeOf(context).width * 0.45;
    final tile = CupertinoListTile(
      leading: leading,
      title: Text(
        title,
        style: titleColor == null ? null : TextStyle(color: titleColor),
      ),
      subtitle: v != null && stacked
          ? Text(subtitle == null ? v : '$v · $subtitle')
          : subtitle == null
          ? null
          : Text(subtitle!),
      additionalInfo: v != null && !stacked
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxValueWidth),
              child: Text(v, overflow: TextOverflow.ellipsis),
            )
          : null,
      trailing: trailing ?? (chevron ? const CupertinoListTileChevron() : null),
      onTap: onTap,
    );
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: tile,
    );
  }
}

/// Scrolling page content that runs edge to edge under the translucent
/// bars (as on iOS) and can always scroll fully clear of the floating tab
/// bar and system navigation.
class PageList extends StatelessWidget {
  const PageList({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return ListView(
      controller: controller,
      // Scrolls only when the content doesn't fit, so a short page or
      // sheet stays still instead of bouncing like a web page.
      primary: false,
      padding: padding.copyWith(
        top: padding.top + insets.top,
        bottom: padding.bottom + insets.bottom,
      ),
      children: children,
    );
  }
}

/// The plain page background behind content that scrolls under clear
/// bars.
class PageBackground extends StatelessWidget {
  const PageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final pattern = context.skin?.pattern;
    return IgnorePointer(
      child: ColoredBox(
        color: context.groupedBackground,
        child: pattern == null
            ? null
            : RepaintBoundary(
                child: CustomPaint(
                  painter: PatternPainter(
                    pattern,
                    context.isDark ? pattern.dark : pattern.light,
                  ),
                  size: Size.infinite,
                ),
              ),
      ),
    );
  }
}

/// An alert with one text field. Returns the text when [confirm] is
/// tapped, '' for [clearLabel] (when given), and null when cancelled.
///
/// The dialog owns its controller, so it lives until the closing animation
/// has finished with the field.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String confirm,
  String initial = '',
  String? placeholder,
  String? suffix,
  String? clearLabel,
  TextAlign textAlign = TextAlign.start,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter> inputFormatters = const [],
}) => showCupertinoDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    confirm: confirm,
    initial: initial,
    placeholder: placeholder,
    suffix: suffix,
    clearLabel: clearLabel,
    textAlign: textAlign,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.confirm,
    required this.initial,
    required this.placeholder,
    required this.suffix,
    required this.clearLabel,
    required this.textAlign,
    required this.keyboardType,
    required this.inputFormatters,
  });

  final String title;
  final String confirm;
  final String initial;
  final String? placeholder;
  final String? suffix;
  final String? clearLabel;
  final TextAlign textAlign;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.suffix;
    final clear = widget.clearLabel;
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          autofocus: true,
          textAlign: widget.textAlign,
          placeholder: widget.placeholder,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          suffix: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(suffix),
                ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, clear == null ? null : ''),
          child: Text(clear ?? 'Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
