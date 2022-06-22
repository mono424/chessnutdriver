import 'package:chessnutdriver/ChessnutBoard.dart';
import 'package:chessnutdriver/ChessnutCommunicationClient.dart';
import 'package:chessnutdriver/ChessnutCommunicationType.dart';
import 'package:chessnutdriver/LEDPattern.dart';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ChessnutBoard connectedBoard;

  void connect() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    print(devices);
    if (devices.length == 0) {
      return;
    }

    List<UsbDevice> dgtDevices = devices.where((d) => d.vid == 4292).toList();
    UsbPort usbDevice = await dgtDevices[0].create();
    await usbDevice.open();

    await usbDevice.setDTR(true);
	  await usbDevice.setRTS(true);

	  usbDevice.setPortParameters(38400, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    ChessnutCommunicationClient client = ChessnutCommunicationClient(ChessnutCommunicationType.usb, usbDevice.write);
    usbDevice.inputStream.listen(client.handleReceive);
    
    if (dgtDevices.length > 0) {
      // connect to board and initialize
      ChessnutBoard nBoard = new ChessnutBoard();
      await nBoard.init(client);
      print("chessnutBoard connected");

      // set connected board
      setState(() {
        connectedBoard = nBoard;
      });
    }
  }

  Map<String, String> lastData;

  LEDPattern ledpattern = LEDPattern();

  void toggleLed(String square) {
    ledpattern.setSquare(square, !ledpattern.getSquare(square));
    connectedBoard.setLEDs(ledpattern);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text("chessnutdriver example"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(child: TextButton(
            child: Text(connectedBoard == null ? "Try to connect to board" : "Connected"),
            onPressed: connectedBoard == null ? connect : null,
          )),
          Center( child: StreamBuilder(
            stream: connectedBoard?.getBoardUpdateStream(),
            builder: (context, AsyncSnapshot<Map<String, String>> snapshot) {
              if (!snapshot.hasData && lastData == null) return Text("- no data -");

              Map<String, String> fieldUpdate = snapshot.data ?? lastData;
              lastData = fieldUpdate;
              List<Widget> rows = [];
              
              for (var i = 0; i < 8; i++) {
                List<Widget> cells = [];
                for (var j = 0; j < 8; j++) {
                    MapEntry<String, String> entry = fieldUpdate.entries.toList()[i * 8 + j];
                    cells.add(
                      TextButton(
                        onPressed: () => toggleLed(entry.key),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(width / 8 - 4, width / 8 - 4),
                          alignment: Alignment.centerLeft
                        ),
                        child: Container(
                          padding: EdgeInsets.only(bottom: 2),
                          width: width / 8 - 4,
                          height: width / 8 - 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: ledpattern.getSquare(entry.key) ? Colors.blueAccent : Colors.black54,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(entry.key, style: TextStyle(color: Colors.white)),
                                Text(entry.value, style: TextStyle(color: Colors.white, fontSize: 8)),
                              ],
                            )
                          ),
                        ),
                      )
                    );
                }
                rows.add(Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: cells,
                ));
              }

              return Column(
                children: rows,
              );
            }
          )),
        ],
      ),
    );
  }
}
