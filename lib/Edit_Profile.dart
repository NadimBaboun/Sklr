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
              .where((country) => country['dial_code'] != null && country['dial_code']!.isNotEmpty)
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full name',
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: 'Nick name',
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                ),
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  // Dial Code Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _countryDialCode,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 10),
                  // Phone Number Input
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
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
                      decoration: InputDecoration(
                        labelText: 'Country',
                      ),
                    )
                  : CircularProgressIndicator(),
              SizedBox(height: 15),
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
                decoration: InputDecoration(
                  labelText: 'Gender',
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                ),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Handle form submission logic
                },
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
