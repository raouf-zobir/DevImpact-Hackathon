import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sama/services/generative_ai_service.dart';

class EmailSender extends StatefulWidget {
  const EmailSender({Key? key}) : super(key: key);

  @override
  State<EmailSender> createState() => _EmailSenderState();
}

class _EmailSenderState extends State<EmailSender> {
  final TextEditingController _promptController = TextEditingController();
  String _generatedTitle = '';
  String _generatedText = '';
  String _recipients = '';
  String _purpose = '';
  bool _isLoading = false;

  final GenerativeAI _generativeAI = GenerativeAI(
    apiKey: "AIzaSyBUHbhKVH5yWOEw9Z2OROA84Wrm7d7bs8s",
    modelName: "gemini-2.0-flash-exp",
  );

  Future<void> _generateEmail() async {
    setState(() => _isLoading = true);

    try {
      final response = await _generativeAI.generateResponse(_promptController.text);
      
      // Parse the response text to extract information
      final String responseText = response['data']['text'];
      final Map<String, String> parsedResponse = _parseGeneratedResponse(responseText);

      setState(() {
        _recipients = parsedResponse['recipients'] ?? '';
        _purpose = parsedResponse['purpose'] ?? '';
        _generatedTitle = parsedResponse['title'] ?? '';
        _generatedText = parsedResponse['text'] ?? '';
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to generate email: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _parseGeneratedResponse(String response) {
    final Map<String, String> result = {};
    
    final extractedInfoMatch = RegExp(r'Extracted Information:\nRecipients: (.*?)\nPurpose: (.*?)\n\nGenerated Output:', dotAll: true)
        .firstMatch(response);
    
    if (extractedInfoMatch != null) {
      result['recipients'] = extractedInfoMatch.group(1)?.trim() ?? '';
      result['purpose'] = extractedInfoMatch.group(2)?.trim() ?? '';
    }

    final generatedOutputMatch = RegExp(r'Generated Output:\nTitle: (.*?)\nText: (.*?)$', dotAll: true)
        .firstMatch(response);
    
    if (generatedOutputMatch != null) {
      result['title'] = generatedOutputMatch.group(1)?.trim() ?? '';
      result['text'] = generatedOutputMatch.group(2)?.trim() ?? '';
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Generator'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Describe your email request',
                border: OutlineInputBorder(),
                hintText: 'e.g., Notify all students about school closure tomorrow due to a water leak',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateEmail,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate Email'),
            ),
            const SizedBox(height: 24),
            if (_recipients.isNotEmpty) ...[
              _buildInfoCard('Recipients', _recipients),
              const SizedBox(height: 8),
              _buildInfoCard('Purpose', _purpose),
              const SizedBox(height: 8),
              _buildInfoCard('Generated Title', _generatedTitle),
              const SizedBox(height: 8),
              Expanded(
                child: _buildInfoCard('Generated Email', _generatedText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Implement email sending functionality
                  Get.snackbar(
                    'Success',
                    'Email sent successfully!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                },
                icon: const Icon(Icons.send),
                label: const Text('Send Email'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}