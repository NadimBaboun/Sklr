import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;
  double _scrollProgress = 0.0;

  final List<Map<String, dynamic>> _sections = [
    {
      'title': 'Types of Data We Collect',
      'icon': Icons.data_usage_outlined,
      'color': const Color(0xFF2196F3),
      'content': 'SKLR collects essential information to create and manage your account. This includes your username, email address, and phone number. Additionally, we store data about your in-app activities, such as coin transactions and rewards earned. This helps us enhance your experience and ensure the proper functioning of app features.',
    },
    {
      'title': 'Use of Your Personal Data',
      'icon': Icons.person_outline,
      'color': const Color(0xFF4CAF50),
      'content': 'The information you provide is used to personalize your experience on SKLR. For example, your data enables us to manage your account, show your profile to others when needed, and track in-app coin usage. We also analyze this information to improve the app and introduce features that match user preferences. Your personal data is never shared with third parties for marketing purposes.',
    },
    {
      'title': 'Disclosure of Your Personal Data',
      'icon': Icons.security_outlined,
      'color': const Color(0xFFFF9800),
      'content': 'We prioritize your privacy and do not share your personal data with third parties unless required by law. In certain situations, such as to comply with legal obligations or to prevent misuse of the platform, we may disclose limited data. SKLR ensures that any data shared follows strict security protocols to protect your information.',
    },
    {
      'title': 'Data Security & Protection',
      'icon': Icons.shield_outlined,
      'color': const Color(0xFF9C27B0),
      'content': 'We implement industry-standard security measures to protect your personal information. This includes encryption of sensitive data, secure server infrastructure, and regular security audits. Your data is stored in secure databases with restricted access and backup systems to ensure data integrity.',
    },
    {
      'title': 'Your Rights & Control',
      'icon': Icons.settings_outlined,
      'color': const Color(0xFFE91E63),
      'content': 'You have the right to access, update, or delete your personal information at any time. You can modify your profile settings, review your data usage, and request data deletion through the app settings. We respect your privacy choices and provide transparent controls over your information.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollProgress = _scrollController.offset / _scrollController.position.maxScrollExtent;
        });
      });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isLargeScreen = size.width > 600;
        final isTablet = size.width > 768;
        final isDesktop = size.width > 1024;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Modern Header Section
              Container(
                height: size.height * (isDesktop ? 0.20 : isTablet ? 0.18 : 0.22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6296FF),
                      Color(0xFF4A7BFF),
                      Color(0xFF3461FF),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
                    bottomRight: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6296FF).withOpacity(0.3),
                      blurRadius: isLargeScreen ? 20 : 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32.0 : isTablet ? 28.0 : 20.0,
                      vertical: isDesktop ? 20.0 : isTablet ? 18.0 : 16.0,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isDesktop ? 12 : isTablet ? 10 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: Colors.white,
                                    size: isDesktop ? 24 : isTablet ? 22 : 20,
                                  ),
                                ),
                              ),
                              SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
                              Expanded(
                                child: Text(
                                  'Privacy & Policy',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(isDesktop ? 12 : isTablet ? 10 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.privacy_tip_outlined,
                                  color: Colors.white,
                                  size: isDesktop ? 24 : isTablet ? 22 : 20,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                          Text(
                            "Your privacy is our priority",
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
                          // Progress indicator
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _scrollProgress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Content Section
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32.0 : isTablet ? 28.0 : 20.0,
                      vertical: isDesktop ? 24.0 : isTablet ? 20.0 : 16.0,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Introduction Card
                          Container(
                            padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.grey[50]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.06),
                                  spreadRadius: 1,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(isDesktop ? 12 : isTablet ? 10 : 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF6296FF), Color(0xFF4A7BFF)],
                                        ),
                                        borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                        size: isDesktop ? 24 : isTablet ? 22 : 20,
                                      ),
                                    ),
                                    SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
                                    Expanded(
                                      child: Text(
                                        'About This Policy',
                                        style: GoogleFonts.poppins(
                                          fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2D3142),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                                Text(
                                  'This Privacy Policy explains how SKLR collects, uses, and protects your personal information. We are committed to maintaining the highest standards of privacy and data security.',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                                    color: const Color(0xFF6B7280),
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 12 : isTablet ? 10 : 8,
                                    vertical: isDesktop ? 8 : isTablet ? 6 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6296FF).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(isDesktop ? 12 : isTablet ? 10 : 8),
                                    border: Border.all(
                                      color: const Color(0xFF6296FF).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Last updated: June 11, 2025',
                                    style: GoogleFonts.poppins(
                                      fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                                      color: const Color(0xFF6296FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
                          
                          // Policy Sections
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _sections.length,
                            separatorBuilder: (context, index) => SizedBox(
                              height: isDesktop ? 20 : isTablet ? 16 : 12,
                            ),
                            itemBuilder: (context, index) {
                              return _buildPolicySection(
                                _sections[index],
                                index + 1,
                                isDesktop,
                                isTablet,
                              );
                            },
                          ),
                          
                          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
                          
                          // Contact Information
                          Container(
                            padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF6296FF).withOpacity(0.05),
                                  const Color(0xFF6296FF).withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                              border: Border.all(
                                color: const Color(0xFF6296FF).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.contact_support_outlined,
                                      color: const Color(0xFF6296FF),
                                      size: isDesktop ? 24 : isTablet ? 22 : 20,
                                    ),
                                    SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
                                    Text(
                                      'Need Help?',
                                      style: GoogleFonts.poppins(
                                        fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6296FF),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
                                Text(
                                  'If you have any questions about this Privacy Policy or how we handle your data, please contact our support team.',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                                    color: const Color(0xFF6B7280),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicySection(Map<String, dynamic> section, int index, bool isDesktop, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
        boxShadow: [
          BoxShadow(
            color: (section['color'] as Color).withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 12 : isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (section['color'] as Color).withOpacity(0.15),
                        (section['color'] as Color).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                    border: Border.all(
                      color: (section['color'] as Color).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    section['icon'] as IconData,
                    color: section['color'] as Color,
                    size: isDesktop ? 24 : isTablet ? 22 : 20,
                  ),
                ),
                SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 8 : isTablet ? 6 : 4,
                          vertical: isDesktop ? 4 : isTablet ? 3 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: (section['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isDesktop ? 8 : isTablet ? 6 : 4),
                        ),
                        child: Text(
                          '$index',
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                            color: section['color'] as Color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
                      Text(
                        section['title'],
                        style: GoogleFonts.poppins(
                          fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2D3142),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.1),
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
            Text(
              section['content'],
              style: GoogleFonts.poppins(
                fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                color: const Color(0xFF6B7280),
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
