import 'package:flutter/material.dart';

void chose_language() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LanguageSelectionScreen(),
    );
  }
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  _LanguageSelectionScreenState createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String selectedLanguage = "English (UK)";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Language",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Suggested Section
          const Text(
            "Suggested",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          RadioListTile<String>(
            title: const Text("English (US)"),
            value: "English (US)",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("English (UK)"),
            value: "English (UK)",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          const Divider(thickness: 1, color: Colors.grey),

          // Others Section
          const Text(
            "Others",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          RadioListTile<String>(
            title: const Text("Mandarin"),
            value: "Mandarin",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("Hindi"),
            value: "Hindi",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("Spanish"),
            value: "Spanish",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("French"),
            value: "French",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("Arabic"),
            value: "Arabic",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("Russian"),
            value: "Russian",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("Indonesia"),
            value: "Indonesia",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text("Vietnamese"),
            value: "Vietnamese",
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          ),
        ],
      ),
    );
  }
}
