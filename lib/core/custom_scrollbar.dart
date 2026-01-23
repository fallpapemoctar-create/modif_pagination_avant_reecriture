import 'package:flutter/material.dart';

/// Custom scrollbar widget with DSFR styling
/// Always visible, rounded "tube" style, customizable colors
class CustomScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController controller;
  final Color? thumbColor;
  final Color? trackColor;
  final double? thickness;
  final double? radius;
  final bool isAlwaysShown;

  const CustomScrollbar({
    Key? key,
    required this.child,
    required this.controller,
    this.thumbColor,
    this.trackColor,
    this.thickness,
    this.radius,
    this.isAlwaysShown = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Responsive thickness based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultThickness = screenWidth < 600 ? 10.0 : (screenWidth < 900 ? 12.0 : 14.0);
    final defaultRadius = screenWidth < 600 ? 5.0 : (screenWidth < 900 ? 6.0 : 7.0);

    return RawScrollbar(
      controller: controller,
      thumbVisibility: isAlwaysShown,
      trackVisibility: isAlwaysShown,
      thickness: thickness ?? defaultThickness,
      radius: Radius.circular(radius ?? defaultRadius),
      thumbColor: thumbColor ?? const Color(0xFF000091), // Blue France by default
      trackColor: trackColor ?? const Color(0xFFEEEEEE), // Light gray track
      trackBorderColor: Colors.transparent,
      minThumbLength: 48.0,
      minOverscrollLength: 8.0,
      child: child,
    );
  }
}

/// Custom scrollbar with Blue France theme (default DSFR color)
class DsfrScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController controller;
  final bool isAlwaysShown;

  const DsfrScrollbar({
    Key? key,
    required this.child,
    required this.controller,
    this.isAlwaysShown = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollbar(
      controller: controller,
      thumbColor: const Color(0xFF000091), // Blue France
      trackColor: const Color(0xFFEEEEEE),
      isAlwaysShown: isAlwaysShown,
      child: child,
    );
  }
}

/// Custom scrollbar with Red Marianne theme
class DsfrScrollbarRed extends StatelessWidget {
  final Widget child;
  final ScrollController controller;
  final bool isAlwaysShown;

  const DsfrScrollbarRed({
    Key? key,
    required this.child,
    required this.controller,
    this.isAlwaysShown = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollbar(
      controller: controller,
      thumbColor: const Color(0xFFE1000F), // Red Marianne
      trackColor: const Color(0xFFEEEEEE),
      isAlwaysShown: isAlwaysShown,
      child: child,
    );
  }
}

/// Custom scrollbar with gray theme (subtle)
class DsfrScrollbarGray extends StatelessWidget {
  final Widget child;
  final ScrollController controller;
  final bool isAlwaysShown;

  const DsfrScrollbarGray({
    Key? key,
    required this.child,
    required this.controller,
    this.isAlwaysShown = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollbar(
      controller: controller,
      thumbColor: const Color(0xFF666666),
      trackColor: const Color(0xFFEEEEEE),
      isAlwaysShown: isAlwaysShown,
      child: child,
    );
  }
}
