import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/Home/home.dart';
import 'package:sklr/Auth/phoneNumber.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../database/models.dart';

class PhoneVerifyPage extends StatefulWidget {
  final String phoneNumber;
  final int? userId;
  final bool isRegistration;

  const PhoneVerifyPage({
    super.key, 
    required this.phoneNumber,
    this.userId,
    this.isRegistration = false,
  });

  @override
  State<StatefulWidget> createState() => PhoneVerifyPageState();
}
//phone verify page done  
class PhoneVerifyPageState extends State<PhoneVerifyPage> {
  String? otp;
  bool otpFilled = false;
  final TextEditingController otpController = TextEditingController();
  int remaining = 60; // 1 minute to enter otp?
  Timer? timer;
  bool enableResend = false;

  @override
  void initState() {
    super.initState();

    startTimer();
  }

  void onOTPChanged(String value) {
    otp = value;
    setState(() {
      otpFilled = value.length == 4;
    });
  }

  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remaining > 0) {
        setState((){
          remaining--;
        });
      } else {
        setState(() {
          enableResend = true;
        });
        timer.cancel();
      }
    });
  }

  void resendOTP() {
    // logic for sending OTP goes here
    setState(() {
      remaining = 60;
      enableResend = false;
    });
    startTimer();
  }

  void verifyOTP() async {
    if (otpFilled) {
      // verification of OTP goes here
      if (otp == '1234') { // local testing, no verification
        final int? userId = await UserIdStorage.getLoggedInUserId();

        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Failed to fetch valid session'))
          );
          return;
        }

        // make patch request to backend
        DatabaseResponse result = await DatabaseHelper.patchUser(userId, {
          'phone_number': '+${widget.phoneNumber}'
        } as Map<String, dynamic>);

        if (result.success) {
          // award 1 currency for verifying  phone number
          final bool awarded = await DatabaseHelper.awardUser(userId);

          if (awarded) {
            Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => HomePage()), 
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('You already have a verified phone number!'))
            );
          }
        }
        else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.data['error']))
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Please enter a valid code'))
        );
      }
    } 
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        automaticallyImplyLeading: false, // Ensures no back button
        toolbarHeight: 0, // Minimizes the app bar
      ),
      resizeToAvoidBottomInset: true, // Handle keyboard properly
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/illustration-smartphone.png',
                  height: 160,
                  width: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Verify Your Phone',
                  style: GoogleFonts.mulish(
                    color: const Color(0xff053742),
                    fontSize: 24,
                    fontWeight: FontWeight.w600
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Please enter the 4 digit code sent to\n',
                        style: GoogleFonts.mulish(
                          textStyle: const TextStyle(
                            color: Color(0xff88879C),
                            fontSize: 14,
                          )
                        ),
                      ),
                      TextSpan(
                        text: '+${widget.phoneNumber}',
                        style: GoogleFonts.mulish(
                          textStyle: const TextStyle(
                            color: Color(0xff3204FF),
                            fontSize: 14
                          )
                        )
                      ),
                    ],
                  )
                ),
                const SizedBox(height: 20),
                PinCodeTextField(
                  appContext: context,
                  length: 4,
                  controller: otpController,
                  onChanged: onOTPChanged,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.underline,
                    fieldHeight: 50,
                    fieldWidth: 50,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey,
                    selectedColor: Colors.black,
                  ),
                  enableActiveFill: false,
                ),
                const SizedBox(height: 12),
                Text(
                  formatTime(remaining),
                  style: GoogleFonts.mulish(
                    textStyle: const TextStyle(
                      color: Color(0xff88879C),
                      fontSize: 14,
                    )
                  )
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Didn\'t receive the code? ',
                        style: GoogleFonts.mulish(
                          textStyle: const TextStyle(
                            color: Color(0xff88879C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ),
                      TextSpan(
                        text: 'Resend',
                        style: GoogleFonts.mulish(
                          textStyle: TextStyle(
                            color: enableResend ? const Color(0xff3204FF) : const Color(0xff88879C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            if (enableResend) {
                              resendOTP();
                            }
                          },
                      )
                    ]
                  )
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // otp is filled & active "session" is ongoing
                      if (otpFilled && !enableResend) {
                        verifyOTP();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: otpFilled && !enableResend ? const Color(0xff3204FF) : Colors.grey[350],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)
                      )
                    ),
                    child: Text(
                      'Verify',
                      style: GoogleFonts.mulish(
                        textStyle: TextStyle(
                          color: otpFilled && !enableResend ? Colors.white : const Color(0xff88879C),
                          fontSize: 16,
                          fontWeight: FontWeight.w600
                        )
                      )
                    )
                  )
                ),
                const SizedBox(height: 16),
                // Skip button for verification - always show for registration
                if (widget.isRegistration)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: () async {
                        // Ensure the user keeps their initial 50 credits even when skipping
                        if (widget.userId != null) {
                          // No need to award additional credits, they already got 50 on registration
                          // Just navigate to home
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (context) => HomePage()),
                          );
                        } else {
                          // Fallback if user ID is missing
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session error. Please try again.'))
                          );
                        }
                      },
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.mulish(
                          textStyle: const TextStyle(
                            color: Color(0xff88879C),
                            fontSize: 15,
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16), // Extra space at bottom for keyboard
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatTime(int seconds) {
  int minutes = seconds ~/ 60;
  int remaining = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}