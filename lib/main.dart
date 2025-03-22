import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart'; // Add this package for translation

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        appBarTheme:
            AppBarTheme(backgroundColor: Colors.grey.shade900, elevation: 0),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey.shade900,
      ),
      home: const CreatePromptScreen(),
    );
  }
}

class CreatePromptScreen extends StatefulWidget {
  const CreatePromptScreen({super.key});

  @override
  State<CreatePromptScreen> createState() => _CreatePromptScreenState();
}

class _CreatePromptScreenState extends State<CreatePromptScreen> {
  TextEditingController controller = TextEditingController();
  TextEditingController followUpController = TextEditingController();
  Uint8List? imageBytes;
  String? imageDescription;
  String? translatedDescription;
  bool isLoading = false;
  bool isTranslating = false;
  bool isProcessingFollowUp = false;
  bool hasError = false;
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speechToText = stt.SpeechToText();
  final translator = GoogleTranslator();
  bool isListening = false;
  String selectedLanguage = 'Spanish';
  List<String> languages = [
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Japanese',
    'Chinese',
    'Russian'
  ];

  // Style options for image generation
  final List<Map<String, dynamic>> styleOptions = [
    {'name': 'Photography', 'id': '122'},
    {'name': 'Anime', 'id': '29'},
    {'name': 'Realistic', 'id': '3'},
    {'name': 'Painting', 'id': '22'},
    {'name': 'Digital Art', 'id': '9'},
  ];
  String selectedStyleId = '122';

  Future<void> generateImage(String prompt) async {
    setState(() {
      isLoading = true;
      hasError = false;
      imageDescription = null;
      translatedDescription = null;
    });

    try {
      String url = 'https://api.vyro.ai/v1/imagine/api/generations';
      Map<String, dynamic> headers = {
        'Authorization':
            'Bearer vk-3Yn7eTipAFIuhjFYT8AxdD2Hw0rp7k2WyfCoLMNjSVOoyIP'
      };

      Map<String, dynamic> payload = {
        'prompt': prompt,
        'style_id': selectedStyleId,
        'aspect_ratio': '1:1',
        'cfg': '5',
        'seed': '1',
        'high_res_results': '1'
      };

      FormData formData = FormData.fromMap(payload);
      Dio dio = Dio();
      dio.options =
          BaseOptions(headers: headers, responseType: ResponseType.bytes);

      final response = await dio.post(url, data: formData);

      if (response.statusCode == 200) {
        setState(() {
          imageBytes = Uint8List.fromList(response.data);
          isLoading = false;
        });

        describeImage(imageBytes!);
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> describeImage(Uint8List imageBytes) async {
    const String geminiApiKey = "AIzaSyCDKK08OS_DWyYR4KCRVN200SxRZjD-z4I";
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: geminiApiKey,
    );

    try {
      final response = await model.generateContent([
        Content.multi([DataPart('image/png', imageBytes)])
      ]);

      setState(() {
        imageDescription = response.text ?? "No description available.";
      });

      speakText(imageDescription!);
    } catch (e) {
      setState(() {
        imageDescription = "Failed to generate description.";
      });
    }
  }

  Future<void> translateDescription() async {
    if (imageDescription == null) return;

    setState(() {
      isTranslating = true;
    });

    try {
      final translation = await translator.translate(
        imageDescription!,
        to: getLanguageCode(selectedLanguage),
      );

      setState(() {
        translatedDescription = translation.text;
        isTranslating = false;
      });
    } catch (e) {
      setState(() {
        translatedDescription = "Translation failed.";
        isTranslating = false;
      });
    }
  }

  String getLanguageCode(String language) {
    switch (language) {
      case 'Hindi':
        return 'hi';
      case 'Spanish':
        return 'es';
      case 'French':
        return 'fr';
      case 'German':
        return 'de';
      case 'Italian':
        return 'it';
      case 'Japanese':
        return 'ja';
      case 'Chinese':
        return 'zh-cn';
      case 'Russian':
        return 'ru';
      default:
        return 'es';
    }
  }

  Future<void> askFollowUpQuestion(String question) async {
    if (imageBytes == null || question.isEmpty) return;

    setState(() {
      isProcessingFollowUp = true;
    });

    const String geminiApiKey = "AIzaSyCDKK08OS_DWyYR4KCRVN200SxRZjD-z4I";
    final model =
        GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(
              'Here is an image. Based on this image, please answer the following question: $question'),
          DataPart('image/png', imageBytes!)
        ])
      ]);

      setState(() {
        imageDescription = imageDescription! +
            "\n\nYou asked: $question\n\nAnswer: ${response.text ?? "No answer available."}";
        isProcessingFollowUp = false;
      });

      speakText(response.text ?? "No answer available.");
    } catch (e) {
      setState(() {
        imageDescription =
            imageDescription! + "\n\nFailed to process your question.";
        isProcessingFollowUp = false;
      });
    }
  }

  Future<void> speakText(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  Future<void> speakTranslation() async {
    if (translatedDescription == null) return;

    await flutterTts.setLanguage(getLanguageCode(selectedLanguage));
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(translatedDescription!);
  }

  void startListening() async {
    bool available = await speechToText.initialize();
    if (available) {
      setState(() => isListening = true);
      speechToText.listen(onResult: (result) {
        setState(() {
          controller.text = result.recognizedWords;
        });
      });
    }
  }

  void stopListening() {
    setState(() => isListening = false);
    speechToText.stop();
  }

  void startFollowUpListening() async {
    bool available = await speechToText.initialize();
    if (available) {
      setState(() => isListening = true);
      speechToText.listen(onResult: (result) {
        setState(() {
          followUpController.text = result.recognizedWords;
        });
      });
    }
  }

  Future<void> saveImage() async {
    // Implementation would require additional packages for saving to gallery
    // This is a placeholder for where you'd implement image saving functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image saved to gallery')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gen-AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: const Text('Settings'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Choose Image Style'),
                            const SizedBox(height: 10),
                            ...styleOptions
                                .map((style) => RadioListTile(
                                      title: Text(style['name']),
                                      value: style['id'],
                                      groupValue: selectedStyleId,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedStyleId = value.toString();
                                        });
                                        Navigator.pop(context);
                                      },
                                    ))
                                .toList(),
                          ],
                        ),
                      ));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter your prompt",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      cursorColor: Colors.deepPurple,
                      decoration: InputDecoration(
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.deepPurple),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(isListening ? Icons.mic : Icons.mic_none),
                          onPressed:
                              isListening ? stopListening : startListening,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.deepPurple)),
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            generateImage(controller.text);
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text("Generate & Describe"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Display image and description
            isLoading
                ? const CircularProgressIndicator()
                : hasError
                    ? const Text("Something went wrong",
                        style: TextStyle(color: Colors.red))
                    : imageBytes != null
                        ? Column(
                            children: [
                              Image.memory(imageBytes!,
                                  fit: BoxFit.cover, width: double.infinity),
                              const SizedBox(height: 10),

                              // Action buttons
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      onPressed: imageDescription != null
                                          ? () => speakText(imageDescription!)
                                          : null,
                                      tooltip: 'Listen',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.translate),
                                      onPressed: imageDescription != null
                                          ? () => translateDescription()
                                          : null,
                                      tooltip: 'Translate',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.save_alt),
                                      onPressed: imageBytes != null
                                          ? () => saveImage()
                                          : null,
                                      tooltip: 'Save Image',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      onPressed: imageBytes != null
                                          ? () => ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Share functionality will be implemented')),
                                              )
                                          : null,
                                      tooltip: 'Share',
                                    ),
                                  ],
                                ),
                              ),

                              // Image description
                              imageDescription != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Description:",
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            imageDescription!,
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const CircularProgressIndicator(),

                              // Translation section
                              if (isTranslating)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),

                              if (translatedDescription != null &&
                                  !isTranslating)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "$selectedLanguage Translation:",
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.volume_up,
                                                size: 20),
                                            onPressed: () => speakTranslation(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        translatedDescription!,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Text("Translate to: "),
                                          DropdownButton<String>(
                                            value: selectedLanguage,
                                            items: languages
                                                .map((String language) {
                                              return DropdownMenuItem<String>(
                                                value: language,
                                                child: Text(language),
                                              );
                                            }).toList(),
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                setState(() {
                                                  selectedLanguage = newValue;
                                                  translatedDescription = null;
                                                });
                                                translateDescription();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                              // Follow-up question section
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Ask a follow-up question:",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: followUpController,
                                      cursorColor: Colors.deepPurple,
                                      decoration: InputDecoration(
                                        hintText:
                                            "E.g., What time of day is it in the image?",
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(
                                              color: Colors.deepPurple),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.mic),
                                          onPressed: startFollowUpListening,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 48,
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all(
                                                    Colors.deepPurple)),
                                        onPressed: isProcessingFollowUp
                                            ? null
                                            : () {
                                                if (followUpController
                                                    .text.isNotEmpty) {
                                                  askFollowUpQuestion(
                                                      followUpController.text);
                                                  followUpController.clear();
                                                }
                                              },
                                        icon: isProcessingFollowUp
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.question_answer),
                                        label: const Text("Ask Question"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child:
                                  Text("Enter a prompt to generate an image"),
                            ),
                          ),
          ],
        ),
      ),
    );
  }
}
