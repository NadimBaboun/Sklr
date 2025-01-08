import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sklr/PrivacyPolicy.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/startpage.dart';
import 'dart:io';
import 'Edit_Profile.dart'; // Import the Edit Profile page
import 'package:sklr/notfication-control.dart';
import 'package:sklr/Choose-languge.dart';
import 'addskillpage.dart';
import 'navigationbar-bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Remove Picture'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _image = null;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    // Outer circle with background color
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Color(0xFFDCEBFF), // Light blue background
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        // Avatar image
                        child: ClipOval(
                          child: _image != null
                              ? Image.file(
                                  _image!,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                )
                              : Image.asset(
                                  'assets/images/avatar.png', // Replace with your default avatar image path
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // User Name and Details
            Text(
              'Mohammad',
              style: GoogleFonts.lexend(
                textStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'youremail@domain.com | +01 234 567 89',
              style: GoogleFonts.lexend(
                textStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Profile Settings
            Expanded(
              child: ListView(
                children: [
                  OptionTile(
                    icon: Icons.add,
                    title: 'Add a skill',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddSkillPage()),
                      );
                    },
                  ),
                  OptionTile(
                    icon: Icons.person_outline,
                    title: 'Edit profile information',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditProfilePage()),
                      );
                    },
                  ),
                  OptionTile(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationSettingsScreen()),
                      );
                    },
                  ),
                  OptionTile(
                      icon: Icons.language,
                      title: 'Language',
                      trailing: const Text('English',
                          style: TextStyle(color: Colors.blue)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LanguageSelectionScreen()),
                        );
                      }),
                  const Divider(height: 20),
                  OptionTile(
                    icon: Icons.lock_outline,
                    title: 'Security',
                  ),
                  OptionTile(
                    icon: Icons.brightness_6_outlined,
                    title: 'Theme',
                    trailing: const Text('Light mode',
                        style: TextStyle(color: Colors.blue)),
                  ),
                  const Divider(height: 20),
                  OptionTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                  ),
                  OptionTile(
                    icon: Icons.mail_outline,
                    title: 'Contact us',
                  ),
                  OptionTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy policy',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PrivacyPolicy()),
                      );
                    },
                  ),
                  OptionTile(
                    icon: Icons.logout_outlined,
                    title: 'Sign Out',
                    onTap: () {
                      showSignOutDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
      currentIndex: 3,
       loggedInUserId: 1),
    );
  }
}

class OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Function? onTap;

  const OptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: trailing,
      onTap: () => onTap?.call(),
    );
  }
}

showSignOutDialog(BuildContext context) {
  Widget button = TextButton(
    child: const Text('Sign Out'),
    onPressed: () async {
      Navigator.of(context, rootNavigator: true).pop();
      await UserIdStorage.setRememberMe(false);
      await UserIdStorage.saveLoggedInUserId(-1);
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const StartPage())
      );
    },
  );

  AlertDialog dialog = AlertDialog(
    title: const Text("Confirm signout?"),
    content: Text("If you sign out, you will no longer have access to Sklr or any of its services."),
    actions: [
      button,
    ],
  );

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return dialog;
    }
  );
}
