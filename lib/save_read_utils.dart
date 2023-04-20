import 'dart:io';
import 'dart:typed_data';

import 'package:krccsnet/krccsnet_encoder.dart';

const int IMAGE_HEIGHT = 256;
const int IMAGE_WIDTH = 256;

class SaveReadUtils {
  static Future<void> saveOutputTensor(
      String saveFullDirectory, List<dynamic> outputTensor) async {
    // save output , shape 1, 2, 128, 128
    File(saveFullDirectory).createSync();

    for (int j = 0; j < 2; ++j) {
      for (int i = 0; i < IMAGE_HEIGHT ~/ 2; ++i) {
        // File("${saveDirectory!}/${_getFileName.text}.krc")
        //     .writeAsStringSync(output0[i].join('\n'), mode: FileMode.append);
        await File(saveFullDirectory).writeAsBytes(
            Float32List.fromList(outputTensor[0][j][i] as List<double>)
                .buffer
                .asUint8List(),
            mode: FileMode.append);
      }
    }
  }

  static Future<List<dynamic>> readTensor(String readFullDirectory) async {
    var input = KrccsnetEncoder.getDecodeInputTensor();
    Uint8List rawBytes =
        await File(readFullDirectory).readAsBytes(); // 2 * 128 * 128
    for (int i = 0; i < 2; ++i) {
      var reader = rawBytes.buffer.asFloat32List(
          i * IMAGE_HEIGHT * IMAGE_WIDTH, IMAGE_HEIGHT * IMAGE_WIDTH ~/ 4);
      for (int ch = 0; ch < IMAGE_HEIGHT ~/ 2; ++ch) {
        for (int cw = 0; cw < IMAGE_WIDTH ~/ 2; ++cw) {
          input[0][i][ch][cw] = reader[ch * IMAGE_HEIGHT ~/ 2 + cw];
        }
      }
    }
    return input;
  }
}
