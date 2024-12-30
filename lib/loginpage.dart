import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:sklr/forgot-passowrd.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _keepLogIn = false;
  bool isLoginEnabled = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    // Add listeners to email and password controllers
    _emailController.addListener(_updateLoginButtonState);
    _passwordController.addListener(_updateLoginButtonState);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Method to check if the Login button should be enabled
  void _updateLoginButtonState() {
    setState(() {
      isLoginEnabled = _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _isValidEmail(_emailController.text);
    });
  }

  // Simple email validation
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width to adjust layout based on screen size
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: screenWidth < 600
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 50, vertical: 30), // Responsive padding
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Login',
                    style: GoogleFonts.mulish(
                      fontSize: screenWidth < 600 ? 32 : 40, // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Email Input TextField
                const Text("Email", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "Enter email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    fillColor: const Color.fromARGB(125, 207, 235, 252),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Password Input TextField
                const Text("Password", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible, // Toggle visibility
                  decoration: InputDecoration(
                    hintText: "Enter password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible; // Toggle password visibility
                        });
                      },
                    ),
                    fillColor: const Color.fromARGB(125, 207, 235, 252),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // "Keep me Logged In" button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _keepLogIn,
                          onChanged: (bool? value) {
                            setState(() {
                              _keepLogIn = value ?? false;
                            });
                          },
                          activeColor: Colors.white,
                          checkColor: const Color(0xFF6296FF),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        const Text("Keep Login"),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage()));
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Color(0xFF6296FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoginEnabled
                        ? () {
                            // Add login logic here
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isLoginEnabled ? const Color(0xFF6296FF) : Colors.grey,
                    ),
                    child: Text(
                      "Login",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth < 600 ? 18 : 20), // Responsive font size
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: GoogleFonts.mulish(
                        textStyle: TextStyle(
                          color: Colors.grey[700],
                          fontSize: screenWidth < 600 ? 16 : 18, // Responsive font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Register',
                          style: GoogleFonts.mulish(
                            textStyle: TextStyle(
                              color: const Color(0xFF6296FF),
                              fontSize: screenWidth < 600 ? 16 : 18, // Responsive font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => const Register()));
                            },
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// responsive check done 