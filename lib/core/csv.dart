/// Minimal CSV helpers (RFC-ish) with UTF-8 BOM for Excel.
library;

const csvUtf8Bom = '\uFEFF';

String escapeCsvField(Object? value) {
  if (value == null) return '';
  final s = value is DateTime
      ? value.toUtc().toIso8601String()
      : value.toString();
  if (s.contains('"') || s.contains(',') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String encodeCsvRow(List<Object?> fields) =>
    fields.map(escapeCsvField).join(',');

String encodeCsv({
  required List<String> headers,
  required List<List<Object?>> rows,
  bool withBom = true,
}) {
  final buf = StringBuffer();
  if (withBom) buf.write(csvUtf8Bom);
  buf.writeln(encodeCsvRow(headers));
  for (final row in rows) {
    buf.writeln(encodeCsvRow(row));
  }
  return buf.toString();
}

/// Parse a single CSV line respecting quotes.
List<String> parseCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}

List<List<String>> parseCsv(String raw) {
  var text = raw;
  if (text.startsWith(csvUtf8Bom)) {
    text = text.substring(1);
  }
  final lines = text.split(RegExp(r'\r?\n'));
  final rows = <List<String>>[];
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    rows.add(parseCsvLine(line));
  }
  return rows;
}

/// Merge rule: keep the side with the newer [updatedAt] (ISO strings).
T pickNewer<T>({
  required T local,
  required T incoming,
  required DateTime? Function(T) updatedAtOf,
}) {
  final a = updatedAtOf(local);
  final b = updatedAtOf(incoming);
  if (a == null) return incoming;
  if (b == null) return local;
  return !b.isBefore(a) ? incoming : local;
}
