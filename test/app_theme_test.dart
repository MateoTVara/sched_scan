import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sched_scan/app_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('buildAppTheme', () {
    test('pins the brand orange as primary in both brightnesses', () {
      expect(brandPrimary, const Color(0xFFFF6600));

      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        expect(theme.colorScheme.primary, brandPrimary);
        expect(theme.colorScheme.brightness, brightness);
      }
    });

    test('puts a readable foreground on the brand orange', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        expect(theme.colorScheme.onPrimary, Colors.black);
        expect(
          _contrast(theme.colorScheme.onPrimary, brandPrimary),
          greaterThanOrEqualTo(7),
        );
      }
    });

    test('paints the AppBar and the FAB in the brand colours', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final appBar = theme.appBarTheme;
        expect(appBar.backgroundColor, brandPrimary);
        expect(appBar.foregroundColor, theme.colorScheme.onPrimary);
        // No elevation tint over the bar once content scrolls under it.
        expect(appBar.scrolledUnderElevation, 0);

        final fab = theme.floatingActionButtonTheme;
        expect(fab.backgroundColor, brandPrimary);
        expect(fab.foregroundColor, theme.colorScheme.onPrimary);
      }
    });

    test('keeps light and dark as distinct palettes', () {
      final light = buildAppTheme(Brightness.light);
      final dark = buildAppTheme(Brightness.dark);

      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
      expect(light.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
      expect(light.scaffoldBackgroundColor, light.colorScheme.surface);
      expect(dark.scaffoldBackgroundColor, dark.colorScheme.surface);
    });
  });
}
