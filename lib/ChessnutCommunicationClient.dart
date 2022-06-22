import 'dart:async';
import 'dart:typed_data';

import 'package:chessnutdriver/ChessnutCommunicationType.dart';

class ChessnutCommunicationClient {
  final ChessnutCommunicationType type;
  final Future<void> Function(Uint8List) send;
  final StreamController<Uint8List> _inputStreamController = StreamController<Uint8List>();

  Stream<Uint8List> get receiveStream {
    return _inputStreamController.stream.asBroadcastStream();
  }

  ChessnutCommunicationClient(this.type, this.send);

  handleReceive(Uint8List message) {
    _inputStreamController.add(message);
  }
}