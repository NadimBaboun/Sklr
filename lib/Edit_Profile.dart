import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _selectedCountry;
  String _selectedGender = 'Male';
  String _countryDialCode = '';
  List<Map<String, String>> _countries = [];

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    const url = 'https://restcountries.com/v3.1/all';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _countries = data
              .map((country) => {
                    'name': country['name']['common'] as String,
                    'dial_code': country['idd']['root'] != null
                        ? '${country['idd']['root']}${(country['idd']['suffixes'] ?? [''])[0]}'
                        : '',
                  })
              .where((country) =>
                  country['dial_code'] != null && country['dial_code']!.isNotEmpty)
              .toList();
          _selectedCountry = _countries.first['name'];
          _countryDialCode = _countries.first['dial_code']!;
        });
      }
    } catch (error) {
      print('Failed to load countries: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 40.0 : 20.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 15),

              // Nickname
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: 'Nick name'),
              ),
              const SizedBox(height: 15),

              // Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 15),

              // Phone Number with Dial Code
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _countryDialCode,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Phone number'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Country Selector
              _countries.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      value: _selectedCountry,
                      onChanged: (value) {
                        setState(() {
                          _selectedCountry = value!;
                          _countryDialCode = _countries.firstWhere(
                            (country) => country['name'] == value,
                          )['dial_code']!;
                        });
                      },
                      items: _countries
                          .map((country) => DropdownMenuItem(
                                value: country['name'],
                                child: Text(country['name']!),
                              ))
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Country'),
                    )
                  : const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 15),

              // Gender Selector
              DropdownButtonFormField<String>(
                value: _selectedGender,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value!;
                  });
                },
                items: ['Male', 'Female', 'Other']
                    .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              const SizedBox(height: 15),

              // Address
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 30),

              // Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Handle form submission
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 50.0 : 30.0,
                      vertical: 15.0,
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//responsive check done 