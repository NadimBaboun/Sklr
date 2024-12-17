import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';


class LoginPage extends StatefulWidget{
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _keepLogIn = false;

  @override
  Widget build (BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: const Color(0xFF6296FF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Text('Login',
                  style: GoogleFonts.mulish(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87, 
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                //Email InputTextfield
                const Text("Email", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "Enter email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                //Password InputTextfield
                const Text("Password", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Enter password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: const Icon(Icons.visibility_off),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                //"Keep me Logged In" button
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
                        ),
                        const Text("Keep me logged in"),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        // Add Logic to Forgot Password
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
                //Login Button ( Add logic to log in later)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      //Add Logic here
                    }, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6296FF),
                    ),
                    child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: InkWell(
                    onTap: (){
                      //Direct user to signup page later
                    },
                    child: const Text(
                      "Don't have an account? Register",
                      style: TextStyle(
                        color: Color(0xFF6296FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )
                    )
                  )
                )
              ],
            ),
            )
        ),
      ),
    );
  }
}