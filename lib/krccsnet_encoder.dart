import 'dart:typed_data';
import 'dart:isolate';
import 'dart:io';
import 'package:image/image.dart' as image_utils;
import 'package:tflite_flutter/tflite_flutter.dart';

const int IMAGE_HEIGHT = 256;
const int IMAGE_WIDTH = 256;

class KrccsnetEncoder {
  static Future<int> _encode(Interpreter encoderInterpreter,
      List<dynamic> input, List<dynamic> output, int times) async {
    if (times <= 0) {
      throw Exception("times can't be $times, must > 0");
    }
    var start = DateTime.now().millisecondsSinceEpoch;
    for (int roll = 0; roll < times; ++roll) {
      encoderInterpreter.run(input, output);
    }
    var end = DateTime.now().millisecondsSinceEpoch;
    int krccsnetTime = (end - start) ~/ times;
    return krccsnetTime;
  }

  // static Future<int> _decode(Interpreter decoderInterpreter,
  //     List<dynamic> input, List<dynamic> output, int times) async {
  static Future<int> _decode(Interpreter decoderInterpreter,
      List<dynamic> input, Map<int, Object> output, int times) async {
    if (times <= 0) {
      throw Exception("times can't be $times, must > 0");
    }
    var start = DateTime.now().millisecondsSinceEpoch;
    for (int roll = 0; roll < times; ++roll) {
      decoderInterpreter.runForMultipleInputs([input], output);
    }
    var end = DateTime.now().millisecondsSinceEpoch;
    int krccsnetTime = (end - start) ~/ times;
    return krccsnetTime;
  }

  static Future<int> _encodeJpeg(ByteBuffer input, int times) async {
    // prepare jpeg

    image_utils.JpegEncoder jpegEncoder = image_utils.JpegEncoder(quality: 100);
    image_utils.Image jpegEncoderTestImage = image_utils.Image.fromBytes(
        width: IMAGE_WIDTH, height: IMAGE_HEIGHT, bytes: input);

    var start = DateTime.now().millisecondsSinceEpoch;
    for (int roll = 0; roll < times; ++roll) {
      jpegEncoder.encode(jpegEncoderTestImage);
    }
    var end = DateTime.now().millisecondsSinceEpoch;

    int jpegTime = (end - start) ~/ times;
    return jpegTime;
  }

  static List<dynamic> getEncodeInputTensor(image_utils.Image rawImage) {
    // var converted = rawImage.
    // convert 2 y cb cr
    // rawImage.convert(format: image_utils.FormatType)
    // 提取y通道
    // fp32 / int8
    //
    var input = List<double>.filled(IMAGE_HEIGHT * IMAGE_WIDTH, 0.0)
        .reshape([1, 1, IMAGE_HEIGHT, IMAGE_WIDTH]);
    // fill with lumianceNormalized, shape: n c h w
    for (int ch = 0; ch < IMAGE_HEIGHT; ++ch) {
      for (int cw = 0; cw < IMAGE_WIDTH; ++cw) {
        input[0][0][ch][cw] = rawImage.getPixel(cw, ch).luminanceNormalized;
      }
    }
    return input;
  }

  static List<dynamic> getEncodeOutputTensor() {
    // fill output , shape 1, 2, 128, 128
    var output = List<double>.filled(IMAGE_HEIGHT * IMAGE_WIDTH ~/ 2, 0.0)
        .reshape([1, 2, IMAGE_HEIGHT ~/ 2, IMAGE_WIDTH ~/ 2]);
    return output;
  }

  static List<dynamic> getDecodeInputTensor() {
    var input = List<double>.filled(IMAGE_HEIGHT * IMAGE_WIDTH ~/ 2, 0.0)
        .reshape([1, 2, IMAGE_HEIGHT ~/ 2, IMAGE_WIDTH ~/ 2]);
    return input;
  }

  static List<dynamic> getDecodeOutputTensor() {
    var output = List<double>.filled(IMAGE_HEIGHT * IMAGE_WIDTH, 0.0)
        .reshape([1, 1, IMAGE_HEIGHT, IMAGE_WIDTH]);
    return output;
  }

  static void encode(List<Object> options) async {
    SendPort sendPort = options[0] as SendPort;
    Interpreter encoderInterpreter = Interpreter.fromAddress(options[2] as int);
    File(options[1] as String).readAsBytes().then((imageBytes) async {
      image_utils.Decoder? rawImageDecoder =
          image_utils.findDecoderForData(imageBytes);

      if (rawImageDecoder == null) {
        throw Exception("Format not supported.");
      }

      var rawImage = rawImageDecoder.decode(imageBytes)!;
      var input = getEncodeInputTensor(rawImage);
      var output = getEncodeOutputTensor();

      int krccsnetTime = await _encode(encoderInterpreter, input, output, 1);
      sendPort.send([krccsnetTime, output]);
    });
  }

  static void decode(List<Object> options) async {
    SendPort sendPort = options[0] as SendPort;
    List<dynamic> input = options[1] as List<dynamic>;
    Interpreter decoderInterpreter = Interpreter.fromAddress(options[2] as int);
    // var output = getDecodeOutputTensor();
    // await _decode(decoderInterpreter, input, output, 1);
    // List<dynamic> ->

    var output = <int, Object>{};
    output[0] = getDecodeOutputTensor();
    output[1] = getDecodeOutputTensor();
    await _decode(decoderInterpreter, input, output, 1);

    var rawImage = image_utils.Image(width: 256, height: 256);
    for (int ch = 0; ch < IMAGE_HEIGHT; ++ch) {
      for (int cw = 0; cw < IMAGE_WIDTH; ++cw) {
        double c = (output[1]! as List<dynamic>)[0][0][ch][cw] * 256.0;
        rawImage.setPixelRgb(cw, ch, c, c, c);
      }
    }

    sendPort.send(rawImage.buffer);

    /// 1. read file(byte stream)
    /// 2. recover to Tensor
    /// 3. run
  }

  static void benchmark(List<Object> options) async {
    SendPort sendPort = options[0] as SendPort;
    Interpreter encoderInterpreter = Interpreter.fromAddress(options[2] as int);
    File(options[1] as String).readAsBytes().then((imageBytes) async {
      image_utils.Decoder? rawImageDecoder =
          image_utils.findDecoderForData(imageBytes);

      if (rawImageDecoder == null) {
        throw Exception("Format not supported.");
      }

      var rawImage = rawImageDecoder.decode(imageBytes)!;

      var input = getEncodeInputTensor(rawImage);
      var output = getEncodeOutputTensor();

      var runPass = 10;
      var krccsnetTime =
          await _encode(encoderInterpreter, input, output, runPass);
      var jpegTime = await _encodeJpeg(
          image_utils
              .copyCrop(rawImage,
                  x: 0, y: 0, width: IMAGE_WIDTH, height: IMAGE_HEIGHT)
              .buffer,
          runPass);
      sendPort.send([krccsnetTime, jpegTime]);
      // piece of shit
    });
  }
}

// class KrccsnetRet {
//   final int time;
//   final
//   const KrccsnetRet({required this.time});
// }
