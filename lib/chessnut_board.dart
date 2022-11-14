import 'dart:async';
import 'dart:typed_data';

import 'package:chessnutdriver/chessnut_communication_client.dart';
import 'package:chessnutdriver/chessnut_communication_type.dart';
import 'package:chessnutdriver/chessnut_message.dart';
import 'package:chessnutdriver/chessnut_protocol.dart';
import 'package:chessnutdriver/led_pattern.dart';
import 'package:synchronized/synchronized.dart';

class ChessnutBoard {
  
  late ChessnutCommunicationClient _client;
  late StreamController _inputStreamController;
  late StreamController _boardUpdateStreamController;
  Stream<ChessnutMessage>? _inputStream;
  Stream<Map<String, String>>? _boardUpdateStream;
  List<int>? _buffer;

  Map<String, String> _currBoard = Map.fromEntries(ChessnutProtocol.squares.map((e) => MapEntry(e, ChessnutProtocol.pieces[0])));

  Map<String, String> get currBoard {
    return _currBoard;
  }

  ChessnutBoard();

  Future<void> init(ChessnutCommunicationClient client) async {
    _client = client;
    _client.receiveStream.listen(_handleInputStream);
    _inputStreamController = StreamController<ChessnutMessage>();
    _boardUpdateStreamController = StreamController<Map<String, String>>();
    _inputStream = _inputStreamController.stream.asBroadcastStream() as Stream<ChessnutMessage>?;
    _boardUpdateStream = _boardUpdateStreamController.stream.asBroadcastStream() as Stream<Map<String, String>>?;

    getInputStream()!.map(_createBoardMap).listen(_newBoardState);

    Future<void> ack = getAckFuture();
    _send(Uint8List.fromList([0x21, 0x01, 0x00]));
    await ack;
  }

  void _newBoardState(Map<String, String> state) {
    _currBoard = state;
    _boardUpdateStreamController.add(_currBoard);
  }

  var lock = new Lock();
  void _handleInputStream(Uint8List rawChunk) async {
    await lock.synchronized(() async {
      List<int> chunk = rawChunk.toList();

      if (_buffer == null)
        _buffer = chunk.toList();
      else
        _buffer!.addAll(chunk);

      while(_buffer!.length > 0) {
        try {
          _buffer = skipToNextStart(0, _buffer!);
          ChessnutMessage message = ChessnutMessage.parse(_buffer!);
          _inputStreamController.add(message);
          _buffer!.removeRange(0, message.length);
        } on ChessnutInvalidMessageException catch (e) {
          _buffer = skipToNextStart(0, _buffer!);
          _inputStreamController.addError(e);
        } on ChessnutMessageTooShortException catch (_) {
          break;
        } catch (err) {
          _inputStreamController.addError(err);
        }
      }
    });
  }

  List<int> skipToNextStart(int start, List<int> buffer) {
    int index = start;
    for (; index < (buffer.length - 1); index++) {
      if (_isMessageStart(buffer, index)) break;
    }
    if (index == (buffer.length - 1)) return [];
    return buffer.sublist(index, buffer.length - index);
  }

  bool _isMessageStart(List<int> buffer, int index) {
    if (_client.type == ChessnutCommunicationType.usb) {
      return (buffer[index] == 0x01 && buffer[index + 1] == 0x3D);
    } else if (_client.type == ChessnutCommunicationType.bluetooth) {
      return (buffer[index] == 0x01 && buffer[index + 1] == 0x24);
    }
    throw Exception("Invalid communication type");
  }

  Stream<ChessnutMessage>? getInputStream() {
    return _inputStream;
  }

  Stream<Map<String, String>>? getBoardUpdateStream() {
    return _boardUpdateStream;
  }

  Map<String, String> _createBoardMap(ChessnutMessage message) {
    Map<String, String> map = {};
    for (var i = 0; i < message.pieces.length; i++) {
      map[ChessnutProtocol.squares[i]] = ChessnutProtocol.pieces[message.pieces[i]];
    }
    return map;
  }

  Future<void> setLEDs(LEDPattern pattern) async {
    Future<void> ack = getAckFuture();
    await _send(Uint8List.fromList([0x0A, 0x08, ...pattern.pattern]));
    await ack;
  }

  Future<void> _send(Uint8List message) async {
    await _client.send(message);
  }

  Future<void> getAckFuture() {
    return _client.waitForAck ? _client.ackStream.firstWhere((e) => equals(e.toList(), [0x23, 0x01, 0x00])).timeout(_client.ackTimeout) : Future.value();
  }

  bool equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  
}
