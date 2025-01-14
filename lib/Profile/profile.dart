import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sklr/Util/PrivacyPolicy.dart';
import 'package:sklr/Profile/dashboard.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/Util/startpage.dart';
import 'dart:io';
import '../Edit_Profile.dart'; 
import '../Util/navigationbar-bar.dart';
import '../database/database.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isModerator = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = await UserIdStorage.getLoggedInUserId();

    if (userId != null && userId > 0) {
      final response = await DatabaseHelper.fetchUserFromId(userId);
      if (response.success) {
        setState(() {
          userData = response.data;
          isLoading = false;
          isModerator = userData!['moderator'];
        });
      } else {
        setState(() {
          isLoading = true;
        });
      }
    }
  }
  //Didnt have time to implement storing images into database
/*
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
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: const Color(0xFF6296FF),
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${userData?['credits'] ?? 0}",
                    style: GoogleFonts.lexend(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6296FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Avatar Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Color(0xFFDCEBFF), 
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
                                  'assets/images/avatar.png',
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                      ),
                    ),/*
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6296FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),*/
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // User Name and Details
            Text(
              userData?['username'] ?? 'Unknown User',
              style: GoogleFonts.mulish(
                textStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${userData?['email'] ?? 'No Email'} | ${userData?['phone_number'] ?? 'No Phone'}',
              style: GoogleFonts.mulish(
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
                  isModerator
                      ? OptionTile(
                          icon: Icons.report_gmailerrorred_outlined,
                          title: 'Reports',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ModeratorDashboard()),
                            );
                          })
                      : SizedBox.shrink(),
                  const Divider(height: 20),
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
      ),
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
    child: const Text('Sign Out', style: TextStyle(color: Color(0xFF6296FF))),
    onPressed: () async {
      Navigator.of(context, rootNavigator: true).pop();
      await UserIdStorage.setRememberMe(false);
      await UserIdStorage.saveLoggedInUserId(-1);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const StartPage()));
    },
  );

  AlertDialog dialog = AlertDialog(
    title: const Text("Confirm signout?"),
    content: Text(
        "If you sign out, you will no longer have access to Sklr or any of its services."),
    actions: [
      button,
    ],
  );

  showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return dialog;
      });
}
