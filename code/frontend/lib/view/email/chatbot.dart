import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sama/core/networking/gemini_api_services.dart';
import 'package:sama/core/networking/api_constant.dart';

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _username = 'aotdevimpact@gmail.com';
  static const String _password = 'vszx bbbx knal cxdy';

  final String _studentsCsvPath = 'C:/Users/msi/Desktop/Project/Students/students.csv';
  final String _teachersCsvPath = 'C:/Users/msi/Desktop/Project/Teachers/teachers.csv';
  
  Map<String, List<List<dynamic>>> _cachedData = {};

  // Helper method to extract and normalize grade information
  String? _normalizeGrade(String? gradeText) {
    if (gradeText == null) return null;
    
    // Remove whitespace and convert to lowercase
    final normalized = gradeText.toLowerCase().replaceAll(' ', '');
    
    // Handle various grade formats
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

  Future<List<String>> getEmailAddresses(String recipientType, {String? level}) async {
    final normalizedRecipientType = recipientType.replaceAll(' ', '').toLowerCase();
    final List<String> emailList = [];
    final normalizedLevel = _normalizeGrade(level);

    // Load appropriate CSV data based on recipient type
    if (normalizedRecipientType.contains('teachers')) {
      await _loadCsvData(_teachersCsvPath, 'teachers');
      const emailIndex = 5; // Adjust this index based on your teachers.csv structure

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
      const emailIndex = 5; // Student email column
      const parentEmailIndex = 10; // Parent email column
      const gradeIndex = 13; // Grade column index

      for (var row in _cachedData['students']!) {
        if (row.length <= emailIndex || row[0] == "ID") continue;

        // Check grade if level is specified
        if (normalizedLevel != null) {
          String studentGrade = _normalizeGrade(row[gradeIndex]?.toString()) ?? '';
          if (studentGrade != normalizedLevel) continue;
        }

        String? studentEmail = row[emailIndex]?.toString().trim();
        String? parentEmail = row[parentEmailIndex]?.toString().trim();

        if (normalizedRecipientType.contains('students') || normalizedRecipientType.contains('both')) {
          if (studentEmail != null && studentEmail.isNotEmpty) {
            emailList.add(studentEmail);
          }
        }
        if (normalizedRecipientType.contains('parents') || normalizedRecipientType.contains('both')) {
          if (parentEmail != null && parentEmail.isNotEmpty) {
            emailList.add(parentEmail);
          }
        }
      }
    }

    return emailList.toSet().toList();
  }

  Future<void> sendEmail({
    required List<String> recipientTypes,
    String? level,
    required String subject,
    required String body,
  }) async {
    final smtpServer = SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _username,
      password: _password,
    );

    final emailAddresses = <String>{};
    
    // Process each recipient type separately
    for (var recipientType in recipientTypes) {
      final addresses = await getEmailAddresses(recipientType, level: level);
      emailAddresses.addAll(addresses);
    }

    if (emailAddresses.isEmpty) {
      throw Exception('No recipients found for types: $recipientTypes${level != null ? ' in grade $level' : ''}');
    }

    print('Preparing to send email to ${emailAddresses.length} recipients');

    for (var email in emailAddresses) {
      final message = Message()
        ..from = Address(_username)
        ..recipients.add(Address(email))
        ..subject = subject
        ..text = body;

      try {
        await send(message, smtpServer);
        print('Email sent successfully to $email');
      } catch (e) {
        print('Failed to send email to $email: $e');
      }
    }

    print('All emails have been sent.');
  }

  static RecipientInfo parseRecipientString(String recipients) {
    final parts = recipients.toLowerCase().split(',').map((e) => e.trim()).toList();
    String? level;
    List<String> types = [];

    // First pass: extract grade information
    for (var part in parts) {
      if (part.contains('grade') || RegExp(r'g\d+').hasMatch(part)) {
        // Extract grade number and standardize format
        final gradeMatch = RegExp(r'grade\s*(\d+)|g(\d+)').firstMatch(part);
        if (gradeMatch != null) {
          final gradeNum = gradeMatch.group(1) ?? gradeMatch.group(2);
          level = 'grade$gradeNum';
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

    // Ensure types list is not empty
    if (types.isEmpty) {
      types.add('students'); // Default to 'students' if no specific type is found
    }

    return RecipientInfo(types: types.toSet().toList(), level: level);
  }
}

class RecipientInfo {
  final List<String> types;
  final String? level;

  RecipientInfo({required this.types, this.level});
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

  final GeminiAPIService _geminiAPIService =
      GeminiAPIService(apiKey: ApiConstants.apiKey);

  void _resetState() {
    setState(() {
      _inputController.clear();
      _emailData = null;
      _showEmailPreview = false;
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

      "Hello! I’m ready to create an email. Please provide your request."

      Use natural language processing (NLP) to analyze the user’s request and deduce:

      Recipients: Teachers, Students, Parents or Both.

      Student Grades: Grade 1, Grade 2, Grade 3.
      Avoid asking follow-up questions unless key details are ambiguous.

      Information Extraction

      Directly deduce the relevant details from the provided text:

      Recipients: Clearly categorize them (e.g., "Teachers," "Students - Grade 1," "Students - Grade 2").
      Purpose: Generate a clear, concise description of the email's intent.
      Example input:

      "Notify all students about school closure tomorrow due to a water leak."

      Extracted:
      Recipients: Students
      Levels: none (implied).
      Purpose: Inform students about school closure due to a water leak.

      Content Generation

      Based on extracted details, generate:
      Title: Clear and concise, summarizing the purpose.
      Text: Fully detailed email text, appropriately addressing the audience.
      Example Output:
      Title: "School Closure Tomorrow Due to Water Leak"
      Text: "Dear Students, please be advised that the school will be closed tomorrow due to a water leak. We apologize for any inconvenience this may cause. Further updates will be provided as they become available."

      Structured Output for Extraction

      Present the final result in an easy-to-extract format.
      Output Format:

      Extracted Information:
      Recipients: [e.g., Teachers, Students]
      Purpose: [Short purpose summary]

      Generated Output:
      Title: [Generated Title]
      Text: [Generated Text]
      Example:

      Extracted Information:
      Recipients: Students 

      Generated Output:
      Title: School Closure Tomorrow Due to Water Leak
      Text: Dear Students, please be advised that the school will be closed tomorrow due to a water leak. We apologize for any inconvenience this may cause. Further updates will be provided as they become available.

      No Clutter Policy

      Avoid conversational fluff like “Okay, processing your request…” or redundant confirmations.
      Present results immediately for clarity.
      Ambiguities or Missing Details

      Only prompt the user to clarify if absolutely necessary. If no specific level is mentioned for Students, default to “All levels.”
      ''';

      final responseText = await _geminiAPIService
          .generateContent(prompt + _inputController.text);

      if (responseText != null) {
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
                  onPressed: () async {
                    try {
                      setState(() => _isLoading = true);

                      final recipientInfo = EmailService.parseRecipientString(
                          _emailData!.recipients);

                      await _emailService.sendEmail(
                        recipientTypes: recipientInfo.types,
                        level: recipientInfo.level,
                        subject: _emailData!.title,
                        body: _emailData!.text,
                      );

                      Get.snackbar(
                        'Success',
                        'Email sent successfully!',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                      _resetState();
                    } catch (e) {
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
                  },
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
      appBar: AppBar(
        title: const Text('Email Assistant'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_showEmailPreview) _buildInputSection(),
            if (_showEmailPreview)
              Expanded(
                child: SingleChildScrollView(
                  child: _buildEmailPreview(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
