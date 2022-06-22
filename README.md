# chessnutdriver

The chessnutdriver flutter package allows you to quickly get you chessnut-board connected
to your Android application.

## Getting Started with chessnutdriver + usb_serial

Add dependencies to `pubspec.yaml`
```
dependencies:
	chessnutdriver: ^0.0.4
	usb_serial: ^0.2.4
```

include the package
```
import 'package:chessnutdriver/chessnutdriver.dart';
import 'package:usb_serial/usb_serial.dart';
```

add compileOptions to `android\app\build.gradle`
```
android {
    ...
    compileOptions {
        sourceCompatibility 1.8
        targetCompatibility 1.8
    }
    ...
}
```
you can do optional more steps to allow usb related features,
for that please take a look at the package we depend on: 
[usb_serial](https://pub.dev/packages/usb_serial).


Connect to a connected board and listen to its events:
```dart
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

    chessnutCommunicationClient client = chessnutCommunicationClient(usbDevice.write);
    usbDevice.inputStream.listen(client.handleReceive);
    
    if (dgtDevices.length > 0) {
      // connect to board and initialize
      chessnutBoard nBoard = new chessnutBoard();
      await nBoard.init(client);
      print("chessnutBoard connected");

      // set connected board
      setState(() {
        connectedBoard = nBoard;
      });
    }
```

## In action

To get a quick look, it is used in the follwoing project, which is not open source yet.

https://khad.im/p/white-pawn

