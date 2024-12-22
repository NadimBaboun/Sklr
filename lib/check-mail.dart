import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class CheckMailPage extends StatefulWidget{
  const CheckMailPage({super.key});

  @override
  _CheckMailStatePage createState() => _CheckMailStatePage();
}

class _CheckMailStatePage extends State<CheckMailPage>{

@override
Widget build(BuildContext context){
  return Scaffold(
    backgroundColor: Colors.white,
    body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/checkmail.png', 
                height: 450,
                width: 450,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                "We have sent password recovery instructions to your email.",
                style: GoogleFonts.mulish(
                  textStyle: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6296FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                ),
                child: const Text(
                  "Finish",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}