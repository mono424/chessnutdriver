import 'dart:async';
import 'dart:typed_data';

import 'package:chessnutdriver/ChessnutBoard.dart';
import 'package:chessnutdriver/ChessnutCommunicationClient.dart';
import 'package:chessnutdriver/ChessnutCommunicationType.dart';
import 'package:chessnutdriver/LEDPattern.dart';
import 'package:example/ble_scanner.dart';
import 'package:example/device_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:usb_serial/usb_serial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final _ble = FlutterReactiveBle();
  final _scanner = BleScanner(ble: _ble, logMessage: print);
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: _scanner),
        StreamProvider<BleScannerState>(
          create: (_) => _scanner.state,
          initialData: const BleScannerState(
            discoveredDevices: [],
            scanIsInProgress: false,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter example',
        home: MyApp(),
      ),
    ),
  );
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
  final flutterReactiveBle = FlutterReactiveBle();

  final bleReadCharacteristic = Uuid.parse("1B7E8262-2877-41C3-B46E-CF057C562023");
  final bleWriteCharacteristic = Uuid.parse("1B7E8272-2877-41C3-B46E-CF057C562023");

  ChessnutBoard connectedBoard;
  Stream<ConnectionStateUpdate> boardBtStream;
  StreamSubscription<List<int>> boardBtInputStream;
  bool loading = false;

  void connectBle() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    String deviceId = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => DeviceListScreen()));

    setState(() {
      loading = true;
    });
    flutterReactiveBle.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 5),
    ).listen((e) async {
      if (e.connectionState == DeviceConnectionState.connected) {

        List<DiscoveredService> services = await flutterReactiveBle.discoverServices(e.deviceId);


        QualifiedCharacteristic read;
        QualifiedCharacteristic write;
        for (var service in services) {
          for (var characteristicId in service.characteristicIds) {
            if (characteristicId == bleReadCharacteristic) {
              read = QualifiedCharacteristic(
                serviceId: service.serviceId,
                characteristicId: bleReadCharacteristic,
                deviceId: e.deviceId
              );
            }

            if (characteristicId == bleWriteCharacteristic) {
              write = QualifiedCharacteristic(
                serviceId: service.serviceId,
                characteristicId: bleWriteCharacteristic,
                deviceId: e.deviceId
              );
            }
          }
        }

        ChessnutCommunicationClient chessnutCommuniChessnutCommunicationClient = ChessnutCommunicationClient(ChessnutCommunicationType.bluetooth, (v) => flutterReactiveBle.writeCharacteristicWithResponse(write, value: v));
        boardBtInputStream = flutterReactiveBle
            .subscribeToCharacteristic(read)
            .listen((list) {
              print(list);
              chessnutCommuniChessnutCommunicationClient.handleReceive(Uint8List.fromList(list));
            });
          

        // connect to board and initialize
        ChessnutBoard nBoard = new ChessnutBoard();
        await nBoard.init(chessnutCommuniChessnutCommunicationClient);
        print("chessnutBoard connected");

        // set connected board
        setState(() {
          connectedBoard = nBoard;
          loading = false;
        });
      }
    });
  }

  void connect() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    print(devices);
    if (devices.length == 0) {
      return;
    }

    List<UsbDevice> chessnutDevices = devices.where((d) => d.vid == 0x2D80).toList();
    UsbPort usbDevice = await chessnutDevices[0].create();
    await usbDevice.open();

    await usbDevice.setDTR(true);
	  await usbDevice.setRTS(true);

	  usbDevice.setPortParameters(38400, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    ChessnutCommunicationClient client = ChessnutCommunicationClient(ChessnutCommunicationType.usb, usbDevice.write);
    usbDevice.inputStream.listen(client.handleReceive);
    
    if (chessnutDevices.length > 0) {
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
            child: Text(connectedBoard == null ? "Try to connect to board (USB)" : "Connected"),
            onPressed: !loading && connectedBoard == null ? connect : null,
          )),
          Center(child: TextButton(
            child: Text(connectedBoard == null ? "Try to connect to board (BLE)" : "Connected"),
            onPressed: !loading && connectedBoard == null ? connectBle : null,
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
                                Text(entry.value ?? ".", style: TextStyle(color: Colors.white, fontSize: 8)),
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
