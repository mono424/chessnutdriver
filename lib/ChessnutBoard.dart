import 'dart:async';
import 'dart:typed_data';

import 'package:chessnutdriver/ChessnutCommunicationClient.dart';
import 'package:chessnutdriver/ChessnutCommunicationType.dart';
import 'package:chessnutdriver/ChessnutMessage.dart';
import 'package:chessnutdriver/ChessnutProtocol.dart';
import 'package:chessnutdriver/LEDPattern.dart';

class ChessnutBoard {
  
  ChessnutCommunicationClient _client;
  StreamController _inputStreamController;
  StreamController _boardUpdateStreamController;
  Stream<ChessnutMessage> _inputStream;
  Stream<Map<String, String>> _boardUpdateStream;
  List<int> _buffer;

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
    _inputStream = _inputStreamController.stream.asBroadcastStream();
    _boardUpdateStream = _boardUpdateStreamController.stream.asBroadcastStream();

    getInputStream().map(createBoardMap).listen(_newBoardState);
  }

  void _newBoardState(Map<String, String> state) {
    _boardUpdateStreamController.add(_currBoard);
  }

  bool _isWorking = false;
  void _handleInputStream(Uint8List rawChunk) {
    List<int> chunk = rawChunk.toList();

    if (_buffer == null)
      _buffer = chunk.toList();
    else
      _buffer.addAll(chunk);

    if (_isWorking == true) return;
    while(_buffer.length > 0) {
      _isWorking = true;
      try {
        _buffer = skipToNextStart(0, _buffer);
        ChessnutMessage message = ChessnutMessage.parse(_buffer);
        _inputStreamController.add(message);
        _buffer.removeRange(0, message.length);
      } on ChessnutInvalidMessageException catch (e) {
        _buffer = skipToNextStart(0, _buffer);
        _inputStreamController.addError(e);
      } on ChessnutMessageTooShortException catch (_) {
        break;
      } catch (err) {
        _inputStreamController.addError(err);
      }
    }
    _isWorking = false;
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

  Stream<ChessnutMessage> getInputStream() {
    return _inputStream;
  }

  Stream<Map<String, String>> getBoardUpdateStream() {
    return _boardUpdateStream;
  }

  Map<String, String> createBoardMap(ChessnutMessage message) {
    Map<String, String> map = {};
    for (var i = 0; i < message.pieces.length; i++) {
      map[ChessnutProtocol.squares[i]] = ChessnutProtocol.pieces[message.pieces[i]];
    }
    return map;
  }

  Future<void> setLEDs(LEDPattern pattern) async {
    await _send(Uint8List.fromList(pattern.pattern));
  }

  Future<void> _send(Uint8List message) async {
    await _client.send(message);
  }
  
}
