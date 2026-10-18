import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One block of a `text/event-stream`: the fields between two blank lines.
///
/// Read as the HTML standard's event-stream parser reads them, with one
/// difference that matters to the live room's client: a block carrying only
/// `retry:` (the first thing on every stream) or only `id:` is handed over
/// too, where a browser would apply it silently. The caller decides what each
/// field means.
@immutable
class SseFrame {
  const SseFrame({
    this.event = 'message',
    this.data = '',
    this.id,
    this.retry,
  });

  /// The `event:` field; `message` when the block names none, as a browser
  /// would dispatch it.
  final String event;

  /// The `data:` lines joined with `\n`; empty when there were none.
  final String data;

  /// This block's own `id:` field: null when it has none (the last id
  /// stands), empty when it resets the last id.
  final String? id;

  /// The `retry:` field in milliseconds, when it was a whole number.
  final int? retry;

  @override
  bool operator ==(Object other) =>
      other is SseFrame &&
      other.event == event &&
      other.data == data &&
      other.id == id &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(event, data, id, retry);

  @override
  String toString() => 'SseFrame(event: $event, id: $id, retry: $retry, '
      'data: ${data.length > 80 ? '${data.substring(0, 80)}…' : data})';
}

/// Turns the bytes of a `text/event-stream` into [SseFrame]s.
///
/// UTF-8 (a character split across two chunks is put back together), lines
/// ended by CRLF, LF or a lone CR (also when split across chunks), a leading
/// byte-order mark dropped, `:` comments skipped, one space after a field's
/// colon dropped, unknown fields ignored, an `id:` containing NUL ignored and
/// a `retry:` that is not all digits ignored. A block the stream ends in the
/// middle of is dropped, as the standard says: it may be half a snapshot.
class SseDecoder extends StreamTransformerBase<List<int>, SseFrame> {
  const SseDecoder();

  @override
  Stream<SseFrame> bind(Stream<List<int>> stream) {
    final lines = stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    return Stream<SseFrame>.eventTransformed(lines, _SseSink.new);
  }
}

class _SseSink implements EventSink<String> {
  _SseSink(this._out);

  final EventSink<SseFrame> _out;

  bool _first = true;
  bool _any = false;
  String? _event;
  final StringBuffer _data = StringBuffer();
  bool _hasData = false;
  String? _id;
  int? _retry;

  static final _digits = RegExp(r'^[0-9]+$');

  @override
  void add(String line) {
    if (_first) {
      _first = false;
      if (line.startsWith('﻿')) line = line.substring(1);
    }
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) return;

    final colon = line.indexOf(':');
    final String field;
    var value = '';
    if (colon < 0) {
      field = line;
    } else {
      field = line.substring(0, colon);
      value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
    }

    switch (field) {
      case 'event':
        _event = value;
        _any = true;
      case 'data':
        if (_hasData) _data.write('\n');
        _data.write(value);
        _hasData = true;
        _any = true;
      case 'id':
        if (!value.contains('\u0000')) {
          _id = value;
          _any = true;
        }
      case 'retry':
        if (_digits.hasMatch(value)) {
          _retry = int.tryParse(value);
          _any = _any || _retry != null;
        }
      default:
        // Not a field this stream defines: ignored, as a browser does.
        break;
    }
  }

  void _dispatch() {
    if (_any) {
      _out.add(SseFrame(
        event: (_event == null || _event!.isEmpty) ? 'message' : _event!,
        data: _data.toString(),
        id: _id,
        retry: _retry,
      ));
    }
    _any = false;
    _event = null;
    _data.clear();
    _hasData = false;
    _id = null;
    _retry = null;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _out.addError(error, stackTrace);

  @override
  void close() {
    // A block without its blank line is unfinished: dropped.
    _out.close();
  }
}
