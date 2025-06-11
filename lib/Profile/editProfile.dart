import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  String? _selectedCountryCode = '+1'; // Default to US
  String? _selectedCountryFlag = '🇺🇸'; // Default US flag emoji
  
  // Common country codes with flag emojis
  final Map<String, String> _countryCodes = {
    '🇦🇫 Afghanistan': '+93',
    '🇦🇱 Albania': '+355',
    '🇩🇿 Algeria': '+213',
    '🇦🇩 Andorra': '+376',
    '🇦🇴 Angola': '+244',
    '🇦🇬 Antigua and Barbuda': '+1268',
    '🇦🇷 Argentina': '+54',
    '🇦🇲 Armenia': '+374',
    '🇦🇺 Australia': '+61',
    '🇦🇹 Austria': '+43',
    '🇦🇿 Azerbaijan': '+994',
    '🇧🇸 Bahamas': '+1242',
    '🇧🇭 Bahrain': '+973',
    '🇧🇩 Bangladesh': '+880',
    '🇧🇧 Barbados': '+1246',
    '🇧🇾 Belarus': '+375',
    '🇧🇪 Belgium': '+32',
    '🇧🇿 Belize': '+501',
    '🇧🇯 Benin': '+229',
    '🇧🇹 Bhutan': '+975',
    '🇧🇴 Bolivia': '+591',
    '🇧🇦 Bosnia and Herzegovina': '+387',
    '🇧🇼 Botswana': '+267',
    '🇧🇷 Brazil': '+55',
    '🇧🇳 Brunei': '+673',
    '🇧🇬 Bulgaria': '+359',
    '🇧🇫 Burkina Faso': '+226',
    '🇧🇮 Burundi': '+257',
    '🇰🇭 Cambodia': '+855',
    '🇨🇲 Cameroon': '+237',
    '🇨🇦 Canada': '+1',
    '🇨🇻 Cape Verde': '+238',
    '🇨🇫 Central African Republic': '+236',
    '🇹🇩 Chad': '+235',
    '🇨🇱 Chile': '+56',
    '🇨🇳 China': '+86',
    '🇨🇴 Colombia': '+57',
    '🇰🇲 Comoros': '+269',
    '🇨🇬 Congo': '+242',
    '🇨🇩 Congo (DRC)': '+243',
    '🇨🇰 Cook Islands': '+682',
    '🇨🇷 Costa Rica': '+506',
    '🇨🇮 Côte d\'Ivoire': '+225',
    '🇭🇷 Croatia': '+385',
    '🇨🇺 Cuba': '+53',
    '🇨🇾 Cyprus': '+357',
    '🇨🇿 Czech Republic': '+420',
    '🇩🇰 Denmark': '+45',
    '🇩🇯 Djibouti': '+253',
    '🇩🇲 Dominica': '+1767',
    '🇩🇴 Dominican Republic': '+1809',
    '🇪🇨 Ecuador': '+593',
    '🇪🇬 Egypt': '+20',
    '🇸🇻 El Salvador': '+503',
    '🇬🇶 Equatorial Guinea': '+240',
    '🇪🇷 Eritrea': '+291',
    '🇪🇪 Estonia': '+372',
    '🇸🇿 Eswatini': '+268',
    '🇪🇹 Ethiopia': '+251',
    '🇫🇯 Fiji': '+679',
    '🇫🇮 Finland': '+358',
    '🇫🇷 France': '+33',
    '🇬🇦 Gabon': '+241',
    '🇬🇲 Gambia': '+220',
    '🇬🇪 Georgia': '+995',
    '🇩🇪 Germany': '+49',
    '🇬🇭 Ghana': '+233',
    '🇬🇷 Greece': '+30',
    '🇬🇩 Grenada': '+1473',
    '🇬🇹 Guatemala': '+502',
    '🇬🇳 Guinea': '+224',
    '🇬🇼 Guinea-Bissau': '+245',
    '🇬🇾 Guyana': '+592',
    '🇭🇹 Haiti': '+509',
    '🇭🇳 Honduras': '+504',
    '🇭🇰 Hong Kong': '+852',
    '🇭🇺 Hungary': '+36',
    '🇮🇸 Iceland': '+354',
    '🇮🇳 India': '+91',
    '🇮🇩 Indonesia': '+62',
    '🇮🇷 Iran': '+98',
    '🇮🇶 Iraq': '+964',
    '🇮🇪 Ireland': '+353',
    '🇮🇱 Israel': '+972',
    '🇮🇹 Italy': '+39',
    '🇯🇲 Jamaica': '+1876',
    '🇯🇵 Japan': '+81',
    '🇯🇴 Jordan': '+962',
    '🇰🇿 Kazakhstan': '+7',
    '🇰🇪 Kenya': '+254',
    '🇰🇮 Kiribati': '+686',
    '🇰🇵 North Korea': '+850',
    '🇰🇷 South Korea': '+82',
    '🇰🇼 Kuwait': '+965',
    '🇰🇬 Kyrgyzstan': '+996',
    '🇱🇦 Laos': '+856',
    '🇱🇻 Latvia': '+371',
    '🇱🇧 Lebanon': '+961',
    '🇱🇸 Lesotho': '+266',
    '🇱🇷 Liberia': '+231',
    '🇱🇾 Libya': '+218',
    '🇱🇮 Liechtenstein': '+423',
    '🇱🇹 Lithuania': '+370',
    '🇱🇺 Luxembourg': '+352',
    '🇲🇴 Macao': '+853',
    '🇲🇬 Madagascar': '+261',
    '🇲🇼 Malawi': '+265',
    '🇲🇾 Malaysia': '+60',
    '🇲🇻 Maldives': '+960',
    '🇲🇱 Mali': '+223',
    '🇲🇹 Malta': '+356',
    '🇲🇭 Marshall Islands': '+692',
    '🇲🇷 Mauritania': '+222',
    '🇲🇺 Mauritius': '+230',
    '🇲🇽 Mexico': '+52',
    '🇫🇲 Micronesia': '+691',
    '🇲🇩 Moldova': '+373',
    '🇲🇨 Monaco': '+377',
    '🇲🇳 Mongolia': '+976',
    '🇲🇪 Montenegro': '+382',
    '🇲🇦 Morocco': '+212',
    '🇲🇿 Mozambique': '+258',
    '🇲🇲 Myanmar': '+95',
    '🇳🇦 Namibia': '+264',
    '🇳🇷 Nauru': '+674',
    '🇳🇵 Nepal': '+977',
    '🇳🇱 Netherlands': '+31',
    '🇳🇿 New Zealand': '+64',
    '🇳🇮 Nicaragua': '+505',
    '🇳🇪 Niger': '+227',
    '🇳🇬 Nigeria': '+234',
    '🇲🇰 North Macedonia': '+389',
    '🇳🇴 Norway': '+47',
    '🇴🇲 Oman': '+968',
    '🇵🇰 Pakistan': '+92',
    '🇵🇼 Palau': '+680',
    '🇵🇸 Palestine': '+970',
    '🇵🇦 Panama': '+507',
    '🇵🇬 Papua New Guinea': '+675',
    '🇵🇾 Paraguay': '+595',
    '🇵🇪 Peru': '+51',
    '🇵🇭 Philippines': '+63',
    '🇵🇱 Poland': '+48',
    '🇵🇹 Portugal': '+351',
    '🇶🇦 Qatar': '+974',
    '🇷🇴 Romania': '+40',
    '🇷🇺 Russia': '+7',
    '🇷🇼 Rwanda': '+250',
    '🇰🇳 Saint Kitts and Nevis': '+1869',
    '🇱🇨 Saint Lucia': '+1758',
    '🇻🇨 Saint Vincent': '+1784',
    '🇼🇸 Samoa': '+685',
    '🇸🇲 San Marino': '+378',
    '🇸🇹 São Tomé and Príncipe': '+239',
    '🇸🇦 Saudi Arabia': '+966',
    '🇸🇳 Senegal': '+221',
    '🇷🇸 Serbia': '+381',
    '🇸🇨 Seychelles': '+248',
    '🇸🇱 Sierra Leone': '+232',
    '🇸🇬 Singapore': '+65',
    '🇸🇰 Slovakia': '+421',
    '🇸🇮 Slovenia': '+386',
    '🇸🇧 Solomon Islands': '+677',
    '🇸🇴 Somalia': '+252',
    '🇿🇦 South Africa': '+27',
    '🇸🇸 South Sudan': '+211',
    '🇪🇸 Spain': '+34',
    '🇱🇰 Sri Lanka': '+94',
    '🇸🇩 Sudan': '+249',
    '🇸🇷 Suriname': '+597',
    '🇸🇪 Sweden': '+46',
    '🇨🇭 Switzerland': '+41',
    '🇸🇾 Syria': '+963',
    '🇹🇼 Taiwan': '+886',
    '🇹🇯 Tajikistan': '+992',
    '🇹🇿 Tanzania': '+255',
    '🇹🇭 Thailand': '+66',
    '🇹🇱 Timor-Leste': '+670',
    '🇹🇬 Togo': '+228',
    '🇹🇴 Tonga': '+676',
    '🇹🇹 Trinidad and Tobago': '+1868',
    '🇹🇳 Tunisia': '+216',
    '🇹🇷 Turkey': '+90',
    '🇹🇲 Turkmenistan': '+993',
    '🇹🇻 Tuvalu': '+688',
    '🇺🇬 Uganda': '+256',
    '🇺🇦 Ukraine': '+380',
    '🇦🇪 UAE': '+971',
    '🇬🇧 United Kingdom': '+44',
    '🇺🇸 United States': '+1',
    '🇺🇾 Uruguay': '+598',
    '🇺🇿 Uzbekistan': '+998',
    '🇻🇺 Vanuatu': '+678',
    '🇻🇦 Vatican City': '+379',
    '🇻🇪 Venezuela': '+58',
    '🇻🇳 Vietnam': '+84',
    '🇾🇪 Yemen': '+967',
    '🇿🇲 Zambia': '+260',
    '🇿🇼 Zimbabwe': '+263',
  };
  
  Map<String, dynamic>? userData;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      final result = await DatabaseHelper.getUser(userId!);
      if (result.success && result.data != null) {
        setState(() {
          userData = result.data;
          _usernameController.text = userData?['username'] ?? '';
          _emailController.text = userData?['email'] ?? '';
          _bioController.text = userData?['bio'] ?? '';
          _locationController.text = userData?['location'] ?? '';
          _websiteController.text = userData?['website'] ?? '';
          
          // Parse phone number if it exists
          String phoneNumber = userData?['phone_number'] ?? '';
          if (phoneNumber.isNotEmpty) {
            // Check if phone has country code
            if (phoneNumber.startsWith('+')) {
              // Extract country code (assuming format like +1234567890)
              int spaceIndex = phoneNumber.indexOf(' ');
              if (spaceIndex != -1) {
                _selectedCountryCode = phoneNumber.substring(0, spaceIndex);
                _phoneController.text = phoneNumber.substring(spaceIndex + 1);
              } else {
                // Default handling if no space found
                _selectedCountryCode = '+1'; // Default to US
                _phoneController.text = phoneNumber.replaceFirst(RegExp(r'^\+\d+'), '');
              }
            } else {
              _selectedCountryCode = '+1'; // Default to US
              _phoneController.text = phoneNumber;
            }
            
            // Set flag emoji based on country code
            _setFlagFromCountryCode(_selectedCountryCode!);
          } else {
            _selectedCountryCode = '+1'; // Default to US
            _selectedCountryFlag = '🇺🇸'; // Default US flag
          }
          
          isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  void _setFlagFromCountryCode(String code) {
    // Find the flag for the given country code
    String? countryWithFlag = _countryCodes.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => const MapEntry('🇺🇸 United States', '+1'),
        )
        .key;
    
    // Extract just the flag emoji (first character)
    _selectedCountryFlag = countryWithFlag.substring(0, 2);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    int? maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.lexend(
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.lexend(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF6296FF)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6296FF), width: 2),
          ),
          errorText: errorText,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }
  
  Widget _buildPhoneField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(15),
        ],
        style: GoogleFonts.lexend(
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: 'Phone Number',
          labelStyle: GoogleFonts.lexend(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: GestureDetector(
            onTap: () {
              _showCountryCodeDialog();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedCountryFlag ?? '🌍', style: GoogleFonts.lexend(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    _selectedCountryCode ?? '+1',
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      color: const Color(0xFF6296FF),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF6296FF), size: 18),
                ],
              ),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6296FF), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }
  
  void _showCountryCodeDialog() {
    TextEditingController searchController = TextEditingController();
    List<MapEntry<String, String>> filteredCountries = _countryCodes.entries.toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            'Select Country',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            filteredCountries = _countryCodes.entries
                                .where((entry) => entry.key.toLowerCase().contains(value.toLowerCase()))
                                .toList();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search countries...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          // Extract flag emoji and country name
                          final parts = country.key.split(' ');
                          final flag = parts[0];
                          final name = parts.sublist(1).join(' ');
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCountryCode = country.value;
                                  _selectedCountryFlag = flag;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      flag,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      country.value,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF2196F3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF6296FF),
        title: Text(
          "Edit Profile",
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6296FF)))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 40.0 : 20.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6296FF), Color(0xFF5A89F2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6296FF).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note,
                              color: Colors.white,
                              size: 36,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Personal Information',
                                style: GoogleFonts.lexend(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_outline,
                      ),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _buildPhoneField(),
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        icon: Icons.location_on_outlined,
                      ),
                      _buildTextField(
                        controller: _websiteController,
                        label: 'Website',
                        icon: Icons.link,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6296FF).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() => isLoading = true);
                            try {
                              final userId = await UserIdStorage.getLoggedInUserId();
                              
                              // Format phone number with country code
                              String formattedPhone = '';
                              if (_phoneController.text.isNotEmpty) {
                                // Remove any spaces from the phone number
                                String cleanPhone = _phoneController.text.replaceAll(' ', '');
                                // Format with space after country code for consistency
                                formattedPhone = '$_selectedCountryCode $cleanPhone';
                                print('DEBUG: Formatted phone number: $formattedPhone'); // Debug log
                              }
                              
                              final update = {
                                'username': _usernameController.text,
                                'email': _emailController.text,
                                'bio': _bioController.text,
                                'location': _locationController.text,
                                'website': _websiteController.text,
                                'phone_number': formattedPhone,
                              };
                              print('DEBUG: Update data being sent: $update'); // Debug log
                              
                              final result = await DatabaseHelper.patchUser(userId!, update);
                              print('DEBUG: Update result: $result'); // Debug log
                              setState(() => isLoading = false);
                              
                              if (result.success) {
                                print('DEBUG: Update successful, new data: ${result.data}'); // Debug log
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Profile updated successfully!'),
                                      backgroundColor: const Color(0xFF2196F3),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } else {
                                print('DEBUG: Update failed: ${result.data}'); // Debug log
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.data['error'] ?? 'Failed to update profile'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'An error occurred',
                                    style: GoogleFonts.lexend(),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6296FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_outlined, color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                'Save Changes',
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}