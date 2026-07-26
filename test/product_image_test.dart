import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:backend_test_dashboard/widgets/record_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts any image ratio for square card cropping', () async {
    final square = await _png(12, 12);
    final wide = await _png(12, 8);

    final squareSize = await inspectProductImage(square);
    final wideSize = await inspectProductImage(wide);

    expect((squareSize.width, squareSize.height), (12, 12));
    expect((wideSize.width, wideSize.height), (12, 8));
  });

  test('adds one dollar sign to stored product details', () {
    expect(productDetailsForStorage('4.50 · Iced'), r'$4.50 · Iced');
    expect(productDetailsForStorage(r'$4.50 · Iced'), r'$4.50 · Iced');
    expect(productDetailsForEditing(r'$4.50 · Iced'), '4.50 · Iced');
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
