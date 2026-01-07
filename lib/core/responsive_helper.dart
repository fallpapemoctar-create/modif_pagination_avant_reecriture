import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities for adaptive UI
class ResponsiveHelper {
  // Breakpoints
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 900;
  static const double desktopMaxWidth = 1200;
  static const double largeDesktopMaxWidth = 1600;

  /// Check if current screen is mobile size
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMaxWidth;

  /// Check if current screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMaxWidth && width < tabletMaxWidth;
  }

  /// Check if current screen is desktop size
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxWidth;

  /// Check if current screen is large desktop
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= largeDesktopMaxWidth;

  /// Get responsive padding based on screen size
  static EdgeInsets getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, {double? mobile, double? tablet, double? desktop}) {
    if (isMobile(context)) return mobile ?? 8.0;
    if (isTablet(context)) return tablet ?? 12.0;
    return desktop ?? 16.0;
  }

  /// Get dialog width based on screen size
  static double getDialogWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isMobile(context)) return width * 0.95;
    if (isTablet(context)) return width * 0.7;
    if (width < desktopMaxWidth) return 600;
    return 700;
  }

  /// Get grid column count based on width
  static int getGridColumns(BuildContext context, {int? mobile, int? tablet, int? desktop}) {
    if (isMobile(context)) return mobile ?? 1;
    if (isTablet(context)) return tablet ?? 2;
    return desktop ?? 3;
  }

  /// Get responsive font size
  static double getFontSize(BuildContext context, {double base = 16.0}) {
    if (isMobile(context)) return base;
    if (isTablet(context)) return base + 1.0;
    return base + 2.0;
  }

  /// Build responsive widget based on screen size
  static Widget buildResponsive(
    BuildContext context, {
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  /// Get card elevation based on screen size
  static double getCardElevation(BuildContext context) {
    return isMobile(context) ? 1.0 : 2.0;
  }

  /// Get responsive border radius
  static BorderRadius getBorderRadius(BuildContext context) {
    return BorderRadius.circular(isMobile(context) ? 8.0 : 12.0);
  }
}

/// Widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.buildResponsive(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

/// Responsive container that adjusts max width based on screen
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 
            (ResponsiveHelper.isDesktop(context) ? 1400 : double.infinity),
        ),
        padding: padding ?? ResponsiveHelper.getPagePadding(context),
        child: child,
      ),
    );
  }
}
