import 'dart:async';
import 'dart:typed_data';

import 'package:chessnutdriver/ChessnutCommunicationClient.dart';
import 'package:chessnutdriver/ChessnutMessage.dart';
import 'package:chessnutdriver/ChessnutProtocol.dart';
import 'package:chessnutdriver/IntegrityCheckType.dart';
import 'package:chessnutdriver/LEDPattern.dart';

class ChessnutBoard {
  
  ChessnutCommunicationClient _client;
  StreamController _inputStreamController;
  StreamController _boardUpdateStreamController;
  Stream<ChessnutMessage> _inputStream;
  Stream<Map<String, List<int>>> _boardUpdateStream;
  List<int> _buffer;

  Map<String, List<int>> _currBoard = Map.fromEntries(ChessnutProtocol.squares.map((e) => MapEntry(e, ChessnutProtocol.emptyFieldId)));

  Map<String, List<int>> get currBoard {
    return _currBoard;
  }

  List<Map<String, List<int>>> _lastBoards = [];

  ChessnutBoard();

  Future<void> init(ChessnutCommunicationClient client) async {
    _client = client;
    _client.receiveStream.listen(_handleInputStream);
    _inputStreamController = new StreamController<ChessnutMessage>();
    _boardUpdateStreamController = new StreamController<Map<String, List<int>>>();
    _inputStream = _inputStreamController.stream.asBroadcastStream();
    _boardUpdateStream = _boardUpdateStreamController.stream.asBroadcastStream();

    getInputStream().map(createBoardMap).listen(_newBoardState);
  }

  void _newBoardState(Map<String, List<int>> state) {
    // PieceId Whitelist
    if (pieceIdWhitelist != null && pieceIdWhitelist.length > 0) {
      state = state.map((key, value) {
        if (pieceIdWhitelist.any((e) => ChessnutProtocol.equalId(e, value))) {
          return MapEntry(key, value);
        }
        return MapEntry(key, ChessnutProtocol.emptyFieldId);
      });
    }

    // Integrity Checks
    int messagesNeeded = 1 + _incoomingIntegrityChecks;
    _lastBoards.insert(0, state);
    if (_lastBoards.length < messagesNeeded) return;

    _lastBoards = _lastBoards.sublist(0, messagesNeeded);

    if (incoomingIntegrityCheckType == IntegrityCheckType.cell) {
      _currBoard = _currBoard.map((key, value) {
        List<int> potentialNewValue = _lastBoards.first[key];
        if (_lastBoards.every((e) => ChessnutProtocol.equalId(e[key], potentialNewValue))) {
          return MapEntry(key, potentialNewValue);
        }
        return MapEntry(key, value);
      });
    } else {
      if (checkStatesAreEqual(_lastBoards)) {
        _currBoard = _lastBoards.first;
      }
    }

    _boardUpdateStreamController.add(_currBoard);
  }

  bool checkStatesAreEqual(List<Map<String, List<int>>> states) {
    Map<String, List<int>> first = _lastBoards.first;
    for (var entry in first.entries) {
      if (!states.every((e) => ChessnutProtocol.equalId(e[entry.key], entry.value))) {
        return false;
      }
    }
    return true;
  }

  bool _isWorking = false;
  void _handleInputStream(Uint8List rawChunk) {
    List<int> chunk = rawChunk.toList();

    if (_buffer == null)
      _buffer = chunk.toList();
    else
      _buffer.addAll(chunk);

    if (_isWorking == true) return;
    while(_buffer.length >= 384) {
      _isWorking = true;
      try {
        _buffer = skipToNextStart(0, _buffer);
        ChessnutMessage message = ChessnutMessage.parse(_buffer);
        _inputStreamController.add(message);
        _buffer.removeRange(0, message.length);
        //print("Received valid message");
      } on ChessnutInvalidMessageException catch (e) {
        _buffer = skipToNextStart(0, _buffer);
        _inputStreamController.addError(e);
      } on ChessnutInvalidMessageLengthException catch (e) {
        _buffer = skipToNextStart(1, _buffer);
        _inputStreamController.addError(e);
      } on ChessnutMessageTooShortException catch (_) {
        //_inputStreamController.addError(e);
      } catch (err) {
        //print("Unknown parse-error: " + err.toString());
        _inputStreamController.addError(err);
      }
    }
    _isWorking = false;
  }

  List<int> skipToNextStart(int start, List<int> buffer) {
    int index = start;
    for (; index < buffer.length; index++) {
      if ((buffer[index] & 127) == 58) break;
    }
    if (index == buffer.length) return [];
    return buffer.sublist(index, buffer.length - index);
  }

  Stream<ChessnutMessage> getInputStream() {
    return _inputStream;
  }

  Stream<Map<String, List<int>>> getBoardUpdateStream() {
    return _boardUpdateStream;
  }

  Map<String, List<int>> createBoardMap(ChessnutMessage message) {
    Map<String, List<int>> map = Map<String, List<int>>();
    for (var i = 0; i < message.items.length; i++) {
      map[ChessnutProtocol.squares[i]] = message.items[i];
    }
    return map;
  }

  Future<void> setLEDs(LEDPattern pattern) async {
    await _send(Uint8List.fromList(pattern.pattern));
  }

  Future<void> _send(Uint8List message) async {
    await _client.send(message);
    for (var i = 0; i < _redundantOutputMessages; i++) {
      await Future.delayed(redudantOutputMessageDelay);
      await _client.send(message);
    }
  }
  
}
