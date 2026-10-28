import 'dart:convert';

import 'package:flutter/material.dart';

/// VietQR Napas247 (EMVCo) + bộ vẽ QR tại máy, không phụ thuộc mạng.
class VietQr {
  static const bankBin = '970403';
  static const accountNumber = '070118746463';

  static String tlv(String id, String value) {
    if (value.length > 99) value = value.substring(0, 99);
    return '$id${value.length.toString().padLeft(2, '0')}$value';
  }

  static int crc16(String data) {
    var crc = 0xFFFF;
    for (final unit in data.codeUnits) {
      crc ^= unit << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }
    return crc;
  }

  static String emvCoPayload({
    required int amount,
    required String transferCode,
    String accountNumber = VietQr.accountNumber,
    String bankBin = VietQr.bankBin,
  }) {
    final consumer = tlv('00', bankBin) + tlv('01', accountNumber);
    final merchant =
        tlv('00', 'A000000727') + tlv('01', consumer) + tlv('02', 'QRIBFTTA');
    final additional = tlv('08', transferCode);
    final amountField = amount > 0 ? tlv('54', '$amount') : '';
    final body =
        '000201010212${tlv('38', merchant)}5303704$amountField'
        '5802VN${tlv('62', additional)}6304';
    final crc = crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$body$crc';
  }
}

class QrMatrix {
  final int size;
  final List<List<bool>> modules;
  const QrMatrix(this.size, this.modules);
  bool at(int x, int y) => modules[y][x];

  static QrMatrix encode(String text) {
    final bytes = utf8.encode(text);
    final version = _versionFor(bytes.length);
    final data = _buildData(bytes, version);
    final codewords = _withEcc(data, version);
    return _place(codewords, version);
  }
}

const _eccM = [
  // ecPerBlock, g1Blocks, g1Data, g2Blocks, g2Data
  [0, 0, 0, 0, 0],
  [10, 1, 16, 0, 0],
  [16, 1, 28, 0, 0],
  [26, 1, 44, 0, 0],
  [18, 2, 32, 0, 0],
  [24, 2, 43, 0, 0],
  [16, 4, 27, 0, 0],
  [18, 4, 31, 0, 0],
  [22, 2, 38, 2, 39],
  [22, 3, 36, 2, 37],
  [26, 4, 43, 1, 44],
];

const _alignments = <int, List<int>>{
  2: [6, 18],
  3: [6, 22],
  4: [6, 26],
  5: [6, 30],
  6: [6, 34],
  7: [6, 22, 38],
  8: [6, 24, 42],
  9: [6, 26, 46],
  10: [6, 28, 50],
};

int _versionFor(int byteCount) {
  for (var v = 1; v <= 10; v++) {
    final info = _eccM[v];
    final capacity = info[1] * info[2] + info[3] * info[4];
    final countBits = v <= 9 ? 8 : 16;
    final need = ((4 + countBits + byteCount * 8) + 7) ~/ 8;
    if (need <= capacity) return v;
  }
  throw StateError('Nội dung QR vượt quá dung lượng.');
}

List<int> _buildData(List<int> bytes, int version) {
  final info = _eccM[version];
  final capacity = info[1] * info[2] + info[3] * info[4];
  final bits = <int>[];
  void put(int value, int len) {
    for (var i = len - 1; i >= 0; i--) {
      bits.add((value >> i) & 1);
    }
  }

  put(0x4, 4);
  put(bytes.length, version <= 9 ? 8 : 16);
  for (final b in bytes) {
    put(b, 8);
  }
  final remaining = capacity * 8 - bits.length;
  put(0, remaining < 4 ? remaining : 4);
  while (bits.length % 8 != 0) {
    bits.add(0);
  }
  final data = <int>[];
  for (var i = 0; i < bits.length; i += 8) {
    var v = 0;
    for (var j = 0; j < 8; j++) {
      v = (v << 1) | bits[i + j];
    }
    data.add(v);
  }
  var pad = 0xEC;
  while (data.length < capacity) {
    data.add(pad);
    pad = pad == 0xEC ? 0x11 : 0xEC;
  }
  return data;
}

final _gfExp = List<int>.filled(512, 0);
final _gfLog = List<int>.filled(256, 0);
bool _gfReady = false;

void _initGf() {
  if (_gfReady) return;
  var x = 1;
  for (var i = 0; i < 255; i++) {
    _gfExp[i] = x;
    _gfLog[x] = i;
    x <<= 1;
    if (x & 0x100 != 0) x ^= 0x11d;
  }
  for (var i = 255; i < 512; i++) {
    _gfExp[i] = _gfExp[i - 255];
  }
  _gfReady = true;
}

int _gfMul(int a, int b) {
  if (a == 0 || b == 0) return 0;
  return _gfExp[_gfLog[a] + _gfLog[b]];
}

List<int> _rsGenerator(int degree) {
  var poly = [1];
  for (var i = 0; i < degree; i++) {
    final next = List<int>.filled(poly.length + 1, 0);
    for (var j = 0; j < poly.length; j++) {
      next[j] ^= poly[j];
      next[j + 1] ^= _gfMul(poly[j], _gfExp[i]);
    }
    poly = next;
  }
  return poly;
}

List<int> _rsRemainder(List<int> data, List<int> generator) {
  final result = List<int>.filled(generator.length - 1, 0, growable: true);
  for (final b in data) {
    final factor = b ^ result[0];
    result.removeAt(0);
    result.add(0);
    if (factor == 0) continue;
    for (var i = 0; i < result.length; i++) {
      result[i] ^= _gfMul(generator[i + 1], factor);
    }
  }
  return result;
}

List<int> _withEcc(List<int> data, int version) {
  _initGf();
  final info = _eccM[version];
  final ecCount = info[0];
  final generator = _rsGenerator(ecCount);
  final blocks = <List<int>>[];
  final eccBlocks = <List<int>>[];
  var offset = 0;
  void addGroup(int count, int dataLen) {
    for (var i = 0; i < count; i++) {
      final block = data.sublist(offset, offset + dataLen);
      offset += dataLen;
      blocks.add(block);
      eccBlocks.add(_rsRemainder(block, generator));
    }
  }

  addGroup(info[1], info[2]);
  addGroup(info[3], info[4]);
  final result = <int>[];
  final maxData = info[2] > info[4] ? info[2] : info[4];
  for (var i = 0; i < maxData; i++) {
    for (final block in blocks) {
      if (i < block.length) result.add(block[i]);
    }
  }
  for (var i = 0; i < ecCount; i++) {
    for (final block in eccBlocks) {
      result.add(block[i]);
    }
  }
  return result;
}

bool _maskBit(int mask, int x, int y) {
  switch (mask) {
    case 0:
      return (x + y) % 2 == 0;
    case 1:
      return y % 2 == 0;
    case 2:
      return x % 3 == 0;
    case 3:
      return (x + y) % 3 == 0;
    case 4:
      return (y ~/ 2 + x ~/ 3) % 2 == 0;
    case 5:
      return (x * y) % 2 + (x * y) % 3 == 0;
    case 6:
      return ((x * y) % 2 + (x * y) % 3) % 2 == 0;
    default:
      return ((x * y) % 3 + (x + y) % 2) % 2 == 0;
  }
}

int _formatBits(int mask) {
  const eccM = 0;
  var data = (eccM << 3) | mask;
  var d = data << 10;
  for (var i = 14; i >= 10; i--) {
    if ((d >> i) & 1 != 0) d ^= 0x537 << (i - 10);
  }
  return ((data << 10) | d) ^ 0x5412;
}

int _versionBits(int version) {
  var d = version << 12;
  for (var i = 17; i >= 12; i--) {
    if ((d >> i) & 1 != 0) d ^= 0x1F25 << (i - 12);
  }
  return (version << 12) | d;
}

QrMatrix _place(List<int> codewords, int version) {
  final size = 21 + 4 * (version - 1);
  final reserved = List.generate(size, (_) => List<bool>.filled(size, false));
  final best = List.generate(size, (_) => List<bool>.filled(size, false));

  void setReserved(int x, int y) {
    if (x >= 0 && y >= 0 && x < size && y < size) reserved[y][x] = true;
  }

  void finder(int left, int top) {
    for (var y = -1; y <= 7; y++) {
      for (var x = -1; x <= 7; x++) {
        setReserved(left + x, top + y);
      }
    }
  }

  finder(0, 0);
  finder(size - 7, 0);
  finder(0, size - 7);
  for (var i = 0; i < size; i++) {
    setReserved(i, 6);
    setReserved(6, i);
  }
  final aligns = _alignments[version] ?? const <int>[];
  for (final y in aligns) {
    for (final x in aligns) {
      if ((x == 6 && y == 6) ||
          (x == 6 && y == size - 7) ||
          (x == size - 7 && y == 6)) {
        continue;
      }
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          setReserved(x + dx, y + dy);
        }
      }
    }
  }
  for (var i = 0; i < 15; i++) {
    setReserved(i < 8 ? (i < 6 ? i : i + 1) : size - 15 + i, 8);
    setReserved(8, i < 8 ? (i < 6 ? i : i + 1) : size - 15 + i);
  }
  setReserved(8, size - 8);
  setReserved(size - 8, 8);
  if (version >= 7) {
    for (var i = 0; i < 6; i++) {
      for (var j = 0; j < 3; j++) {
        setReserved(size - 11 + j, i);
        setReserved(i, size - 11 + j);
      }
    }
  }

  int score(List<List<bool>> grid) {
    var total = 0;
    for (var y = 0; y < size; y++) {
      var run = 1;
      for (var x = 1; x < size; x++) {
        if (grid[y][x] == grid[y][x - 1]) {
          run++;
          if (run == 5) total += 3;
          if (run > 5) total++;
        } else {
          run = 1;
        }
      }
    }
    for (var x = 0; x < size; x++) {
      var run = 1;
      for (var y = 1; y < size; y++) {
        if (grid[y][x] == grid[y - 1][x]) {
          run++;
          if (run == 5) total += 3;
          if (run > 5) total++;
        } else {
          run = 1;
        }
      }
    }
    var dark = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x + 1 < size &&
            y + 1 < size &&
            grid[y][x] == grid[y][x + 1] &&
            grid[y][x] == grid[y + 1][x] &&
            grid[y][x] == grid[y + 1][x + 1]) {
          total += 3;
        }
        if (grid[y][x]) dark++;
      }
    }
    total += ((dark * 100 / (size * size) - 50).abs() / 5).floor() * 10;
    return total;
  }

  void paintPattern(List<List<bool>> grid, int mask) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        grid[y][x] = false;
      }
    }
    void finderPaint(int left, int top) {
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 7; x++) {
          final edge = x == 0 || y == 0 || x == 6 || y == 6;
          final core = x >= 2 && x <= 4 && y >= 2 && y <= 4;
          grid[top + y][left + x] = edge || core;
        }
      }
    }

    finderPaint(0, 0);
    finderPaint(size - 7, 0);
    finderPaint(0, size - 7);
    for (var i = 8; i < size - 8; i++) {
      grid[6][i] = i % 2 == 0;
      grid[i][6] = i % 2 == 0;
    }
    for (final cy in aligns) {
      for (final cx in aligns) {
        if ((cx == 6 && cy == 6) ||
            (cx == 6 && cy == size - 7) ||
            (cx == size - 7 && cy == 6)) {
          continue;
        }
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            grid[cy + dy][cx + dx] =
                dx.abs() == 2 || dy.abs() == 2 || (dx == 0 && dy == 0);
          }
        }
      }
    }
    grid[size - 8][8] = true;
    var bit = 0;
    final totalBits = codewords.length * 8;
    var direction = -1;
    var x = size - 1;
    var y = size - 1;
    while (x > 0) {
      if (x == 6) x--;
      while (true) {
        for (var dx = 0; dx < 2; dx++) {
          final xx = x - dx;
          if (reserved[y][xx]) continue;
          var dark = false;
          if (bit < totalBits) {
            dark = ((codewords[bit >> 3] >> (7 - (bit & 7))) & 1) == 1;
            bit++;
          }
          if (_maskBit(mask, xx, y)) dark = !dark;
          grid[y][xx] = dark;
        }
        y += direction;
        if (y < 0 || y >= size) {
          y -= direction;
          direction = -direction;
          break;
        }
      }
      x -= 2;
    }
    final format = _formatBits(mask);
    for (var i = 0; i < 6; i++) {
      grid[8][i] = ((format >> i) & 1) == 1;
    }
    grid[8][7] = ((format >> 6) & 1) == 1;
    grid[8][8] = ((format >> 7) & 1) == 1;
    grid[7][8] = ((format >> 8) & 1) == 1;
    for (var i = 9; i < 15; i++) {
      grid[14 - i][8] = ((format >> i) & 1) == 1;
    }
    for (var i = 0; i < 7; i++) {
      grid[size - 1 - i][8] = ((format >> i) & 1) == 1;
    }
    for (var i = 7; i < 15; i++) {
      grid[8][size - 15 + i] = ((format >> i) & 1) == 1;
    }
    grid[size - 8][8] = true;
    if (version >= 7) {
      final vb = _versionBits(version);
      var k = 0;
      for (var a = 0; a < 6; a++) {
        for (var b = 0; b < 3; b++) {
          final dark = ((vb >> k) & 1) == 1;
          grid[a][size - 11 + b] = dark;
          grid[size - 11 + b][a] = dark;
          k++;
        }
      }
    }
  }

  var bestScore = 1 << 30;
  for (var mask = 0; mask < 8; mask++) {
    final grid = List.generate(size, (_) => List<bool>.filled(size, false));
    paintPattern(grid, mask);
    final s = score(grid);
    if (s < bestScore) {
      bestScore = s;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          best[y][x] = grid[y][x];
        }
      }
    }
  }
  return QrMatrix(size, best);
}

class VietQrImage extends StatefulWidget {
  final List<String> urls;
  final String payload;
  final double size;
  const VietQrImage({
    super.key,
    required this.urls,
    required this.payload,
    this.size = 244,
  });

  @override
  State<VietQrImage> createState() => _VietQrImageState();
}

class _VietQrImageState extends State<VietQrImage> {
  int _index = 0;

  QrMatrix? _matrixFor(String payload) {
    try {
      return QrMatrix.encode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant VietQrImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls != widget.urls || oldWidget.payload != widget.payload) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // QR EMVCo vẽ offline là nguồn chính nên luôn hiển thị ngay cả khi
    // ảnh VietQR/SePay bị 301/CORS. Ảnh nhà cung cấp chỉ là dự phòng
    // khi cần đối chiếu, không chặn hiển thị QR.
    final matrix = _matrixFor(widget.payload);
    if (matrix == null) {
      if (_index >= widget.urls.length) {
        return const Center(child: Text('Không tạo được mã QR.'));
      }
      return Image.network(
        widget.urls[_index],
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index++);
          });
          return const Center(child: CircularProgressIndicator());
        },
      );
    }
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _QrPainter(matrix),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrMatrix matrix;
  const _QrPainter(this.matrix);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final quiet = 4;
    final n = matrix.size + quiet * 2;
    final cell = size.width / n;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (!matrix.at(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH((x + quiet) * cell, (y + quiet) * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.matrix != matrix;
}
