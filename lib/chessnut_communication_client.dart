import 'dart:async';
import 'dart:typed_data';

import 'package:chessnutdriver/chessnut_communication_type.dart';

class ChessnutCommunicationClient {
  final ChessnutCommunicationType type;
  final bool waitForAck;
  final Duration ackTimeout;
  final Future<void> Function(Uint8List) send;
  final StreamController<Uint8List> _inputStreamController = StreamController<Uint8List>();
  final StreamController<Uint8List> _ackStreamController = StreamController<Uint8List>();
  Stream<Uint8List>? _receiveStream;
  Stream<Uint8List>? _ackStream;

  Stream<Uint8List> get receiveStream {
    if (_receiveStream == null) _receiveStream = _inputStreamController.stream.asBroadcastStream();
    return _receiveStream!;
  }

  Stream<Uint8List> get ackStream {
    if (_ackStream == null) _ackStream = _ackStreamController.stream.asBroadcastStream();
    return _ackStream!;
  }

  ChessnutCommunicationClient(this.type, this.send, { this.waitForAck = false, this.ackTimeout = const Duration(seconds: 1) });

  handleReceive(Uint8List message) {
    _inputStreamController.add(message);
  }

  handleAckReceive(Uint8List message) {
    _ackStreamController.add(message);
  }
}