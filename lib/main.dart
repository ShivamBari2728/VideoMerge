import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isloading = false;
  List<String>? selectedVideos;
  String? outputFilePath;

  // Function to check device storage permission
  void checkDevice() async {
    final plugin = DeviceInfoPlugin();
    final android = await plugin.androidInfo;

    final storageStatus = android.version.sdkInt < 33
        ? await Permission.manageExternalStorage.request()
        : PermissionStatus.granted;

    if (storageStatus == PermissionStatus.granted) {
      print("Storage Permission granted");
    } else if (storageStatus == PermissionStatus.denied) {
      print("Storage Permission denied");
    } else if (storageStatus == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  void _videoMerger() async {
    setState(() {
      isloading = true;
    });

    Directory? downloadsDir = await getExternalStorageDirectory();
    var uuid = Uuid();
    String uniqueId = uuid.v4();
    String outputPath =
        path.join(downloadsDir!.path, 'merged_video_$uniqueId.mp4');

    final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

    String targetHeight = "720";
    String targetFramerate = "30";
    StringBuffer commandBuffer = StringBuffer();
    commandBuffer.write('-y ');
    for (int i = 0; i < selectedVideos!.length; i++) {
      commandBuffer.write('-i ${selectedVideos![i]} ');
    }
    commandBuffer.write('-filter_complex "');
    for (int i = 0; i < selectedVideos!.length; i++) {
      commandBuffer
          .write('[${i}:v]scale=-1:$targetHeight,fps=$targetFramerate[v$i];');
    }
    String videoInputs =
        selectedVideos!.asMap().entries.map((e) => '[v${e.key}]').join();
    commandBuffer.write(
        '$videoInputs concat=n=${selectedVideos!.length}:v=1:a=0[outv];');

    String audioInputs =
        selectedVideos!.asMap().entries.map((e) => '[${e.key}:a]').join();
    commandBuffer.write(
        '$audioInputs concat=n=${selectedVideos!.length}:a=1:v=0[outa]" ');

    commandBuffer.write('-map "[outv]" -map "[outa]" $outputPath');

    String commandToExecute = commandBuffer.toString();

    await _flutterFFmpeg.execute(commandToExecute).then((rc) {
      print("FFmpeg process exited with rc $rc");
      if (rc == 0) {
        print("video saved at ${outputPath}");
        setState(() {
          outputFilePath = outputPath;
        });
      } else {
        print("FFmpeg execution failed with return code $rc");
      }
    }).catchError((e) {
      print("Error during FFmpeg execution: $e");
    });

    setState(() {
      isloading = false;
    });
  }

  Future<void> pickVideos() async {
    try {
      checkDevice();
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.video,
      );

      if (result != null) {
        setState(() {
          selectedVideos = result.paths.whereType<String>().toList();
          print(selectedVideos);
        });
      } else {
        setState(() {
          selectedVideos = null;
        });
      }
    } catch (e) {
      print("Error picking videos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      title: 'Video Picker & Merger',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Pick & Merge Videos'),
          backgroundColor: const Color.fromARGB(255, 104, 102, 122),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: pickVideos,
                child: Text('Pick Videos'),
              ),
              isloading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed:
                          selectedVideos == null || selectedVideos!.isEmpty
                              ? null
                              : _videoMerger,
                      child: Text('Merge Videos'),
                    ),
              SizedBox(height: 20),
              if (outputFilePath != null)
                Text(
                  "Output saved at: $outputFilePath",
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
