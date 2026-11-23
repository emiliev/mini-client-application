// Regenerates the original placeholder portraits under `assets/characters/`.
//
//   fvm dart run utility/mc_fixtures_media/tool/generate_placeholders.dart
//
// Each image is a seeded two-colour gradient with a plain silhouette: no
// third-party art (ADR-0005 §5). Output is deterministic, so a re-run produces
// byte-identical files.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _count = 24;
const _scales = {'': 1, '2.0x/': 2, '3.0x/': 3};
const _baseWidth = 60;
const _baseHeight = 90;

void main() {
  final out = Directory('utility/mc_fixtures_media/assets/characters');
  for (final entry in _scales.entries) {
    Directory('${out.path}/${entry.key}').createSync(recursive: true);
    for (var i = 0; i < _count; i++) {
      final name = i.toString().padLeft(3, '0');
      File('${out.path}/${entry.key}$name.png').writeAsBytesSync(
        _png(_baseWidth * entry.value, _baseHeight * entry.value, i),
      );
    }
  }
}

List<int> _hsv(double h, double s, double v) {
  final c = v * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - c;
  final (r, g, b) = switch (h ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  return [r + m, g + m, b + m].map((e) => (e * 255).round()).toList();
}

Uint8List _png(int w, int h, int index) {
  final hue = (index * 360 / _count) % 360;
  final top = _hsv(hue, 0.55, 0.95);
  final bottom = _hsv((hue + 40) % 360, 0.75, 0.45);
  final shade = _hsv(hue, 0.4, 0.25);
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    final t = y / (h - 1);
    for (var x = 0; x < w; x++) {
      // Head circle and shoulders ellipse, in unit coordinates.
      final u = x / w - 0.5;
      final v = y / h;
      final head = math.sqrt(u * u + math.pow((v - 0.36) * 0.66, 2)) < 0.2;
      final body = math.sqrt(u * u + math.pow((v - 0.95) * 0.55, 2)) < 0.42;
      for (var c = 0; c < 3; c++) {
        raw.addByte(
          head || body ? shade[c] : (top[c] + (bottom[c] - top[c]) * t).round(),
        );
      }
    }
  }
  final idat = ZLibEncoder(level: 9).convert(raw.toBytes());
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    ..add(
      _chunk(
        'IHDR',
        (ByteData(13)
              ..setUint32(0, w)
              ..setUint32(4, h)
              ..setUint8(8, 8) // bit depth
              ..setUint8(9, 2)) // colour type: RGB
            .buffer
            .asUint8List(),
      ),
    )
    ..add(_chunk('IDAT', idat))
    ..add(_chunk('IEND', const []));
  return out.toBytes();
}

Uint8List _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final bytes = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(body)
    ..add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  return bytes.toBytes();
}

final List<int> _table = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _table[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return c ^ 0xffffffff;
}
