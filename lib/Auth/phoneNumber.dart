import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:sklr/Home/home.dart';
import 'package:sklr/Auth/phoneVerify.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class Country {
  final String code;
  final String name;
  final String prefix;

  Country({required this.code, required this.name, required this.prefix});
}

class PhoneNumberPage extends StatefulWidget {
  final int? userId;
  final bool isRegistration;

  const PhoneNumberPage({
    super.key,
    this.userId,
    this.isRegistration = false,
  });

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  String phoneNumber = '';
  String completePhoneNumber = '';
  bool isValid = false;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Phone Verification',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Illustration
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/skillerlogo.png',
                  height: isLargeScreen ? 240 : 180,
                ),
              ),
              const SizedBox(height: 32),
              // Heading
              Text(
                'Phone Verification',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'We\'ll send you a verification code to confirm your phone number',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              // Phone Input
              IntlPhoneField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: GoogleFonts.poppins(
                    color: Colors.grey[700],
                  ),
                  hintText: 'Enter your phone number',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
                initialCountryCode: 'GB',
                onChanged: (phone) {
                  setState(() {
                    phoneNumber = phone.number;
                    completePhoneNumber = phone.completeNumber;
                    isValid = phone.number.length >= 10;
                  });
                },
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                dropdownTextStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                dropdownIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black87,
                ),
                flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 16),
                showDropdownIcon: true,
                dropdownIconPosition: IconPosition.trailing,
              ),
              const SizedBox(height: 40),
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isValid && !isLoading
                      ? () async {
                          setState(() {
                            isLoading = true;
                          });
                          // Navigation delay to show loading state
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            setState(() {
                              isLoading = false;
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PhoneVerifyPage(
                                  phoneNumber: completePhoneNumber,
                                  userId: widget.userId,
                                  isRegistration: widget.isRegistration,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // Skip button (only for optional phone verification)
              if (!widget.isRegistration)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
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

class PhoneAppbar extends StatelessWidget implements PreferredSizeWidget {
  const PhoneAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      centerTitle: false,
      leadingWidth: 25,
      automaticallyImplyLeading: false,
      title: Builder(
        builder: (context) {
          return InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                Icon(Icons.keyboard_arrow_left_sharp),
                Text(
                  'Back',
                  style: GoogleFonts.mulish(
                    textStyle: TextStyle(
                      color: Color(0xff053742),
                      fontSize: 14,
                      fontWeight: FontWeight.w600
                    )
                  )
                )
              ]
            ) 
          );
        }
      )
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class FadedCircle extends StatelessWidget {
  final double right;
  final double top;
  final double width;
  final double height;

  const FadedCircle({super.key, required this.right, required this.top, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color(0xff3CCEFF).withAlpha((0.6 * 255).toInt()),
              Color(0xff3CCEFF).withAlpha((0.1 * 255).toInt()),
            ],
            stops: [
              0.0,
              1.0
            ]
          )
        ),
      )
    );
  }
}

class TitleAndHeader extends StatelessWidget {
  const TitleAndHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Phone Number',
          textAlign: TextAlign.center,
          style: GoogleFonts.mulish(
            textStyle: TextStyle(
              color: Color(0xff053742),
              fontSize: 32,
              fontWeight: FontWeight.w600
            )
          ),
        ),
        Text(
          'Please enter your phone number to verify your account & receive a credit',
          textAlign: TextAlign.center,
          style: GoogleFonts.mulish(
            textStyle: TextStyle(
              color: Color(0xff88879C),
              fontSize: 16
            )
          )
        )
      ]
    );
  }
}

class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(' ', '');

    StringBuffer buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buf.write(' ');
      }
      buf.write(text[i]);
    }

    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.toString().length),
    );
  }
}
//phone number page done 