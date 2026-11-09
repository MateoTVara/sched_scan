import 'package:flutter/foundation.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';

/// The card list's filter row: every section of the current scan, the one
/// section picked, and how to pick another.
///
/// No pick shows no section at all — the view puts its
/// "Selecciona un bloque." prompt in their place. That is the initial
/// state, and what the row falls back to when the picked chip is tapped
/// again; one pick narrows the list to its section, and each new scan
/// starts over with nothing picked.
class SectionFilter {
  const SectionFilter({
    required this.sections,
    required this.selected,
    required this.select,
  });

  /// Every section in display order — one chip each, labelled with a
  /// block's letter or a blockless room's full name.
  final List<EntrySection> sections;

  /// The title of the picked section; null means no section is shown.
  final String? selected;

  /// Picks the section titled [title], or clears the row when it is the
  /// pick already in effect — one section at a time.
  final ValueChanged<String> select;

  /// Whether the section titled [title] is currently shown.
  bool isSelected(String title) => selected == title;
}
