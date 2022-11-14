import 'package:chessnutdriver/chessnut_protocol.dart';

class LEDPattern {

  List<bool> _pattern = List.filled(64, false);

  LEDPattern([List<bool>? pattern]) {
    if(pattern != null) _pattern = pattern;
  }

  List<int> get pattern {
    List<int> bytePattern = [];
    for (var i = 0; i < 8; i++) {
      bytePattern.add(0);
      for (var j = 0; j < 8; j++) {
        if (_pattern[i * 8 + j]) bytePattern[i] += (1 << j);
      }
    }
    return bytePattern;
  }

  void setSquare(String square, bool state) {
    int sqIndex = ChessnutProtocol.squares.indexOf(square.toLowerCase());
    if (sqIndex == -1) throw Exception("Square not found.");
    _pattern[sqIndex] = state;
  }

  bool getSquare(String square) {
    int sqIndex = ChessnutProtocol.squares.indexOf(square.toLowerCase());
    if (sqIndex == -1) throw Exception("Square not found.");
    return _pattern[sqIndex];
  }
  
}