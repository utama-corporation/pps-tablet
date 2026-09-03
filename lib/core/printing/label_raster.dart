import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Hasil rasterisasi satu halaman label ke gambar 1-bit.
///
/// [rgb] adalah buffer `numChannels: 3` dengan tiap channel bernilai 0 atau 255
/// (hasil dithering). Bentuk (width, height, rgb) sengaja dibuat primitif supaya
/// aman dikembalikan dari `Isolate.run`.
class MonoRaster {
  final int width;
  final int height;
  final Uint8List rgb;

  const MonoRaster(this.width, this.height, this.rgb);

  /// Nilai R pixel (x, y) — 0 = hitam (tinta), 255 = putih.
  int luma(int x, int y) => rgb[(y * width + x) * 3];
}

/// Pipeline pemrosesan gambar label yang dipakai bersama oleh jalur cetak
/// Bluetooth (ESC/POS) dan jalur cetak jaringan (TSPL):
///
/// flatten transparansi → grayscale → trim near-white → resize ke lebar dot
/// printer → Floyd–Steinberg dithering.
class LabelRaster {
  const LabelRaster._();

  /// PNG satu halaman → [MonoRaster] siap dikemas.
  ///
  /// [targetWidth] = lebar dot printer: 576 untuk thermal 80mm @203dpi, ~832
  /// untuk label 4" @203dpi. Static + argumen primitif → aman untuk
  /// `Isolate.run(() => LabelRaster.processPage(bytes, targetWidth: ...))`.
  static MonoRaster? processPage(Uint8List pngBytes, {int targetWidth = 576}) {
    var decoded = img.decodeImage(pngBytes);
    if (decoded == null) return null;

    // Flatten transparency → background putih (hindari background hitam).
    final whiteBg = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );
    img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(whiteBg, decoded);
    decoded = whiteBg;

    // Grayscale → trim near-white → resize → dither.
    // Dithering diperlukan agar grayscale (mis. watermark 0.3 opacity) tampil
    // sebagai pola titik pada printer 1-bit, bukan hilang.
    final gray = img.grayscale(decoded);
    final trimmed = _trimNearWhite(gray);
    final resized = img.copyResize(
      trimmed,
      width: targetWidth,
      interpolation: img.Interpolation.linear,
    );
    final dithered = _floydSteinbergDither(resized);

    return MonoRaster(dithered.width, dithered.height, dithered.getBytes());
  }

  /// Varian [processPage] untuk label berukuran tetap: satu halaman PDF di-fit
  /// (jaga rasio) ke kanvas persis [width] × [height] dot, di-tengah, sisanya
  /// putih — tanpa trim. Dipakai jalur TSPL saat ukuran label dikunci (mis. A6
  /// 100×150 mm → 800×1200 dot @203dpi).
  static MonoRaster? processPageFixed(
    Uint8List pngBytes, {
    required int width,
    required int height,
  }) {
    var decoded = img.decodeImage(pngBytes);
    if (decoded == null) return null;

    final whiteBg = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );
    img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(whiteBg, decoded);
    decoded = whiteBg;

    final gray = img.grayscale(decoded);
    final canvas = _fitOnCanvas(gray, width, height);
    final dithered = _floydSteinbergDither(canvas);

    return MonoRaster(dithered.width, dithered.height, dithered.getBytes());
  }

  /// Skala [src] agar muat dalam [w]×[h] (jaga rasio), lalu tempel di tengah
  /// kanvas putih berukuran persis [w]×[h].
  static img.Image _fitOnCanvas(img.Image src, int w, int h) {
    final scale = math.min(w / src.width, h / src.height);
    final dw = (src.width * scale).round().clamp(1, w);
    final dh = (src.height * scale).round().clamp(1, h);
    final scaled = img.copyResize(
      src,
      width: dw,
      height: dh,
      interpolation: img.Interpolation.linear,
    );

    final canvas = img.Image(width: w, height: h, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      canvas,
      scaled,
      dstX: ((w - dw) / 2).round(),
      dstY: ((h - dh) / 2).round(),
    );
    return canvas;
  }

  /// Rekonstruksi `img.Image` dari [MonoRaster] (mis. hasil dari isolate) untuk
  /// diberikan ke `Generator.imageRaster` pada jalur ESC/POS.
  static img.Image toImage(MonoRaster r) => img.Image.fromBytes(
    width: r.width,
    height: r.height,
    bytes: r.rgb.buffer,
    numChannels: 3,
  );

  /// Trim semua sisi yang hanya berisi pixel near-white (luminance >= [threshold]).
  /// Lebih robust dari `img.trim` karena tidak bergantung warna pojok tertentu.
  static img.Image _trimNearWhite(img.Image src, {int threshold = 250}) {
    final w = src.width;
    final h = src.height;

    bool isNearWhiteRow(int y) {
      for (var x = 0; x < w; x++) {
        if (src.getPixel(x, y).r < threshold) return false;
      }
      return true;
    }

    bool isNearWhiteCol(int x) {
      for (var y = 0; y < h; y++) {
        if (src.getPixel(x, y).r < threshold) return false;
      }
      return true;
    }

    var top = 0;
    var bottom = h - 1;
    var left = 0;
    var right = w - 1;

    while (top <= bottom && isNearWhiteRow(top)) {
      top++;
    }
    while (bottom >= top && isNearWhiteRow(bottom)) {
      bottom--;
    }
    while (left <= right && isNearWhiteCol(left)) {
      left++;
    }
    while (right >= left && isNearWhiteCol(right)) {
      right--;
    }

    if (top > bottom || left > right) return src;
    return img.copyCrop(
      src,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    );
  }

  static img.Image _floydSteinbergDither(img.Image src) {
    final w = src.width;
    final h = src.height;

    final buf = List<double>.filled(w * h, 0.0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        buf[y * w + x] = src.getPixel(x, y).r.toDouble();
      }
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final idx = y * w + x;
        final old = buf[idx].clamp(0.0, 255.0);
        final neu = old < 128.0 ? 0.0 : 255.0;
        final err = old - neu;
        buf[idx] = neu;

        if (x + 1 < w) buf[idx + 1] += err * 7 / 16;
        if (y + 1 < h) {
          if (x > 0) buf[idx + w - 1] += err * 3 / 16;
          buf[idx + w] += err * 5 / 16;
          if (x + 1 < w) buf[idx + w + 1] += err * 1 / 16;
        }
      }
    }

    final out = img.Image(width: w, height: h, numChannels: 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = buf[y * w + x] < 128.0 ? 0 : 255;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }
}
