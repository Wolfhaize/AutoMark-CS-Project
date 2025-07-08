import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/answer_provider.dart';
import '../providers/result_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String scannedText = '';
  File? _pickedImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    setState(() {
      _pickedImage = imageFile;
    });

    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    String extractedText = recognizedText.text;
    setState(() {
      scannedText = extractedText;
    });

    // Convert text to answers
    List<String> studentAnswers = extractedText
        .replaceAll('\n', ',')
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final correctAnswers = context.read<AnswerProvider>().correctAnswers;
    context.read<ResultProvider>().calculateScore(studentAnswers, correctAnswers);

    textRecognizer.close();

    // Navigate to result screen
    Navigator.pushNamed(context, '/result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Script")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload),
              label: const Text("Pick Image"),
            ),
            const SizedBox(height: 20),
            _pickedImage != null
                ? Image.file(_pickedImage!, height: 200)
                : const Text("No image selected."),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  scannedText,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}