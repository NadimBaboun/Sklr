import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sklr/Util/PrivacyPolicy.dart';
import 'package:sklr/Profile/dashboard.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/Util/startpage.dart';
import 'dart:io';
import 'editProfile.dart';
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
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isModerator = false;
  String? _avatarUrl;

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
          _avatarUrl = userData?['avatar_url'];
          isLoading = false;
          isModerator = userData!['moderator'];
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (pickedFile == null) return;

      setState(() => isLoading = true);

      final userId = await UserIdStorage.getLoggedInUserId();
      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.path.split('.').last;
      final fileName =
          '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'profiles/$userId/$fileName';

      await supabase.storage.from('profile-pictures').uploadBinary(
            filePath,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final imageUrl =
          supabase.storage.from('profile-pictures').getPublicUrl(filePath);

      final response = await supabase
          .from('users')
          .update({'avatar_url': imageUrl}).eq('id', userId as Object);

      if (response.error != null) {
        throw Exception(response.error!.message);
      }

      setState(() {
        _avatarUrl = imageUrl;
        userData?['avatar_url'] = imageUrl;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (error) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  _buildCreditsSection(),
                  _buildProfileImage(),
                  const SizedBox(height: 20),
                  _buildUserInfo(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildOptions()),
                ],
              ),
            ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 3),
    );
  }

  Widget _buildCreditsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet,
              color: Color(0xFF6296FF), size: 30),
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
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFFDCEBFF),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: _avatarUrl != null
                ? Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset('assets/images/avatar.png'),
                  )
                : Image.asset('assets/images/avatar.png'),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF6296FF),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          userData?['username'] ?? 'Unknown User',
          style: GoogleFonts.mulish(
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${userData?['email'] ?? 'No Email'} | ${userData?['phone_number'] ?? 'No Phone'}',
          style: GoogleFonts.mulish(
            textStyle: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return ListView(
      children: [
        if (isModerator) ...[
          OptionTile(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Reports',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ModeratorDashboard()),
            ),
          ),
          const Divider(height: 20),
        ],
        OptionTile(
          icon: Icons.person_outline,
          title: 'Edit profile information',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditProfilePage()),
          ),
        ),
        OptionTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PrivacyPolicy()),
          ),
        ),
        OptionTile(
          icon: Icons.logout_outlined,
          title: 'Sign Out',
          onTap: () => _showSignOutDialog(context),
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm sign out?"),
          content: const Text(
              "If you sign out, you will no longer have access to Sklr or any of its services."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await supabase.auth.signOut();
                await UserIdStorage.setRememberMe(false);
                await UserIdStorage.saveLoggedInUserId(-1);
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const StartPage()));
                }
              },
              child: const Text('Sign Out',
                  style: TextStyle(color: Color(0xFF6296FF))),
            ),
          ],
        );
      },
    );
  }
}

class OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const OptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
