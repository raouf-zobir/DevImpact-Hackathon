import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sama/core/networking/gemini_api_services.dart';
import 'package:sama/core/networking/api_constant.dart';
import 'package:sama/core/utils/header_with_search.dart';

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class EmailService {
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _username = 'aotdevimpact@gmail.com';
  static const String _password = 'vszx bbbx knal cxdy';

  final String _studentsCsvPath =
      'C:/Users/Raouf/Desktop/Project/Students/students.csv';
  final String _teachersCsvPath =
      'C:/Users/Raouf/Desktop/Project/Teachers/teachers.csv';

  Map<String, List<List<dynamic>>> _cachedData = {};

  String? _normalizeGrade(String? gradeText) {
    if (gradeText == null) return null;
    final normalized = gradeText.toLowerCase().replaceAll(' ', '');

    final gradePatterns = {
      RegExp(r'grade(\d+)'): (Match m) => 'grade${m.group(1)}',
      RegExp(r'g(\d+)'): (Match m) => 'grade${m.group(1)}',
      RegExp(r'^(\d+)(st|nd|rd|th)?grade'): (Match m) => 'grade${m.group(1)}',
      RegExp(r'^(\d+)(st|nd|rd|th)?$'): (Match m) => 'grade${m.group(1)}',
    };

    for (var pattern in gradePatterns.keys) {
      if (pattern.hasMatch(normalized)) {
        return gradePatterns[pattern]!(pattern.firstMatch(normalized)!);
      }
    }
    return null;
  }

  Future<void> _loadCsvData(String path, String type) async {
    if (!_cachedData.containsKey(type)) {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('CSV file not found at $path');
      }
      final csvString = await file.readAsString();
      _cachedData[type] = const CsvToListConverter().convert(csvString);
    }
  }

  Future<List<String>> getEmailAddresses(String recipientType,
      {List<String>? levels, List<String>? sections}) async {
    final normalizedRecipientType =
        recipientType.replaceAll(' ', '').toLowerCase();
    final List<String> emailList = [];
    final normalizedLevels =
        levels?.map((level) => _normalizeGrade(level)).toList();
    final normalizedSections =
        sections?.map((s) => s.trim().toLowerCase()).toList();

    if (normalizedRecipientType.contains('teachers')) {
      await _loadCsvData(_teachersCsvPath, 'teachers');
      const emailIndex = 5;

      for (var row in _cachedData['teachers']!) {
        if (row.length <= emailIndex || row[0] == "ID") continue;
        String? teacherEmail = row[emailIndex]?.toString().trim();
        if (teacherEmail != null && teacherEmail.isNotEmpty) {
          emailList.add(teacherEmail);
        }
      }
    }

    if (normalizedRecipientType.contains('students') ||
        normalizedRecipientType.contains('parents') ||
        normalizedRecipientType.contains('both')) {
      await _loadCsvData(_studentsCsvPath, 'students');
      const emailIndex = 5;
      const parentEmailIndex = 10;
      const gradeIndex = 13;
      const sectionIndex = 14;

      for (var row in _cachedData['students']!) {
        if (row.length <= emailIndex || row[0] == "ID") continue;

        bool includeStudent = true;

        // Check grade if levels are specified
        if (normalizedLevels != null && normalizedLevels.isNotEmpty) {
          String studentGrade =
              _normalizeGrade(row[gradeIndex]?.toString()) ?? '';
          if (!normalizedLevels.contains(studentGrade)) {
            includeStudent = false;
          }
        }

        // Check section if sections are specified
        if (normalizedSections != null && normalizedSections.isNotEmpty) {
          String studentSection =
              row[sectionIndex]?.toString().trim().toLowerCase() ?? '';
          if (!normalizedSections.contains(studentSection)) {
            includeStudent = false;
          }
        }

        if (includeStudent) {
          String? studentEmail = row[emailIndex]?.toString().trim();
          String? parentEmail = row[parentEmailIndex]?.toString().trim();

          if (normalizedRecipientType.contains('students') ||
              normalizedRecipientType.contains('both')) {
            if (studentEmail != null && studentEmail.isNotEmpty) {
              emailList.add(studentEmail);
            }
          }
          if (normalizedRecipientType.contains('parents') ||
              normalizedRecipientType.contains('both')) {
            if (parentEmail != null && parentEmail.isNotEmpty) {
              emailList.add(parentEmail);
            }
          }
        }
      }
    }

    return emailList.toSet().toList();
  }

  Future<void> sendEmail({
    required List<String> recipientTypes,
    List<String>? levels,
    List<String>? sections,
    required String subject,
    required String body,
    List<File>? attachments, // New parameter for attachments
  }) async {
    final smtpServer = SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _username,
      password: _password,
    );

    final emailAddresses = <String>{};

    for (var recipientType in recipientTypes) {
      final addresses = await getEmailAddresses(
        recipientType,
        levels: levels,
        sections: sections,
      );
      emailAddresses.addAll(addresses);
    }

    if (emailAddresses.isEmpty) {
      throw Exception('No recipients found for types: $recipientTypes'
          '${levels != null ? ' in grades $levels' : ''}'
          '${sections != null ? ' in sections $sections' : ''}');
    }

    print('Preparing to send email to ${emailAddresses.length} recipients');

    // Process attachments
    List<Attachment>? emailAttachments;
    if (attachments != null && attachments.isNotEmpty) {
      emailAttachments = [];
      for (var file in attachments) {
        if (await file.exists()) {
          final fileName = path.basename(file.path);
          emailAttachments.add(
            FileAttachment(
              file,
              fileName: fileName,
              contentType: _getContentType(fileName),
            ),
          );
        } else {
          print('Warning: Attachment not found: ${file.path}');
        }
      }
    }

    for (var email in emailAddresses) {
      final message = Message()
        ..from = Address(_username)
        ..recipients.add(Address(email))
        ..subject = subject
        ..text = body;

      // Add attachments to the message
      if (emailAttachments != null) {
        message.attachments.addAll(emailAttachments);
      }

      try {
        await send(message, smtpServer);
        print('Email sent successfully to $email');
      } catch (e) {
        print('Failed to send email to $email: $e');
        throw Exception('Failed to send email: $e');
      }
    }

    print('All emails have been sent.');
  }

  // Helper method to determine content type based on file extension
  String _getContentType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  static RecipientInfo parseRecipientString(String recipients) {
    final parts =
        recipients.toLowerCase().split(',').map((e) => e.trim()).toList();
    List<String> levels = [];
    List<String> types = [];
    List<String> sections = [];

    // First pass: extract grade and section information
    for (var part in parts) {
      if (part.contains('grade') || RegExp(r'g\d+').hasMatch(part)) {
        final gradeMatch = RegExp(r'grade\s*(\d+)|g(\d+)').firstMatch(part);
        if (gradeMatch != null) {
          final gradeNum = gradeMatch.group(1) ?? gradeMatch.group(2);
          levels.add('grade$gradeNum');
        }
      } else if (part.contains('section:')) {
        // Extract section after "section:" prefix and trim any whitespace
        final sectionName = part.split(':')[1].trim();
        if (sectionName.isNotEmpty) {
          sections.add(sectionName);
        }
      }
    }

    // Second pass: handle recipient types
    for (var part in parts) {
      if (part.contains('teachers')) {
        types.add('teachers');
      }
      if (part.contains('students')) {
        types.add('students');
      }
      if (part.contains('parents')) {
        types.add('parents');
      }
      if (part.contains('both')) {
        types.addAll(['students', 'parents']);
      }
    }

    if (types.isEmpty) {
      types.add('students');
    }

    return RecipientInfo(
      types: types.toSet().toList(),
      levels: levels,
      sections: sections,
    );
  }
}

class RecipientInfo {
  final List<String> types;
  final List<String> levels;
  final List<String> sections;

  RecipientInfo({
    required this.types,
    required this.levels,
    this.sections = const [],
  });
}

class EmailData {
  final String recipients;
  final String purpose;
  final String title;
  final String text;

  EmailData({
    required this.recipients,
    required this.purpose,
    required this.title,
    required this.text,
  });

  factory EmailData.fromResponse(String response) {
    // More flexible patterns that can handle various formats
    final recipientsPattern =
        RegExp(r'Recipients?:\s*(.*?)(?=\n|Purpose:|$)', dotAll: true);
    final purposePattern = RegExp(
        r'Purpose:\s*(.*?)(?=\n|Title:|Generated Output:|$)',
        dotAll: true);
    final titlePattern = RegExp(r'Title:\s*(.*?)(?=\n|Text:|$)', dotAll: true);
    final textPattern = RegExp(r'Text:\s*(.*?)(?=\n\n|$)', dotAll: true);

    // Alternative patterns for different response formats
    final altTitlePattern = RegExp(
        r'Generated Output:(?:.*?\n)*?(?:Title:)?\s*(.*?)(?=\n|Text:|$)',
        dotAll: true);
    final altTextPattern =
        RegExp(r'(?:Text:|Dear\s+[^,\n]+,)\s*(.*?)(?=\n\n|$)', dotAll: true);

    // Extract data with fallbacks
    String extractWithFallback(RegExp primaryPattern,
        RegExp? alternativePattern, String defaultValue) {
      final primaryMatch =
          primaryPattern.firstMatch(response)?.group(1)?.trim();
      if (primaryMatch != null && primaryMatch.isNotEmpty) {
        return primaryMatch;
      }
      if (alternativePattern != null) {
        final altMatch =
            alternativePattern.firstMatch(response)?.group(1)?.trim();
        if (altMatch != null && altMatch.isNotEmpty) {
          return altMatch;
        }
      }
      return defaultValue;
    }

    // Handle cases where the response might be just the email text without headers
    if (!response.contains('Recipients:') && !response.contains('Title:')) {
      final lines = response.split('\n');
      return EmailData(
        recipients: 'All',
        purpose: '',
        title: lines.first.trim(),
        text: lines.skip(1).join('\n').trim(),
      );
    }

    return EmailData(
      recipients: extractWithFallback(recipientsPattern, null, 'All'),
      purpose: extractWithFallback(purposePattern, null, ''),
      title: extractWithFallback(titlePattern, altTitlePattern, 'New Message'),
      text: extractWithFallback(textPattern, altTextPattern, ''),
    );
  }

  // Helper method to validate if the email data is complete
  bool isValid() {
    return text.isNotEmpty && title.isNotEmpty;
  }
}

// Update the PromptHistory class
class PromptHistory {
  final String prompt;
  final String response;
  final DateTime timestamp;
  final bool wasSent;
  final String recipients;
  final String? error;

  PromptHistory({
    required this.prompt,
    required this.response,
    required this.timestamp,
    this.wasSent = false,
    this.recipients = '',
    this.error,
  });
}

class ChatBot extends StatefulWidget {
  const ChatBot({Key? key}) : super(key: key);

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _inputController = TextEditingController();
  EmailData? _emailData;
  bool _isLoading = false;
  bool _showEmailPreview = false;
  final EmailService _emailService = EmailService();
  final List<PromptHistory> _promptHistory = [];

  final GeminiAPIService _geminiAPIService =
      GeminiAPIService(apiKey: ApiConstants.apiKey);

  final List<File> _selectedFiles = []; // Add a list to store selected files

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(
            result.paths.map((path) => File(path!)).toList(),
          );
        });
      }
    } catch (e) {
      print('Error picking files: $e');
      Get.snackbar(
        'Error',
        'Failed to pick files: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildAttachmentsList() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attachments:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedFiles.map((file) {
              return Chip(
                label: Text(path.basename(file.path)),
                onDeleted: () {
                  setState(() {
                    _selectedFiles.remove(file);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _resetState() {
    setState(() {
      _inputController.clear();
      _emailData = null;
      _showEmailPreview = false;
      _selectedFiles.clear(); // Clear selected files
    });
  }

  Future<void> _sendMessage() async {
    setState(() => _isLoading = true);

    try {
      const prompt = '''
You are an intelligent email assistant designed to extract recipient information, deduce the purpose of an email, and generate tailored content automatically without clutter or unnecessary responses. Your output must be concise and immediately actionable.

Workflow
Greeting and Input Parsing

Start with:
"Hello! I'm ready to create an email. Please provide your request."

Use natural language processing (NLP) to analyze the user's request and deduce:

Recipients: Teachers, Students, Parents or Both.
Student Grades: Grade 1, Grade 2, Grade 3.
Sections: AI, Cybersecurity, etc. (specified after "section:" in the request)

Avoid asking follow-up questions unless key details are ambiguous.

Information Extraction

Directly deduce the relevant details from the provided text:

Recipients: Clearly categorize them (e.g., "Teachers," "Students - Grade 1 - Section: AI," "Students - Grade 2")
Purpose: Generate a clear, concise description of the email's intent.

Example input:
"Notify all students in Grade 1, section: AI about the upcoming cybersecurity workshop"

Extracted:
Recipients: Students, Grade 1, Section: AI
Purpose: Inform students about upcoming cybersecurity workshop

Content Generation

Based on extracted details, generate:
Title: Clear and concise, summarizing the purpose.
Text: Fully detailed email text, appropriately addressing the audience.

Example Output:
Title: "Cybersecurity Workshop Announcement"
Text: "Dear AI Section Students, we are excited to announce an upcoming cybersecurity workshop..."

Structured Output for Extraction

Present the final result in an easy-to-extract format:

Extracted Information:
Recipients: [e.g., Students, Grade 1, Section: AI]
Purpose: [Short purpose summary]

Generated Output:
Title: [Generated Title]
Text: [Generated Text]

No Clutter Policy
Avoid conversational fluff or redundant confirmations.
Present results immediately for clarity.

Ambiguities or Missing Details
Only prompt the user to clarify if absolutely necessary.
If no specific level is mentioned for Students, default to "All levels."
If no section is specified, assume all sections.
''';
      final responseText = await _geminiAPIService
          .generateContent(prompt + _inputController.text);

      if (responseText != null) {
        _promptHistory.add(PromptHistory(
          prompt: _inputController.text,
          response: responseText,
          timestamp: DateTime.now(),
        ));

        setState(() {
          _emailData = EmailData.fromResponse(responseText);
          _showEmailPreview = true;
        });
      }
    } catch (e) {
      log('Error sending message: $e');
      Get.snackbar(
        'Error',
        'Failed to send message: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update the send email logic
  Future<void> _sendEmail() async {
    try {
      setState(() => _isLoading = true);

      final recipientInfo =
          EmailService.parseRecipientString(_emailData!.recipients);

      await _emailService.sendEmail(
        recipientTypes: recipientInfo.types,
        levels: recipientInfo.levels,
        sections: recipientInfo.sections,
        subject: _emailData!.title,
        body: _emailData!.text,
        attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );

      // Update the last history entry with success status
      if (_promptHistory.isNotEmpty) {
        final lastIndex = _promptHistory.length - 1;
        _promptHistory[lastIndex] = PromptHistory(
          prompt: _promptHistory[lastIndex].prompt,
          response: _promptHistory[lastIndex].response,
          timestamp: _promptHistory[lastIndex].timestamp,
          wasSent: true,
          recipients: _emailData!.recipients,
        );
      }

      Get.snackbar(
        'Success',
        'Email sent successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      _resetState();
    } catch (e) {
      // Update the last history entry with error status
      if (_promptHistory.isNotEmpty) {
        final lastIndex = _promptHistory.length - 1;
        _promptHistory[lastIndex] = PromptHistory(
          prompt: _promptHistory[lastIndex].prompt,
          response: _promptHistory[lastIndex].response,
          timestamp: _promptHistory[lastIndex].timestamp,
          wasSent: false,
          recipients: _emailData!.recipients,
          error: e.toString(),
        );
      }

      Get.snackbar(
        'Error',
        'Failed to send email: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Email History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.blue.shade700),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _promptHistory.length,
                  itemBuilder: (context, index) {
                    final history =
                        _promptHistory[_promptHistory.length - 1 - index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        leading: Icon(
                          history.wasSent ? Icons.check_circle : Icons.error,
                          color: history.wasSent ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          history.prompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generated on: ${history.timestamp.toString().split('.')[0]}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (history.recipients.isNotEmpty)
                              Text(
                                'Recipients: ${history.recipients}',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Response:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(history.response),
                                if (history.error != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error: ${history.error}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _inputController,
          decoration: const InputDecoration(
            labelText: 'Enter your request',
            border: OutlineInputBorder(),
            hintText:
                'e.g., Notify all students about school closure tomorrow due to a water leak',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendMessage,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Generate Email'),
        ),
      ],
    );
  }

  Widget _buildEmailPreview() {
    if (_emailData == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _emailData!.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To: ${_emailData!.recipients}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const Divider(height: 24),
            Text(
              _emailData!.text,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _resetState,
                  child: const Text('Reject'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendEmail,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text('Send Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const HeaderWithSearch(
                  title: "Email Assistant",
                  showSearch: false,
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue.shade50,
                          Colors.white,
                          Colors.white,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_showEmailPreview)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    spreadRadius: 5,
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _inputController,
                                    decoration: InputDecoration(
                                      labelText: 'Enter your request',
                                      labelStyle: TextStyle(
                                          color: Colors.blue.shade400),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                            color: Colors.blue.shade400),
                                      ),
                                      hintText:
                                          'e.g., Notify all students about school closure tomorrow due to a water leak',
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _sendMessage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade400,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text(
                                            'Generate Email',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _pickFiles,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade400,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text(
                                            'Add Attachments',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                  ),
                                  _buildAttachmentsList(),
                                ],
                              ),
                            ),
                          if (_showEmailPreview)
                            Expanded(
                              child: SingleChildScrollView(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.1),
                                        spreadRadius: 5,
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _emailData!.title,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'To: ${_emailData!.recipients}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue.shade400,
                                        ),
                                      ),
                                      Divider(
                                          color: Colors.blue.shade100,
                                          height: 24),
                                      Text(
                                        _emailData!.text,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildAttachmentsList(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: _resetState,
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.red.shade400,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 10),
                                            ),
                                            child: const Text('Reject'),
                                          ),
                                          const SizedBox(width: 16),
                                          ElevatedButton(
                                            onPressed:
                                                _isLoading ? null : _sendEmail,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade400,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 30,
                                                      vertical: 15),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color:
                                                                Colors.white),
                                                  )
                                                : const Text('Send Email'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 60, // Increased from 40
            bottom: 60, // Increased from 40
            child: FloatingActionButton.extended(
              onPressed: _showHistoryDialog,
              backgroundColor: Colors.blue.shade700,
              icon: const Icon(
                Icons.history,
                color: Colors.white,
                size: 32,
              ),
              label: const Text(
                'History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
