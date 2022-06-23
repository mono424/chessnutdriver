# chessnutdriver

The chessnutdriver flutter package allows you to quickly get you chessnut-board connected
to your Android application.

![Screenshot](https://github.com/mono424/chessnutdriver/blob/demo/img/demo.png?raw=true)

## Getting Started with chessnutdriver

Add dependencies to `pubspec.yaml`
```
dependencies:
	chessnutdriver: ^0.0.1
```

include the package
```
import 'package:chessnutdriver/chessnutdriver.dart';
```


Connect to a connected board and listen to its events:
```dart
    ChessnutCommunicationClient chessnutCommuniChessnutCommunicationClient = ChessnutCommunicationClient(
      ChessnutCommunicationType.bluetooth,
      (v) => flutterReactiveBle.writeCharacteristicWithResponse(write, value: v),
      waitForAck: ackEnabled
    );
    boardBtInputStreamA = flutterReactiveBle
        .subscribeToCharacteristic(readA)
        .listen((list) {
          chessnutCommuniChessnutCommunicationClient.handleReceive(Uint8List.fromList(list));
        });
    boardBtInputStreamB = flutterReactiveBle
        .subscribeToCharacteristic(readB)
        .listen((list) {
          chessnutCommuniChessnutCommunicationClient.handleAckReceive(Uint8List.fromList(list));
        });
      

    // connect to board and initialize
    ChessnutBoard nBoard = new ChessnutBoard();
    await nBoard.init(chessnutCommuniChessnutCommunicationClient);
    print("chessnutBoard connected");
```

## In action

To get a quick look, it is used in the follwoing project, which is not open source yet.

https://khad.im/p/white-pawn

