import 'package:flutter/material.dart';
import 'package:krccsnet/save_read_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class SaveFilePage extends StatefulWidget {
  const SaveFilePage({super.key, required this.outputTensor});
  final List<dynamic> outputTensor;
  @override
  State<SaveFilePage> createState() => _SaveFilePageState();
}

class _SaveFilePageState extends State<SaveFilePage> {
  final TextEditingController _getFileName = TextEditingController();
  late final List<dynamic> outputTensor;
  String? saveDirectory;
  @override
  void initState() {
    super.initState();
    outputTensor = widget.outputTensor;
    loadDefaultDirectory();
  }

  void loadDefaultDirectory() async {
    setState(() {
      saveDirectory = '/storage/emulated/0/Download/Krccsnet';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("存储字节流"),
      scrollable: true,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("存储路径"),
                  TextButton(
                    child: Text(
                        saveDirectory == null ? 'Loading' : saveDirectory!),
                    onPressed: () async {
                      if (await Permission.storage.request().isGranted) {
                        String? selectedDirectory =
                            await FilePicker.platform.getDirectoryPath();
                        if (selectedDirectory != null) {
                          setState(() {
                            saveDirectory = selectedDirectory;
                          });
                        }
                      }
                    },
                  ),
                ],
              )),
          Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _getFileName,
                maxLines: 1,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        borderSide: BorderSide(color: Colors.blue)),
                    labelText: '文件名',
                    hintText: '例如 test',
                    icon: Icon(Icons.numbers)),
              )),
        ],
      ),
      actions: [
        ElevatedButton(
            onPressed: () {
              SaveReadUtils.saveOutputTensor(
                  "$saveDirectory/${_getFileName.text}.krc", outputTensor);
              Navigator.pop(context);
            },
            child: const Text("确定"))
      ],
    );
  }
}
