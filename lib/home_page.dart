import 'dart:io';
// import 'dart:ui' as ui show Image;
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krccsnet/krccsnet_encoder.dart';
import 'package:krccsnet/save_file_page.dart';
import 'package:krccsnet/save_read_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as image_utils;

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Image? selectedImage;
  String benchmarkText = "Ready";
  late Interpreter encoderInterpreter;
  late Interpreter decoderInterpreter;
  late List<dynamic> outputTensor;
  bool byteStreamReady = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    loadModel();
    super.initState();
    // selectedImage = Image.asset('assets/rena.png');
  }

  void saveByteStream() async {
    if (byteStreamReady) {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return SaveFilePage(
              outputTensor: outputTensor,
            );
          });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("字节流未生成"),
          showCloseIcon: true,
          closeIconColor: Colors.lightBlue));
    }
  }

  void readByteStream() async {
    if (await Permission.storage.request().isGranted) {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null) {
        var input = await SaveReadUtils.readTensor(result.files.first.path!);
        ReceivePort receivePort = ReceivePort();
        await Isolate.spawn(KrccsnetEncoder.decode,
            [receivePort.sendPort, input, decoderInterpreter.address]);

        setState(() {
          benchmarkText = "decoding";
        });
        receivePort.listen((message) {
          // message: Uint8List
          var rawImage = image_utils.Image.fromBytes(
              width: 256, height: 256, bytes: message);

          setState(() {
            selectedImage = Image.memory(image_utils.encodePng(rawImage));
            benchmarkText = "Done!";
          });
        });
      }
    }
  }

  void loadModel() async {
    // final gpuDelegateV2 = GpuDelegateV2(
    //     options: GpuDelegateOptionsV2(
    //         inferencePriority1: TfLiteGpuInferencePriority.minLatency,
    //         inferencePriority2: TfLiteGpuInferencePriority.auto,
    //         inferencePriority3: TfLiteGpuInferencePriority.auto));
    var interpreteroptions = InterpreterOptions();
    // interpreteroptions.addDelegate(gpuDelegateV2);
    interpreteroptions.useNnApiForAndroid = true;
    encoderInterpreter = await Interpreter.fromAsset('tflite_0.5encoder.tflite',
        options: interpreteroptions);

    decoderInterpreter = await Interpreter.fromAsset('tflite_0.5decoder.tflite',
        options: interpreteroptions);
    // encoderInterpreter =
    //     await Interpreter.fromAsset('tflite_0.5encoder.tflite');

    // decoderInterpreter =
    //     await Interpreter.fromAsset('tflite_0.5decoder.tflite');
  }

  void openGallery() async {
    XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      // throw Exception("File not found.");
    } else {
      setState(() {
        selectedImage = Image.file(File(pickedFile.path));
        byteStreamReady = false;
      });

      ReceivePort receivePort = ReceivePort();
      // var options = receivePort.sendPort;
      await Isolate.spawn(KrccsnetEncoder.encode, [
        receivePort.sendPort,
        pickedFile.path,
        encoderInterpreter.address,
      ]);
      setState(() {
        benchmarkText = "encoding";
      });
      // await for (var times in receivePort) {
      //   int krccsnetTime = times[0];
      //   int jpegTime = times[1];
      //   setState(() {
      //     benchmarkText = "Done!\nkrccsnet: $krccsnetTime\njpeg:$jpegTime";
      //   });
      // }
      // receivePort.listen((times) {
      //   int krccsnetTime = times[0];
      //   int jpegTime = times[1];
      //   setState(() {
      //     benchmarkText = "Done!\nkrccsnet: $krccsnetTime\njpeg:$jpegTime";
      //     byteStreamReady = true;
      //   });
      // });
      receivePort.listen((message) {
        setState(() {
          benchmarkText = "Done!\nelapsed time: ${message[0] as int} ms";
          outputTensor = message[1] as List<dynamic>;
          byteStreamReady = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("krccsnet"),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 10.0, left: 10.0),
            child: Text(
              "图片预览：",
              style: TextStyle(fontSize: 20, color: Colors.black45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              child: selectedImage,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10.0, left: 10.0),
            child: Text(
              "选项：",
              style: TextStyle(fontSize: 20, color: Colors.black45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: OutlinedButton(
                      onPressed: openGallery,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                        child: Column(
                          children: const [
                            Icon(Icons.photo_album_outlined),
                            Text("选择照片")
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                    child: OutlinedButton(
                      onPressed: saveByteStream,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                        child: Column(children: const [
                          Icon(Icons.save_outlined),
                          Text("保存字节流")
                        ]),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: OutlinedButton(
                      onPressed: readByteStream,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                        child: Column(children: const [
                          Icon(Icons.stream_outlined),
                          Text("读取字节流")
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              benchmarkText,
            ),
          )
        ],
      ),
    );
  }
}
