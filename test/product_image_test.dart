import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:backend_test_dashboard/widgets/record_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts square product images and rejects non-square images', () async {
    final square = await _png(12, 12);
    final wide = await _png(12, 8);

    final size = await inspectSquareProductImage(square);
    expect((size.width, size.height), (12, 12));
    await expectLater(
      inspectSquareProductImage(wide),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('1:1'),
        ),
      ),
    );
  });
}

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF6F3A),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
