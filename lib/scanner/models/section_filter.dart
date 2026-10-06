import 'package:flutter/foundation.dart';
import 'package:sched_scan/schedule/models/entry_section.dart';

/// The card list's filter row: every section of the current scan, the
/// current selection, and how to flip one.
///
/// An empty selection shows no section at all — the view puts its
/// "Selecciona un bloque." prompt in their place. That is the initial
/// state, and what the row falls back to when the last chip is
/// deselected; a non-empty selection narrows the list to its sections,
/// and each new scan starts over with nothing selected.
class SectionFilter {
  const SectionFilter({
    required this.sections,
    required this.selected,
    required this.toggle,
  });

  /// Every section in display order — one chip each, labelled with a
  /// block's letter or a blockless room's full name.
  final List<EntrySection> sections;

  /// The selected section titles; empty means no section is shown.
  final Set<String> selected;

  /// Hides a shown section or shows a hidden one.
  final ValueChanged<String> toggle;

  /// Whether the section titled [title] is currently shown.
  bool isSelected(String title) => selected.contains(title);
}
