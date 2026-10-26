part of 'liquid_snackbar_library.dart';

/// Semantic accent and icon, independently configurable for each variant.
@immutable
class LiquidSnackbarVariantStyle {
  /// Creates a style with a non-color status indicator.
  const LiquidSnackbarVariantStyle({required this.color, required this.icon});

  /// Accent applied subtly over the neutral glass surface.
  final Color color;

  /// Status icon; decorative because the live region describes the content.
  final IconData icon;
}

/// Styling tokens. The dark neutral surface keeps white text readable in both
/// app brightness modes; status is communicated by accent and icon together.
@immutable
class LiquidSnackbarTheme extends ThemeExtension<LiquidSnackbarTheme> {
  /// Creates a complete theme; add it to ThemeData.extensions.
  const LiquidSnackbarTheme({
    this.blurSigma = 20,
    this.solid = false,
    this.surfaceColor = const Color(0xFF0B0B0D),
    this.surfaceOpacity = 0.94,
    this.tintOpacity = 0.08,
    this.border = const BorderSide(color: Color(0x33FFFFFF)),
    this.radius = 20,
    this.pillRadius = 999,
    this.shadows = const [
      BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, 6)),
    ],
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
    this.margin = const EdgeInsets.all(16),
    this.maxWidth = 520,
    this.alignment = AlignmentDirectional.center,
    this.gap = 8,
    this.messageStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.4,
    ),
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    this.actionStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeOutCubic,
    this.variantStyles = const {
      LiquidSnackbarVariant.success: LiquidSnackbarVariantStyle(
        color: Color(0xFF65D98C),
        icon: Icons.check_circle_outline_rounded,
      ),
      LiquidSnackbarVariant.error: LiquidSnackbarVariantStyle(
        color: Color(0xFFFF9B96),
        icon: Icons.error_outline_rounded,
      ),
      LiquidSnackbarVariant.warning: LiquidSnackbarVariantStyle(
        color: Color(0xFFFFD27D),
        icon: Icons.warning_amber_rounded,
      ),
      LiquidSnackbarVariant.info: LiquidSnackbarVariantStyle(
        color: Color(0xFF91C8FF),
        icon: Icons.info_outline_rounded,
      ),
      LiquidSnackbarVariant.neutral: LiquidSnackbarVariantStyle(
        color: Color(0xFFD2D2DC),
        icon: Icons.notifications_none_rounded,
      ),
    },
  }) : assert(blurSigma >= 0),
       assert(surfaceOpacity >= 0 && surfaceOpacity <= 1),
       assert(tintOpacity >= 0 && tintOpacity <= 1),
       assert(maxWidth > 0),
       assert(radius >= 0),
       assert(pillRadius >= 0),
       assert(gap >= 0);

  /// Backdrop blur radius; not animated.
  final double blurSigma;

  /// Disable backdrop filtering and use an opaque surface instead.
  final bool solid;

  /// Base glass color, independent of the status accent.
  final Color surfaceColor;

  /// Opacity of the glass base. Ignored in solid/reduced-motion modes.
  final double surfaceOpacity;

  /// Amount of variant color blended into the base.
  final double tintOpacity;

  /// Surface outline.
  final BorderSide border;

  /// Card corner radius.
  final double radius;

  /// Compact pill corner radius.
  final double pillRadius;

  /// Shadows outside the clipped glass surface.
  final List<BoxShadow> shadows;

  /// Internal, direction-aware content padding.
  final EdgeInsetsGeometry padding;

  /// Distance from safe-area/keyboard edges.
  final EdgeInsetsGeometry margin;

  /// Maximum width on tablets and larger viewports.
  final double maxWidth;

  /// Horizontal placement in the available width; vertical placement uses edge.
  final AlignmentGeometry alignment;

  /// Space between simultaneously visible notifications.
  final double gap;

  /// Body typography; inherits unspecified attributes from the ambient theme.
  final TextStyle messageStyle;

  /// Heading typography.
  final TextStyle titleStyle;

  /// Action typography.
  final TextStyle actionStyle;

  /// Entry and exit duration. Reduced-motion fades are capped at 80ms.
  final Duration animationDuration;

  /// Entry and exit easing.
  final Curve animationCurve;

  /// Per-variant styles. Missing entries use the neutral default.
  final Map<LiquidSnackbarVariant, LiquidSnackbarVariantStyle> variantStyles;

  @override
  LiquidSnackbarTheme copyWith({
    double? blurSigma,
    bool? solid,
    Color? surfaceColor,
    double? surfaceOpacity,
    double? tintOpacity,
    BorderSide? border,
    double? radius,
    double? pillRadius,
    List<BoxShadow>? shadows,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? maxWidth,
    AlignmentGeometry? alignment,
    double? gap,
    TextStyle? messageStyle,
    TextStyle? titleStyle,
    TextStyle? actionStyle,
    Duration? animationDuration,
    Curve? animationCurve,
    Map<LiquidSnackbarVariant, LiquidSnackbarVariantStyle>? variantStyles,
  }) => LiquidSnackbarTheme(
    blurSigma: blurSigma ?? this.blurSigma,
    solid: solid ?? this.solid,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
    tintOpacity: tintOpacity ?? this.tintOpacity,
    border: border ?? this.border,
    radius: radius ?? this.radius,
    pillRadius: pillRadius ?? this.pillRadius,
    shadows: shadows ?? this.shadows,
    padding: padding ?? this.padding,
    margin: margin ?? this.margin,
    maxWidth: maxWidth ?? this.maxWidth,
    alignment: alignment ?? this.alignment,
    gap: gap ?? this.gap,
    messageStyle: messageStyle ?? this.messageStyle,
    titleStyle: titleStyle ?? this.titleStyle,
    actionStyle: actionStyle ?? this.actionStyle,
    animationDuration: animationDuration ?? this.animationDuration,
    animationCurve: animationCurve ?? this.animationCurve,
    variantStyles: variantStyles ?? this.variantStyles,
  );

  @override
  LiquidSnackbarTheme lerp(covariant LiquidSnackbarTheme? other, double t) {
    if (other == null) return this;
    double mix(double a, double b) => a + (b - a) * t;
    return copyWith(
      blurSigma: mix(blurSigma, other.blurSigma),
      solid: t < .5 ? solid : other.solid,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      surfaceOpacity: mix(surfaceOpacity, other.surfaceOpacity),
      tintOpacity: mix(tintOpacity, other.tintOpacity),
      border: BorderSide.lerp(border, other.border, t),
      radius: mix(radius, other.radius),
      pillRadius: mix(pillRadius, other.pillRadius),
      shadows: BoxShadow.lerpList(shadows, other.shadows, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
      maxWidth: mix(maxWidth, other.maxWidth),
      alignment: AlignmentGeometry.lerp(alignment, other.alignment, t),
      gap: mix(gap, other.gap),
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      actionStyle: TextStyle.lerp(actionStyle, other.actionStyle, t),
      animationDuration: Duration(
        microseconds: mix(
          animationDuration.inMicroseconds.toDouble(),
          other.animationDuration.inMicroseconds.toDouble(),
        ).round(),
      ),
      animationCurve: t < .5 ? animationCurve : other.animationCurve,
      variantStyles: {
        for (final variant in LiquidSnackbarVariant.values)
          if (variantStyles.containsKey(variant) ||
              other.variantStyles.containsKey(variant))
            variant: LiquidSnackbarVariantStyle(
              color: Color.lerp(
                variantStyles[variant]?.color ?? Colors.white,
                other.variantStyles[variant]?.color ?? Colors.white,
                t,
              )!,
              icon:
                  (t < .5
                          ? variantStyles[variant]
                          : other.variantStyles[variant])
                      ?.icon ??
                  Icons.info_outline,
            ),
      },
    );
  }
}
