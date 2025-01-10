import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sama/core/networking/gemini_api_services.dart';
import 'package:sama/core/networking/api_constant.dart';

class ChatBot extends StatefulWidget {
  const ChatBot({Key? key}) : super(key: key);

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _inputController = TextEditingController();
  String _responseText = '';
  bool _isLoading = false;

  final GeminiAPIService _geminiAPIService = GeminiAPIService(apiKey: ApiConstants.apiKey);

  Future<void> _sendMessage() async {
    setState(() => _isLoading = true);

    try {
      final prompt = '''
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

      final responseText = await _geminiAPIService.generateContent(prompt + _inputController.text);

      setState(() {
        _responseText = responseText ?? 'No response from AI';
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI ChatBot'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'Enter your request',
                border: OutlineInputBorder(),
                hintText: 'e.g., Notify all students about school closure tomorrow due to a water leak',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendMessage,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Send Message'),
            ),
            const SizedBox(height: 24),
            if (_responseText.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_responseText),
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
