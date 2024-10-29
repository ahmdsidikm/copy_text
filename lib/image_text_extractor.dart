import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'camera_screen.dart';

class ImageTextExtractor extends StatefulWidget {
  const ImageTextExtractor({Key? key}) : super(key: key);

  @override
  State<ImageTextExtractor> createState() => _ImageTextExtractorState();
}

class _ImageTextExtractorState extends State<ImageTextExtractor> {
  String extractedText = '';
  File? _image;
  final picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await _handlePermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please grant required permissions in settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _handlePermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt <= 32) {
        // Android 12 or lower
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        // Android 13 or higher
        final status = await Permission.photos.request();
        return status.isGranted;
      }
    }
    return true; // For iOS or other platforms
  }

  void _navigateToCameraScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScreen(),
      ),
    );
  }

  Future<void> getImageFromGallery() async {
    try {
      // Check Android version
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 32) {
          // Android 12 or lower
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) {
              throw PlatformException(
                  code: 'PERMISSION_DENIED',
                  message: 'Storage permission is required');
            }
          }
        } else {
          // Android 13 or higher
          var status = await Permission.photos.status;
          if (!status.isGranted) {
            status = await Permission.photos.request();
            if (!status.isGranted) {
              throw PlatformException(
                  code: 'PERMISSION_DENIED',
                  message: 'Photos permission is required');
            }
          }
        }
      }

      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          extractedText = ''; // Clear previous text when new image is selected
        });
        await extractTextFromImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> extractTextFromImage() async {
    if (_image != null) {
      try {
        final inputImage = InputImage.fromFile(_image!);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        setState(() {
          extractedText = recognizedText.text;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading text: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekstraktor Teks Gambar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _navigateToCameraScreen,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_image != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _image!,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 230, 230, 230),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!, width: 1),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Color.fromARGB(179, 63, 63, 63),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Tidak ada gambar yang dipilih',
                          style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(179, 136, 136, 136)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: getImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pilih gambar dari galeri'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              if (extractedText.isNotEmpty)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Extracted Text:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: extractedText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Text copied to clipboard'),
                                  ),
                                );
                              },
                              tooltip: 'Copy text',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          extractedText,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.left,
                          toolbarOptions: const ToolbarOptions(
                            copy: true,
                            selectAll: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
