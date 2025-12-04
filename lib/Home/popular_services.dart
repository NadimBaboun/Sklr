import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PopularServices extends StatefulWidget {
  const PopularServices({Key? key}) : super(key: key);
  
  @override
  _PopularServicesState createState() => _PopularServicesState();
}

class _PopularServicesState extends State<PopularServices> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    // Implement search functionality
    print('Searching for: $query');
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
                      Color(0xFF2196F3),
                      Color(0xFF1976D2),
                      Color(0xFF0D47A1),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
                    bottomRight: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      blurRadius: isLargeScreen ? 16 : 12,
                      offset: const Offset(0, 6),
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
                                  'Popular Services',
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
                                  Icons.filter_list_rounded,
                                  color: Colors.white,
                                  size: isDesktop ? 24 : isTablet ? 22 : 20,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                          Text(
                            "Discover exceptional talent",
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                          // Search Bar
                          Container(
                            height: isDesktop ? 48 : isTablet ? 44 : 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onSubmitted: _performSearch,
                              style: TextStyle(fontSize: isDesktop ? 15 : isTablet ? 14 : 13),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search popular services...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey[600],
                                  size: isDesktop ? 20 : isTablet ? 18 : 16,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Colors.grey[600],
                                          size: isDesktop ? 18 : isTablet ? 16 : 14,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          Icons.arrow_forward,
                                          color: const Color(0xFF2196F3),
                                          size: isDesktop ? 18 : isTablet ? 16 : 14,
                                        ),
                                        onPressed: () => _performSearch(_searchController.text),
                                      ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: isDesktop ? 12 : isTablet ? 10 : 8,
                                  horizontal: isDesktop ? 16 : isTablet ? 14 : 12,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
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
                          // Stats Section
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    '150+',
                                    'Active Services',
                                    Icons.work_outline,
                                    const Color(0xFF2196F3),
                                    isDesktop,
                                    isTablet,
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 20 : isTablet ? 16 : 12),
                                Expanded(
                                  child: _buildStatCard(
                                    '50+',
                                    'Categories',
                                    Icons.category_outlined,
                                    Colors.green,
                                    isDesktop,
                                    isTablet,
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 20 : isTablet ? 16 : 12),
                                Expanded(
                                  child: _buildStatCard(
                                    '4.8',
                                    'Avg Rating',
                                    Icons.star_outline,
                                    Colors.orange,
                                    isDesktop,
                                    isTablet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
                          
                          // Services Grid
                          Text(
                            'Featured Services',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),
                          
                          // Service Cards Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isDesktop ? 2 : 1,
                              childAspectRatio: isDesktop ? 2.5 : isTablet ? 3.0 : 2.8,
                              mainAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
                              crossAxisSpacing: isDesktop ? 20 : isTablet ? 16 : 12,
                            ),
                            itemCount: 10,
                            itemBuilder: (context, index) {
                              return _buildModernServiceCard(index, isDesktop, isTablet, isLargeScreen);
                            },
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

  Widget _buildStatCard(String value, String label, IconData icon, Color color, bool isDesktop, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: isDesktop ? 28 : isTablet ? 26 : 24,
          ),
          SizedBox(height: isDesktop ? 8 : isTablet ? 6 : 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernServiceCard(int index, bool isDesktop, bool isTablet, bool isLargeScreen) {
    final services = [
      {'name': 'Web Development', 'provider': 'TechCorp Solutions', 'rating': '4.9', 'price': '150', 'icon': Icons.web},
      {'name': 'Mobile App Design', 'provider': 'Creative Studio', 'rating': '4.8', 'price': '120', 'icon': Icons.phone_android},
      {'name': 'Digital Marketing', 'provider': 'Growth Agency', 'rating': '4.7', 'price': '80', 'icon': Icons.trending_up},
      {'name': 'Content Writing', 'provider': 'Word Masters', 'rating': '4.9', 'price': '50', 'icon': Icons.edit},
      {'name': 'Graphic Design', 'provider': 'Visual Arts Co', 'rating': '4.8', 'price': '90', 'icon': Icons.palette},
      {'name': 'SEO Optimization', 'provider': 'Rank Boosters', 'rating': '4.6', 'price': '100', 'icon': Icons.search},
      {'name': 'Video Editing', 'provider': 'Motion Graphics', 'rating': '4.9', 'price': '130', 'icon': Icons.video_camera_back},
      {'name': 'Data Analysis', 'provider': 'Analytics Pro', 'rating': '4.7', 'price': '110', 'icon': Icons.analytics},
      {'name': 'UI/UX Design', 'provider': 'Design Labs', 'rating': '4.8', 'price': '140', 'icon': Icons.design_services},
      {'name': 'Social Media', 'provider': 'Social Experts', 'rating': '4.6', 'price': '70', 'icon': Icons.share},
    ];

    final service = services[index % services.length];

    return InkWell(
      onTap: () {
        // Navigate to service details
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.06),
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
          padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 18 : 16),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 70 : isTablet ? 65 : 60,
                height: isDesktop ? 70 : isTablet ? 65 : 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2196F3).withOpacity(0.1),
                      const Color(0xFF2196F3).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 18 : isTablet ? 16 : 14),
                ),
                child: Icon(
                  service['icon'] as IconData,
                  color: const Color(0xFF2196F3),
                  size: isDesktop ? 32 : isTablet ? 30 : 28,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : isTablet ? 14 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['name'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: isDesktop ? 18 : isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
                    Text(
                      'by ${service['provider']}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 10 : isTablet ? 8 : 6,
                            vertical: isDesktop ? 6 : isTablet ? 5 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(isDesktop ? 12 : isTablet ? 10 : 8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.orange,
                                size: isDesktop ? 14 : isTablet ? 13 : 12,
                              ),
                              SizedBox(width: isDesktop ? 4 : isTablet ? 3 : 2),
                              Text(
                                service['rating'] as String,
                                style: GoogleFonts.poppins(
                                  color: Colors.orange[700],
                                  fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 10 : isTablet ? 8 : 6,
                            vertical: isDesktop ? 6 : isTablet ? 5 : 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.1),
                                Colors.green.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(isDesktop ? 12 : isTablet ? 10 : 8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '\$${service['price']}',
                            style: GoogleFonts.poppins(
                              color: Colors.green[700],
                              fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
