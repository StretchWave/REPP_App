import 'dart:async';
import 'package:flutter/services.dart';

class PoseBridge {
  static final PoseBridge _instance = PoseBridge._internal();
  factory PoseBridge() => _instance;
  PoseBridge._internal();

  static const EventChannel _channel = EventChannel('com.workout/pose_stream');
  Stream<List<Map<String, double>>>? _cachedStream;

  Stream<List<Map<String, double>>> get poseStream {
    _cachedStream ??= _channel.receiveBroadcastStream().map((event) {
      try {
        final List<dynamic> flatList = event;
        final int pointCount = flatList.length ~/ 4;
        final List<Map<String, double>> mapped = [];

        for (int i = 0; i < pointCount; i++) {
          final int offset = i * 4;
          mapped.add({
            'x': (flatList[offset] as num).toDouble(),
            'y': (flatList[offset + 1] as num).toDouble(),
            'z': (flatList[offset + 2] as num).toDouble(),
            'visibility': (flatList[offset + 3] as num).toDouble(),
          });
        }

        return mapped;
      } catch (e) {
        return <Map<String, double>>[];
      }
    }).asBroadcastStream();
    return _cachedStream!;
  }
}

