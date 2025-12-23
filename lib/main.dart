import 'package:flutter/material.dart';

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
//import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Lock Shuffle',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Selected Photos'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool storagePermissionStatus = false;
  Future<Directory>? appDocumentsDirectory;
  Future<String?> albumPath = Future<String>.value("");
  List<Image> wallpaperImages = [];

  @override
  void initState() {
    super.initState();
    checkStoragePermission();
    requestStoragePermission();
    setApplicationDocumentsDirectory();
    getWallpaperImageList(context);
  }

  Future<void> checkStoragePermission() async {
    final DeviceInfoPlugin plugin = DeviceInfoPlugin();
    final AndroidDeviceInfo android = await plugin.androidInfo;

    if (android.version.sdkInt >= 33) {
      var photoStatus = await Permission.photos.status;
      var videoStatus = await Permission.videos.status;
      setState( () {storagePermissionStatus = (photoStatus.isGranted && videoStatus.isGranted);} );
    }
    else {
      var status = await Permission.storage.request();
      setState( () {storagePermissionStatus = (status.isGranted);} );
    }
  }

  Future<Directory> setApplicationDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<void> requestStoragePermission() async {
    final DeviceInfoPlugin plugin = DeviceInfoPlugin();
    final AndroidDeviceInfo android = await plugin.androidInfo;

    if (!storagePermissionStatus) {
      if (android.version.sdkInt >= 33) {
        var photoStatus = await Permission.photos.request();
        var videoStatus = await Permission.videos.request();
        if (photoStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied) {
            await openAppSettings();
        }
        else if (photoStatus.isDenied || videoStatus.isDenied) {
          requestStoragePermission();
        }
      } 
      else {
        var status = await Permission.storage.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        else if (status.isDenied || status.isDenied) {
          requestStoragePermission();
        }
      }
    }
    checkStoragePermission();
  }

  Future<void> folderSelector(BuildContext context) async {
    final Directory? externalStorageDirectory = await getExternalStorageDirectory();

    if (context.mounted) {
      final path = FilesystemPicker.openDialog(context: context, rootDirectory: externalStorageDirectory, fsType: FilesystemType.folder, title:"Select Album");
      setState(() {albumPath = (path);});
    }
  }

  void toast(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> copyAlbumToLocalAppStorage(BuildContext context) async {
    String? albumPathString = await(albumPath);
    if (albumPathString != null) {
      final albumDirectory = Directory(albumPathString);
      List<FileSystemEntity> files = albumDirectory.listSync(recursive: true, followLinks: false);

      for (FileSystemEntity entity in files) {
        if (entity is File) {
          try {
            entity.copy(appDocumentsDirectory as String);
          }
          catch (e) {
            if (context.mounted) {
              toast(context, e.toString());
            }
          }
        }
      }
    }
  }

  void getWallpaperImageList(BuildContext context) async {
    final directory = await appDocumentsDirectory;
    List<Image> imageList = [];
    if (directory != null) {
      List<FileSystemEntity> files = directory.listSync(recursive: true, followLinks: false);
      for (FileSystemEntity entity in files) {
        if (entity is File) {
          try {
            imageList.add(Image.file(entity));
          }
          catch (e) {
            if (context.mounted) {
              toast(context, e.toString());
            }
          }
        }
      }
    }
    wallpaperImages = imageList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Expanded(
        child: GridView.builder(
          itemCount: wallpaperImages.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 0.0,
            mainAxisSpacing: 0.0,
          ),
          itemBuilder: (context, index) {
            return wallpaperImages[index];
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (storagePermissionStatus) {
            folderSelector(context); 
          }
          else {
            toast(context, "Unable to Access Storage");
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
