import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sama/core/networking/gemini_api_services.dart';
import 'package:sama/core/networking/api_constant.dart';
import 'package:sama/core/constants/app_colors.dart';

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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
      {String? level}) async {
    final normalizedRecipientType =
        recipientType.replaceAll(' ', '').toLowerCase();
    final List<String> emailList = [];

    // Load appropriate CSV data based on recipient type
    if (normalizedRecipientType.contains('teachers')) {
      await _loadCsvData(_teachersCsvPath, 'teachers');
      const emailIndex =
          5; // Adjust this index based on your teachers.csv structure

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

      for (var row in _cachedData['students']!) {
        if (row.length <= emailIndex || row[0] == "ID") continue;

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
    for (var recipientType in recipientTypes) {
      final addresses = await getEmailAddresses(recipientType, level: level);
      emailAddresses.addAll(addresses);
    }

    if (emailAddresses.isEmpty) {
      throw Exception('No recipients found for types: $recipientTypes');
    }

    print('Preparing to send email to ${emailAddresses.length} recipients');

    for (var email in emailAddresses) {
      final message = Message()
        ..from = Address(_username)
        ..recipients.add(Address(email))
        ..subject = subject
        ..text = body;

      try {
        final sendReport = await send(message, smtpServer);
        print('Email sent successfully to $email');
      } catch (e) {
        print('Failed to send email to $email: $e');
      }
    }

    print('All emails have been sent.');
  }

  static RecipientInfo parseRecipientString(String recipients) {
    final parts = recipients
        .replaceAll(' ', '')
        .toLowerCase()
        .split(',')
        .map((e) => e.trim())
        .toList();
    return RecipientInfo(types: parts, level: null);
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

class EmailHistoryItem {
  final String prompt;
  final EmailData emailData;
  final DateTime timestamp;
  final bool wasSent;

  EmailHistoryItem({
    required this.prompt,
    required this.emailData,
    required this.timestamp,
    required this.wasSent,
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

  final GeminiAPIService _geminiAPIService =
      GeminiAPIService(apiKey: ApiConstants.apiKey);

  final List<EmailHistoryItem> _history = [];

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

      Recipients: Teachers, Students, or Both.

      Recipients: Teachers, Students, Parents or Both.

      Student Levels: L1, L2, L3, or All levels (if applicable).
      Avoid asking follow-up questions unless key details are ambiguous.

      Information Extraction

      Directly deduce the relevant details from the provided text:

      Recipients: Clearly categorize them (e.g., "Teachers," "Students - L1," "Students - All levels").
      Purpose: Generate a clear, concise description of the email's intent.
      Example input:

      "Notify all students about school closure tomorrow due to a water leak."

      Extracted:
      Recipients: Students
      Levels: All levels (implied).
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
      Recipients: [e.g., Teachers, Students - All levels]
      Purpose: [Short purpose summary]

      Generated Output:
      Title: [Generated Title]
      Text: [Generated Text]
      Example:

      Extracted Information:
      Recipients: Students - All levels

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
        final emailData = EmailData.fromResponse(responseText);
        setState(() {
          _emailData = emailData;
          _showEmailPreview = true;
          _history.insert(
              0,
              EmailHistoryItem(
                prompt: _inputController.text,
                emailData: emailData,
                timestamp: DateTime.now(),
                wasSent: false,
              ));
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

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppColors.lightestGray,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.borderGray)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Email History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          item.emailData.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'To: ${item.emailData.recipients}',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prompt: ${item.prompt}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Created: ${item.timestamp.toString().substring(0, 16)}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          item.wasSent ? Icons.check_circle : Icons.history,
                          color: item.wasSent ? Colors.green : Colors.grey,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _emailData = item.emailData;
                            _showEmailPreview = true;
                          });
                        },
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightestGray,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.subtleGray.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inputController,
            decoration: InputDecoration(
              labelText: 'Enter your request',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              filled: true,
              fillColor: AppColors.lightGray,
              hintText:
                  'e.g., Notify all students about school closure tomorrow due to a water leak',
              hintStyle: TextStyle(color: AppColors.darkGray),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.buttonBlue,
                  AppColors.buttonBlue.withBlue(255),
                ],
              ),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Generate Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailPreview() {
    if (_emailData == null) return const SizedBox.shrink();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightestGray, AppColors.lightPurple],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _emailData!.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: AppColors.textBlack,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'To: ${_emailData!.recipients}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Divider(height: 32, color: AppColors.borderGray),
            Text(
              _emailData!.text,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppColors.textBlack,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _resetState,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.secondaryGreen,
                        AppColors.secondaryGreen.withGreen(200),
                      ],
                    ),
                  ),
                  child: ElevatedButton(
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
                        setState(() {
                          if (_history.isNotEmpty) {
                            final latestEmail = _history.first;
                            _history[0] = EmailHistoryItem(
                              prompt: latestEmail.prompt,
                              emailData: latestEmail.emailData,
                              timestamp: latestEmail.timestamp,
                              wasSent: true,
                            );
                          }
                        });
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Send Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
        title: Text(
          'Email Assistant',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textBlack,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.lightestGray,
        foregroundColor: AppColors.textBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: AppColors.backgroundWhite,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
