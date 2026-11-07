class SheetHeaderInfo {
  final String? area;
  final String? venue;
  final String? date;
  final String? rawTopLeft;
  final String? rawTopRight;

  const SheetHeaderInfo({
    this.area,
    this.venue,
    this.date,
    this.rawTopLeft,
    this.rawTopRight,
  });

  bool get isEmpty =>
      (area == null || area!.trim().isEmpty) &&
      (venue == null || venue!.trim().isEmpty) &&
      (date == null || date!.trim().isEmpty) &&
      (rawTopLeft == null || rawTopLeft!.trim().isEmpty) &&
      (rawTopRight == null || rawTopRight!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  SheetHeaderInfo copyWith({
    String? area,
    String? venue,
    String? date,
    String? rawTopLeft,
    String? rawTopRight,
  }) {
    return SheetHeaderInfo(
      area: area ?? this.area,
      venue: venue ?? this.venue,
      date: date ?? this.date,
      rawTopLeft: rawTopLeft ?? this.rawTopLeft,
      rawTopRight: rawTopRight ?? this.rawTopRight,
    );
  }

  SheetHeaderInfo mergeWith(SheetHeaderInfo other) {
    return SheetHeaderInfo(
      area: (area != null && area!.trim().isNotEmpty) ? area : other.area,
      venue: (venue != null && venue!.trim().isNotEmpty) ? venue : other.venue,
      date: (date != null && date!.trim().isNotEmpty) ? date : other.date,
      rawTopLeft: (rawTopLeft != null && rawTopLeft!.trim().isNotEmpty)
          ? rawTopLeft
          : other.rawTopLeft,
      rawTopRight: (rawTopRight != null && rawTopRight!.trim().isNotEmpty)
          ? rawTopRight
          : other.rawTopRight,
    );
  }

  /// Generates filename in format: [area]_[venue]_[date].txt
  /// E.g. reyon_flormar_26_12_2026.txt
  /// Returns null if none of area, venue, or date are found.
  String? generateFileName() {
    final cleanArea = cleanPart(area);
    final cleanVenue = cleanPart(venue);
    final cleanDateStr = cleanDate(date);

    final parts = <String>[];
    if (cleanArea.isNotEmpty) parts.add(cleanArea);
    if (cleanVenue.isNotEmpty) parts.add(cleanVenue);
    if (cleanDateStr.isNotEmpty) parts.add(cleanDateStr);

    if (parts.isEmpty) return null;
    return '${parts.join('_')}.txt';
  }

  static SheetHeaderInfo fromExtracted({
    String? area,
    String? venue,
    String? date,
    String? rawTopLeft,
    String? rawTopRight,
  }) {
    String? resolvedArea = area?.trim();
    String? resolvedVenue = venue?.trim();
    String? resolvedDate = date?.trim();

    // Check if rawTopLeft has date and/or venue
    if (rawTopLeft != null && rawTopLeft.trim().isNotEmpty) {
      final leftText = rawTopLeft.trim();

      // 1. Date extraction
      final dateMatch = RegExp(r'(\d{1,2})[\.\/\-_](\d{1,2})[\.\/\-_](\d{2,4})')
          .firstMatch(leftText);
      if (dateMatch != null) {
        if (resolvedDate == null || resolvedDate.isEmpty) {
          final day = dateMatch.group(1)!.padLeft(2, '0');
          final month = dateMatch.group(2)!.padLeft(2, '0');
          var year = dateMatch.group(3)!;
          if (year.length == 2) year = '20$year';
          resolvedDate = '${day}_${month}_$year';
        }

        // 2. Venue extraction: "(tarih sonrası ilk iki tire arasındaki kelime)"
        if (resolvedVenue == null || resolvedVenue.isEmpty) {
          final afterDate = leftText.substring(dateMatch.end);
          // Look between first two dashes in text after date
          final doubleDash =
              RegExp(r'[-–—]\s*([^\s-–—]+(?:\s+[^\s-–—]+)*?)\s*[-–—]')
                  .firstMatch(afterDate);
          if (doubleDash != null && doubleDash.group(1)!.trim().isNotEmpty) {
            resolvedVenue = doubleDash.group(1)!.trim();
          } else {
            // If only 1 dash after date
            final singleDash =
                RegExp(r'[-–—]\s*([^\s-–—]+(?:\s+[^\s-–—]+)*)')
                    .firstMatch(afterDate);
            if (singleDash != null && singleDash.group(1)!.trim().isNotEmpty) {
              resolvedVenue = singleDash.group(1)!.trim();
            }
          }
        }
      } else {
        // If no date found in rawTopLeft, check for text between dashes
        if (resolvedVenue == null || resolvedVenue.isEmpty) {
          final doubleDash =
              RegExp(r'[-–—]\s*([^\s-–—]+(?:\s+[^\s-–—]+)*?)\s*[-–—]')
                  .firstMatch(leftText);
          if (doubleDash != null && doubleDash.group(1)!.trim().isNotEmpty) {
            resolvedVenue = doubleDash.group(1)!.trim();
          }
        }
      }
    }

    // Check if rawTopRight can provide area
    if ((resolvedArea == null || resolvedArea.isEmpty) &&
        rawTopRight != null &&
        rawTopRight.trim().isNotEmpty) {
      resolvedArea = rawTopRight.trim();
    }

    return SheetHeaderInfo(
      area: resolvedArea,
      venue: resolvedVenue,
      date: resolvedDate,
      rawTopLeft: rawTopLeft,
      rawTopRight: rawTopRight,
    );
  }

  static String cleanPart(String? text) {
    if (text == null) return '';
    var s = text.trim();
    if (s.isEmpty) return '';

    // Turkish character mapping
    const turkishMap = {
      'İ': 'i', 'I': 'i', 'ı': 'i',
      'Ğ': 'g', 'ğ': 'g',
      'Ü': 'u', 'ü': 'u',
      'Ş': 's', 'ş': 's',
      'Ö': 'o', 'ö': 'o',
      'Ç': 'c', 'ç': 'c',
    };
    for (final entry in turkishMap.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    s = s.toLowerCase();

    // Remove common prefixes like "alan:", "alan adi:", "bölüm:"
    s = s.replaceAll(RegExp(r'^(alan\s*adi|alan|bolum|bolge)\s*[:\-_]\s*'), '');

    // Replace spaces, dots, dashes, slashes with underscore
    s = s.replaceAll(RegExp(r'[\s\.\-\/\\:]+'), '_');

    // Keep only alphanumeric and underscore
    s = s.replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Clean duplicate underscores and leading/trailing underscores
    s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return s;
  }

  static String cleanDate(String? rawDate) {
    if (rawDate == null) return '';
    final s = rawDate.trim();
    if (s.isEmpty) return '';

    final match =
        RegExp(r'(\d{1,2})[\.\/\-_](\d{1,2})[\.\/\-_](\d{2,4})').firstMatch(s);
    if (match != null) {
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!.padLeft(2, '0');
      var year = match.group(3)!;
      if (year.length == 2) year = '20$year';
      return '${day}_${month}_$year';
    }
    return cleanPart(s);
  }
}

