class ChessnutMessage {

  List<int> _pieces = [];
  int _length = 0;

  ChessnutMessage.parse(List<int> message) {
    if (message.length < 65) throw ChessnutMessageTooShortException(message);

    _length = 65;

    for (var i = 2; i < 34; i++) {
      _pieces.add(message[i] & 15);
      _pieces.add(message[i] >> 4);
    }
  }

  List<int> get pieces {
    return _pieces;
  }

  int get length {
    return _length;
  }

}

abstract class ChessnutMessageException implements Exception {
  final List<int> buffer;
  ChessnutMessageException(this.buffer);
}

class ChessnutMessageTooShortException extends ChessnutMessageException {
  ChessnutMessageTooShortException(List<int> buffer) : super(buffer);
}

class ChessnutInvalidMessageLengthException extends ChessnutMessageException {
  ChessnutInvalidMessageLengthException(List<int> buffer) : super(buffer);
}

class ChessnutInvalidMessageException extends ChessnutMessageException {
  ChessnutInvalidMessageException(List<int> buffer) : super(buffer);
}