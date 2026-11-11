import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// LAME (`android/app/src/main/cpp/lame`, built as `libmp3lame.so`; LGPL,
/// unmodified, its own shared library) through dart:ffi: 48 kHz mono CBR
/// with the Info / LAME tag, which carries the encoder delay so players
/// that read it trim the silence LAME adds in front.
final class Mp3Encoder {
  Mp3Encoder._(this._lame, this._gfp);

  /// The library to load; tests point it at a desktop build of LAME.
  static String? libraryPath = Platform.isAndroid ? 'libmp3lame.so' : null;

  /// Whether MP3 can be made here (Android, or a test with [libraryPath]).
  static bool get available => _open() != null;

  static _Lame? _lib;
  static _Lame? _open() {
    final path = libraryPath;
    if (path == null) return null;
    try {
      return _lib ??= _Lame(DynamicLibrary.open(path));
    } on ArgumentError {
      return null;
    }
  }

  /// A new encoder at [sampleRate] and [bitRate] (bits per second), or
  /// null when LAME isn't here or refuses the settings.
  static Mp3Encoder? open({required int sampleRate, required int bitRate}) {
    final lame = _open();
    if (lame == null) return null;
    final gfp = lame.init();
    if (gfp == nullptr) return null;
    lame
      ..setInSampleRate(gfp, sampleRate)
      ..setOutSampleRate(gfp, sampleRate)
      ..setNumChannels(gfp, 1)
      ..setMode(gfp, 3) // MONO
      ..setVbr(gfp, 0) // vbr_off: CBR
      ..setBitRate(gfp, bitRate ~/ 1000)
      ..setWriteVbrTag(gfp, 1) // the Info frame, rewritten by [tag]
      ..setQuality(gfp, 2);
    if (lame.initParams(gfp) < 0) {
      lame.close(gfp);
      return null;
    }
    return Mp3Encoder._(lame, gfp);
  }

  final _Lame _lame;
  final Pointer<Void> _gfp;
  Pointer<Float> _pcm = nullptr;
  int _pcmLength = 0;
  Pointer<Uint8> _out = nullptr;
  int _outLength = 0;

  /// The MP3 bytes for [samples] (−1…1); may be empty while LAME buffers.
  Uint8List encode(Float32List samples) {
    if (samples.length > _pcmLength) {
      if (_pcm != nullptr) calloc.free(_pcm);
      _pcm = calloc<Float>(_pcmLength = samples.length);
    }
    _pcm.asTypedList(samples.length).setAll(0, samples);
    _ensureOut(samples.length * 5 ~/ 4 + 7200);
    final n = _lame.encodeFloat(
      _gfp,
      _pcm,
      _pcm,
      samples.length,
      _out,
      _outLength,
    );
    if (n < 0) throw StateError('LAME encode error $n');
    return Uint8List.fromList(_out.asTypedList(n));
  }

  /// The last frames.
  Uint8List flush() {
    _ensureOut(7200);
    final n = _lame.flush(_gfp, _out, _outLength);
    if (n < 0) throw StateError('LAME flush error $n');
    return Uint8List.fromList(_out.asTypedList(n));
  }

  /// The final Info / LAME tag frame, to write over the file's first
  /// frame (after [flush]).
  Uint8List tag() {
    _ensureOut(7200);
    final n = _lame.lametag(_gfp, _out, _outLength);
    return Uint8List.fromList(_out.asTypedList(n > _outLength ? 0 : n));
  }

  void close() {
    _lame.close(_gfp);
    if (_pcm != nullptr) calloc.free(_pcm);
    if (_out != nullptr) calloc.free(_out);
    _pcm = _out = nullptr;
  }

  void _ensureOut(int length) {
    if (length <= _outLength) return;
    if (_out != nullptr) calloc.free(_out);
    _out = calloc<Uint8>(_outLength = length);
  }
}

typedef _SetInt = int Function(Pointer<Void>, int);
typedef _SetIntC = Int Function(Pointer<Void>, Int);

class _Lame {
  _Lame(DynamicLibrary l)
    : init = l
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'lame_init',
          ),
      setInSampleRate = l.lookupFunction<_SetIntC, _SetInt>(
        'lame_set_in_samplerate',
      ),
      setOutSampleRate = l.lookupFunction<_SetIntC, _SetInt>(
        'lame_set_out_samplerate',
      ),
      setNumChannels = l.lookupFunction<_SetIntC, _SetInt>(
        'lame_set_num_channels',
      ),
      setMode = l.lookupFunction<_SetIntC, _SetInt>('lame_set_mode'),
      setVbr = l.lookupFunction<_SetIntC, _SetInt>('lame_set_VBR'),
      setBitRate = l.lookupFunction<_SetIntC, _SetInt>('lame_set_brate'),
      setWriteVbrTag = l.lookupFunction<_SetIntC, _SetInt>(
        'lame_set_bWriteVbrTag',
      ),
      setQuality = l.lookupFunction<_SetIntC, _SetInt>('lame_set_quality'),
      initParams = l
          .lookupFunction<
            Int Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('lame_init_params'),
      encodeFloat = l
          .lookupFunction<
            Int Function(
              Pointer<Void>,
              Pointer<Float>,
              Pointer<Float>,
              Int,
              Pointer<Uint8>,
              Int,
            ),
            int Function(
              Pointer<Void>,
              Pointer<Float>,
              Pointer<Float>,
              int,
              Pointer<Uint8>,
              int,
            )
          >('lame_encode_buffer_ieee_float'),
      flush = l
          .lookupFunction<
            Int Function(Pointer<Void>, Pointer<Uint8>, Int),
            int Function(Pointer<Void>, Pointer<Uint8>, int)
          >('lame_encode_flush'),
      lametag = l
          .lookupFunction<
            Size Function(Pointer<Void>, Pointer<Uint8>, Size),
            int Function(Pointer<Void>, Pointer<Uint8>, int)
          >('lame_get_lametag_frame'),
      close = l
          .lookupFunction<
            Int Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('lame_close');

  final Pointer<Void> Function() init;
  final _SetInt setInSampleRate;
  final _SetInt setOutSampleRate;
  final _SetInt setNumChannels;
  final _SetInt setMode;
  final _SetInt setVbr;
  final _SetInt setBitRate;
  final _SetInt setWriteVbrTag;
  final _SetInt setQuality;
  final int Function(Pointer<Void>) initParams;
  final int Function(
    Pointer<Void>,
    Pointer<Float>,
    Pointer<Float>,
    int,
    Pointer<Uint8>,
    int,
  )
  encodeFloat;
  final int Function(Pointer<Void>, Pointer<Uint8>, int) flush;
  final int Function(Pointer<Void>, Pointer<Uint8>, int) lametag;
  final int Function(Pointer<Void>) close;
}
