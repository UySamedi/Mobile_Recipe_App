import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  State<IngredientScannerScreen> createState() => _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  String _foodNameDisplay = "សូមបញ្ចូលរូបភាពគ្រឿងផ្សំ";
  String? _foodNameSearch;
  bool _isProcessing = false;

  final model = GenerativeModel(
    model: 'gemini-3.5-flash',
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_GEMINI_API_KEY_HERE', 
  );

  Future<void> _identifyFood(ImageSource source) async {
    final XFile? imageFile = await _picker.pickImage(source: source);
    
    if (imageFile != null) {
      if (!mounted) return;

      // Check if API key is not configured
      final currentApiKey = dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_GEMINI_API_KEY_HERE';
      if (currentApiKey == 'YOUR_GEMINI_API_KEY_HERE' || currentApiKey.trim().isEmpty) {
        setState(() {
          _foodNameDisplay = "បាត់ API Key! សូមបន្ថែម Gemini API Key របស់អ្នកទៅក្នុងឯកសារ .env។";
        });
        return;
      }

      setState(() {
        _isProcessing = true;
        _foodNameDisplay = "កំពុងស្កេនរូបភាព...";
        _foodNameSearch = null;
      });

      try {
        final bytes = await File(imageFile.path).readAsBytes();
        final imagePart = DataPart('image/jpeg', bytes);
        
        final prompt = TextPart('''
          Look at this image. What meat, vegetable, or ingredient is this? 
          Return the answer STRICTLY as a JSON object with two keys:
          - "khmer_name": The short name in Khmer (e.g., សាច់គោ)
          - "english_search_term": The short name in English (e.g., beef)
          Do not include any other text, markdown formatting, or explanations.
        ''');

        final response = await model.generateContent([
          Content.multi([prompt, imagePart])
        ]);

        if (response.text != null && mounted) {
          // Parse the JSON response
          // Remove any markdown block characters (```json ... ```) if Gemini includes them
          String cleanText = response.text!.trim();
          if (cleanText.startsWith('```json')) {
            cleanText = cleanText.substring(7);
          }
          if (cleanText.startsWith('```')) {
            cleanText = cleanText.substring(3);
          }
          if (cleanText.endsWith('```')) {
            cleanText = cleanText.substring(0, cleanText.length - 3);
          }
          cleanText = cleanText.trim();

          final Map<String, dynamic> data = jsonDecode(cleanText);

          setState(() {
            _foodNameDisplay = data['khmer_name'] ?? 'មិនស្គាល់'; 
            _foodNameSearch = data['english_search_term']; 
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          if (e.toString().contains('503') || e.toString().contains('high demand')) {
            _foodNameDisplay = "ប្រព័ន្ធកំពុងមានអ្នកប្រើប្រាស់ច្រើន។ សូមរង់ចាំបន្តិចហើយព្យាយាមម្តងទៀត។";
          } else {
            _foodNameDisplay = "មានកំហុសក្នុងការស្កេន។ សូមព្យាយាមម្តងទៀត។";
          }
          _foodNameSearch = null;
        });
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ម៉ាស៊ីនស្កេនគ្រឿងផ្សំ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _identifyFood(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('កាមេរ៉ា'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _identifyFood(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('វិចិត្រសាល'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _isProcessing 
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          _foodNameDisplay,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3F7A5F)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F7A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // Return the Khmer search term to the previous screen
                Navigator.pop(context, _foodNameDisplay);
              },
              child: const Text('ស្វែងរកជាមួយគ្រឿងផ្សំទាំងនេះ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
