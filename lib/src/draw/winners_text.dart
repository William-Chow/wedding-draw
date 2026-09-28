/// The winners as plain text, one per line in draw order, for the clipboard:
/// pasted into a chat or a note for whoever hands out the prizes.
///
/// ```text
/// William & Anna – lucky draw winners
/// #1  007
/// #2  153
/// #3  250  (outside the current range)
/// ```
String winnersAsText({
  required String title,
  required List<int> winners,
  required String Function(int number) format,
  required bool Function(int number) isInRange,
}) {
  final heading = title.trim();
  final lines = <String>[
    heading.isEmpty ? 'Lucky draw winners' : '$heading – lucky draw winners',
    for (var i = 0; i < winners.length; i++)
      '#${i + 1}  ${format(winners[i])}'
          '${isInRange(winners[i]) ? '' : '  (outside the current range)'}',
  ];
  return lines.join('\n');
}
