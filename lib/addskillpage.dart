import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';

class AddSkillPage extends StatefulWidget {
  const AddSkillPage({super.key});
  @override
  AddSkillPageState createState() => AddSkillPageState();
}

class AddSkillPageState extends State<AddSkillPage> {
  String skillname = '';
  String skilldescription = '';
  int? loggedInUserId;
  String? chosenCategory;
  String? errorMessage;

  final List<String> _choices = [
    'Cooking & Baking',
    'Fitness',
    'IT & Tech',
    'Languages',
    'Music & Audio',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await UserIdStorage.getLoggedInUserId();
    setState(() {
      loggedInUserId = userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            "Add a skill to share with someone!",
            style: GoogleFonts.mulish(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF6296FF),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) {
                  setState(() {
                    skillname = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Enter title for skill",
                  prefixIcon: const Icon(Icons.title),
                  fillColor: const Color.fromARGB(125, 207, 235, 252),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              TextField(
                onChanged: (value) {
                  setState(() {
                    skilldescription = value;
                  });
                },
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Enter skill description",
                  prefixIcon: const Icon(Icons.description),
                  fillColor: const Color.fromARGB(125, 207, 235, 252),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      value: chosenCategory,
                      hint: Text('Choose a category'),
                      icon: Icon(
                        Icons.arrow_downward,
                        color: const Color(0xFF6296FF),
                      ),
                      elevation: 16,
                      underline: Container(
                        height: 2,
                        width: double.infinity,
                        color: Color(0xFF6296FF),
                      ),
                      items: _choices.map((String choice) {
                        return DropdownMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          chosenCategory = newValue;
                        });
                      },
                      isExpanded: false,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (errorMessage != null) ...[
                Center(
                  
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    errorMessage = null;
                  });
                  //check if all fields contain info
                  if (skillname.isNotEmpty &&
                      skilldescription.isNotEmpty &&
                      chosenCategory!.isNotEmpty) {
                    bool skillExists = await DatabaseHelper.checkSkillName(
                        skillname, loggedInUserId);
                    //check if skillname already exist for logged in user
                    if (!skillExists) {
                      //skill is added to the database
                      DatabaseHelper.insertSkill(loggedInUserId, skillname,
                          skilldescription, chosenCategory);
                      Navigator.of(context).pop();
                    } else {
                      setState(() {
                        errorMessage = 'This skill already exists!';
                      });
                    }
                  }
                  else {
                    setState(() {
                        errorMessage = 'Please fill all neccessary information';
                      });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6296FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Create",
                  style: GoogleFonts.mulish(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.mulish(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
