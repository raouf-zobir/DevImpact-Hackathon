import 'dart:convert';
import 'package:http/http.dart' as http;

class GenerativeAI {
  final String apiKey;
  final String modelName;
  final String apiUrl;

  GenerativeAI({
    required this.apiKey,
    required this.modelName,
    this.apiUrl = "https://api.generativeai.google.com/v1/models",
  });

  Future<Map<String, dynamic>> generateResponse(String prompt) async {
    final url = Uri.parse("$apiUrl/$modelName:generateText");

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final body = {
      "prompt": prompt,
      "generation_config": {
        "temperature": 1,
        "top_p": 0.95,
        "top_k": 40,
        "max_output_tokens": 8192,
        "response_mime_type": "text/plain",
      },
    };

    final response = await http.post(url, headers: headers, body: jsonEncode(body));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to get response: ${response.statusCode}, ${response.body}");
    }
  }
}