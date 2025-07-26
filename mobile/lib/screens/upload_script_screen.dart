import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/ai_service.dart';
import '../services/ocr_service.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';
import '../screens/mark_script_screen.dart';

enum UploadStage {
  studentInfo,
  questionPaper,
  markingGuide,
  answerScript,
  review
}

class UploadScriptScreen extends StatefulWidget {
  const UploadScriptScreen({super.key});

  @override
  State<UploadScriptScreen> createState() => _UploadScriptScreenState();
}

class _UploadScriptScreenState extends State<UploadScriptScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  UploadStage _currentStage = UploadStage.studentInfo;
  bool _isLoading = false;
  bool _useAIProcessing = true;

  // Document storage
  File? _questionPaper;
  File? _markingGuide;
  final List<File> _answerScripts = [];
  String _extractedText = '';

  Future<void> _pickImage({bool isAnswerScript = false}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
          if (isAnswerScript) {
            _answerScripts.add(File(pickedFile.path));
          } else if (_currentStage == UploadStage.questionPaper) {
            _questionPaper = File(pickedFile.path);
          } else if (_currentStage == UploadStage.markingGuide) {
            _markingGuide = File(pickedFile.path);
          }
        });

        await _processDocuments();
      }
    } catch (e) {
      _showSnackBar("Image selection failed: ${e.toString()}", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _captureImage({bool isAnswerScript = false}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
          if (isAnswerScript) {
            _answerScripts.add(File(pickedFile.path));
          } else if (_currentStage == UploadStage.questionPaper) {
            _questionPaper = File(pickedFile.path);
          } else if (_currentStage == UploadStage.markingGuide) {
            _markingGuide = File(pickedFile.path);
          }
        });

        await _processDocuments();
      }
    } catch (e) {
      _showSnackBar("Camera failed: ${e.toString()}", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processDocuments() async {
    try {
      if (_currentStage == UploadStage.answerScript) {
        await _processAnswerScripts();
      }

      setState(() => _isLoading = false);
      _moveToNextStage();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Processing failed: ${e.toString()}", isError: true);
    }
  }

  Future<void> _processAnswerScripts() async {
    String fullText = '';
    final ocrService = OCRService();

    for (final file in _answerScripts) {
      final imageText = await ocrService.extractTextFromImage(file);
      fullText += imageText + '\n\n';
    }

    if (_useAIProcessing) {
      final aiService = AIService();
      try {
        final extractedAnswers = await aiService.extractAnswersFromText(
          fullText,
          useGroq: true,
        );
        
        if (extractedAnswers.isNotEmpty) {
          fullText = extractedAnswers.entries
            .map((e) => "${e.key}: ${e.value}")
            .join('\n');
        }
      } catch (aiError) {
        _showSnackBar("AI processing failed, using raw text", isError: true);
      }
    }

    setState(() => _extractedText = fullText);
  }

  void _moveToNextStage() {
    if (_currentStage == UploadStage.review) return;
    
    setState(() {
      _currentStage = UploadStage.values[_currentStage.index + 1];
    });
  }

  void _moveToPreviousStage() {
    if (_currentStage == UploadStage.studentInfo) return;
    
    setState(() {
      _currentStage = UploadStage.values[_currentStage.index - 1];
    });
  }

  Future<void> _saveScript({bool goToMarking = false}) async {
    if (!_validateFields()) return;
    if (_answerScripts.isEmpty) {
      _showSnackBar("Please upload answer scripts", isError: true);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar("User not logged in", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scriptData = {
        'name': _nameController.text.trim(),
        'studentNumber': _studentNumberController.text.trim(),
        'ocrText': _extractedText,
        'status': 'unmarked',
        'timestamp': Timestamp.now(),
        'userId': currentUser.uid,
        'answerScriptCount': _answerScripts.length,
        'hasQuestionPaper': _questionPaper != null,
        'hasMarkingGuide': _markingGuide != null,
        'aiProcessed': _useAIProcessing,
      };

      final docRef = await FirebaseFirestore.instance.collection('scripts').add(scriptData);

      _showSnackBar("Script saved successfully!");

      if (goToMarking) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarkScriptScreen(
              script: {
                'id': docRef.id,
                'name': scriptData['name'],
                'studentNumber': scriptData['studentNumber'],
                'ocrText': _extractedText,
                'timestamp': scriptData['timestamp'],
              },
              guideAnswers: [],
            ),
          ),
        );
      } else {
        _resetForm();
      }
    } catch (e) {
      _showSnackBar("Failed to save: ${e.toString()}", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Please enter student name", isError: true);
      return false;
    }
    if (_studentNumberController.text.trim().isEmpty) {
      _showSnackBar("Please enter student number", isError: true);
      return false;
    }
    return true;
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _studentNumberController.clear();
      _questionPaper = null;
      _markingGuide = null;
      _answerScripts.clear();
      _extractedText = '';
      _currentStage = UploadStage.studentInfo;
    });
  }

  Future<void> _removeFile(bool isAnswerScript) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Removal"),
        content: const Text("Are you sure you want to remove this document?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        if (isAnswerScript) {
          _answerScripts.clear();
        } else if (_currentStage == UploadStage.questionPaper) {
          _questionPaper = null;
        } else {
          _markingGuide = null;
        }
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCurrentStage() {
    switch (_currentStage) {
      case UploadStage.studentInfo:
        return _buildStudentInfoStage();
      case UploadStage.questionPaper:
        return _buildDocumentStage(
          title: "Upload Question Paper",
          description: "Please upload the question paper (image)",
          file: _questionPaper,
          isAnswerScript: false,
        );
      case UploadStage.markingGuide:
        return _buildDocumentStage(
          title: "Upload Marking Guide",
          description: "Please upload the marking guide (image)",
          file: _markingGuide,
          isAnswerScript: false,
        );
      case UploadStage.answerScript:
        return _buildDocumentStage(
          title: "Upload Answer Script",
          description: "Please upload student's answer script (images)",
          file: null,
          isAnswerScript: true,
        );
      case UploadStage.review:
        return _buildReviewStage();
    }
  }

  Widget _buildStudentInfoStage() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Student Information",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _studentNumberController,
              decoration: const InputDecoration(
                labelText: 'Student Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
                hintText: 'e.g., 2023/001234',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_validateFields()) {
                  _moveToNextStage();
                }
              },
              child: const Text("Continue"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentStage({
    required String title,
    required String description,
    required File? file,
    required bool isAnswerScript,
  }) {
    final hasFile = isAnswerScript ? _answerScripts.isNotEmpty : file != null;
    final fileCount = isAnswerScript ? _answerScripts.length : 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            if (hasFile)
              isAnswerScript
                ? SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _answerScripts.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _answerScripts[index],
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 14),
                                    onPressed: () => _removeFile(true),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${index + 1}/$fileCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : ListTile(
                    leading: const Icon(Icons.image),
                    title: Text(file!.path.split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeFile(false),
                    ),
                  )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('No document uploaded yet',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                  onPressed: _isLoading ? null : () => _pickImage(isAnswerScript: isAnswerScript),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  onPressed: _isLoading ? null : () => _captureImage(isAnswerScript: isAnswerScript),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _moveToPreviousStage,
                    child: const Text("Back"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasFile ? _moveToNextStage : null,
                    child: const Text("Continue"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStage() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Review Submission",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            const Text("Student Information:", 
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Name: ${_nameController.text.trim()}"),
            Text("Student Number: ${_studentNumberController.text.trim()}"),
            const SizedBox(height: 16),
            
            const Text("Documents:", 
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Question Paper: ${_questionPaper?.path.split('/').last ?? 'Not provided'}"),
            Text("Marking Guide: ${_markingGuide?.path.split('/').last ?? 'Not provided'}"),
            Text("Answer Scripts: ${_answerScripts.length} file(s)"),
            const SizedBox(height: 16),
            
            const Text("Processing Options:", 
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                const Text("AI Enhancement:"),
                const SizedBox(width: 8),
                Switch(
                  value: _useAIProcessing,
                  onChanged: (value) => setState(() => _useAIProcessing = value),
                ),
                Text(_useAIProcessing ? "ON" : "OFF"),
              ],
            ),
            const SizedBox(height: 16),
            
            const Text("Extracted Text Preview:", 
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _extractedText.isNotEmpty 
                      ? _extractedText 
                      : "No text extracted yet",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _moveToPreviousStage,
                    child: const Text("Back"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveScript(goToMarking: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text("Save Only"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveScript(goToMarking: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text("Save & Mark"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStage == UploadStage.studentInfo
            ? "New Script Upload"
            : "Step ${_currentStage.index} of ${UploadStage.values.length - 1}"),
        centerTitle: true,
        actions: [
          if (_currentStage == UploadStage.review)
            IconButton(
              icon: Icon(_useAIProcessing 
                  ? Icons.auto_awesome 
                  : Icons.auto_awesome_outlined),
              onPressed: () => setState(() => _useAIProcessing = !_useAIProcessing),
              tooltip: "Toggle AI Processing",
            ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_currentStage != UploadStage.studentInfo)
                LinearProgressIndicator(
                  value: (_currentStage.index) / (UploadStage.values.length - 1),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              const SizedBox(height: 20),
              _buildCurrentStage(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 1),
    );
  }
}