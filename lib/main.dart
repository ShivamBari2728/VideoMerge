import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
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
      title: 'Video Merger',
      home: Scaffold(
        extendBodyBehindAppBar:
            true, // Extends body behind the AppBar to make it part of the background
        appBar: AppBar(
          title: Text('Video Merger'),
          backgroundColor:
              Colors.transparent, // Transparent background for the AppBar
          elevation: 0, // Removes the shadow under the AppBar
          centerTitle: true,
          iconTheme: IconThemeData(
              color: Colors.white), // Optional: Make drawer icon white
        ),
        drawer: Drawer(
          child: ListView(
            padding:
                EdgeInsets.zero, // Ensures no padding around drawer content
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                        'assets/images/background2.jpg'), // Background image for the drawer header
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 45, // Adjust the radius as needed
                      backgroundImage: AssetImage(
                          'assets/images/background.jpg'), // Profile or logo image
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Video Merge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                  leading: Icon(
                      Icons.person_outline), // Icon for 'Contact Developer'
                  title: Text('Contact Developer'),
                  onTap: () {
                    launchUrl(Uri.parse("https://github.com/ShivamBari2728"));
                  }),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                  'assets/images/background2.jpg'), // Path to your image
              fit: BoxFit.cover, // Adjust the image's fit
            ),
          ),
          child: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Container(
                    height: 150,
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                        // color: Colors.amber,
                        // image: DecorationImage(
                        //   image: AssetImage(
                        //       'assets/images/background.jpg'), // Background image path
                        //   fit: BoxFit
                        //       .cover, // Adjusts how the image fits in the container
                        //   colorFilter: ColorFilter.mode(
                        //     Colors.black.withOpacity(
                        //         0.2), // Darkens the image for better text visibility
                        //     BlendMode.darken,
                        //   ),
                        // ),
                        ),
                    child: Center(
                      child: Container(
                        width: 300,
                        decoration: BoxDecoration(
                          color: Colors
                              .transparent, // Background color of the container
                          borderRadius: BorderRadius.circular(
                              10), // Optional: Rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                  0.2), // Shadow color with opacity
                              spreadRadius: 5, // Spread radius of the shadow
                              blurRadius: 5, // Blur radius of the shadow
                              offset:
                                  Offset(0, 3), // Offset of the shadow (x, y)
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lightbulb, // Tip icon
                              color: Colors.yellow,
                              size: 30,
                            ),
                            SizedBox(
                                width: 10), // Spacing between icon and text
                            Expanded(
                              child: Text(
                                'Pick videos with same aspect ratio.',
                                style: TextStyle(
                                  color:
                                      Colors.white, // Text color for contrast
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: pickVideos,
                          icon: Icon(
                            Icons.video_library,
                            color: Colors.white70,
                          ), // Icon before the text
                          label: Text(
                            'Pick Videos',
                            style: TextStyle(color: Colors.white70),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12), // Rounded corners
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16), // Button padding
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      isloading
                          ? CircularProgressIndicator()
                          : SizedBox(
                              width: 200,
                              child: ElevatedButton.icon(
                                onPressed: selectedVideos == null ||
                                        selectedVideos!.isEmpty
                                    ? null
                                    : _videoMerger,
                                icon: Icon(
                                  Icons.merge_type,
                                  color: Colors.white70,
                                ), // Icon for merging videos
                                label: Text(
                                  'Merge Videos',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        12), // Rounded corners
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16), // Button padding
                                ),
                              ),
                            ),
                      SizedBox(height: 20),
                      if (outputFilePath != null)
                        Text(
                          "Output saved at: $outputFilePath",
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}
