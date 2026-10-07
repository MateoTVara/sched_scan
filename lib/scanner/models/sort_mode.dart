/// How a block's cards are ordered: the primary key of the sort.
///
/// [roomThenTime] keeps a block's sub-headings as room names and sorts each
/// room's cards by start time — the table's own reading order.
/// [timeThenRoom] flips it: a block's cards are grouped by start time, so its
/// sub-headings become the times (`08:00`, `10:00`, …) and the rooms appear
/// inside each group in table order.
///
/// Only ever one direction applies — see [SortOrder] — and the top-level
/// section titles (`Bloque A`, `LOSA DEPORTIVA`) are the same either way, so
/// switching modes leaves the filter row's selection alone.
enum SortMode {
  /// Rooms first (table order), then start time inside each room.
  roomThenTime,

  /// Start time first, grouped; rooms in table order inside each group.
  timeThenRoom,
}

/// Which end the time ordering starts from. Blocks stay alphabetical and
/// rooms keep their table order in both directions — this only moves the
/// cards (and, in [SortMode.timeThenRoom], the time sub-headings).
enum SortOrder {
  /// Earliest start time first; entries without a printed time always last.
  ascending,

  /// Latest start time first; entries without a printed time still last.
  descending,
}
