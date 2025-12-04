import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/user_id_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/supabase_service.dart';

class CreateSkill extends StatefulWidget {
  @override
  _CreateSkillState createState() => _CreateSkillState();
}

class _CreateSkillState extends State<CreateSkill> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  String? _selectedCategory;
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _createSkill() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Retrieve the logged-in user ID
        final userId = await UserIdStorage.getLoggedInUserId();
        if (userId == null) {
          throw Exception('User ID not found. Please log in again.');
        }

        // Parse the cost value safely
        final cost = double.tryParse(_costController.text.trim());
        if (cost == null) {
          throw Exception('Invalid cost value. Please enter a valid number.');
        }

        // Prepare skill data
        final skillData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'cost': cost,
          'category': _selectedCategory,
          'user_id': userId.toString(),
          'created_at': DateTime.now().toIso8601String(),
          'status': 'Active',
        };

        // Upload image if selected
        if (_selectedImage != null) {
          final fileName = 'skill_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await supabase.storage
              .from('listing-images')
              .uploadBinary(
                fileName,
                _selectedImage!.readAsBytesSync(),
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );

          final imageUrl = supabase.storage
              .from('listing-images')
              .getPublicUrl(fileName);

          skillData['image_url'] = imageUrl;
        }

        // Insert skill data into the database
        final result = await supabase.from('skills').insert(skillData).select();

        if (result.isEmpty) {
          throw Exception('Failed to create skill: No data returned from the database.');
        }

        // Show success message and navigate back
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Skill created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating skill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Reset loading state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Skill'),
        backgroundColor: const Color(0xFF6296FF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skill Name',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter skill name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Skill name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter skill description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Cost',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Enter cost',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Cost is required';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Category',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: ['Category 1', 'Category 2', 'Category 3']
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Image',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    // Implement image picker logic here
                  },
                  child: const Text('Select Image'),
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _createSkill,
                          child: const Text('Create Skill'),
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