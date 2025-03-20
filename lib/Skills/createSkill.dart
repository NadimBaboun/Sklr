import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user_id_storage/user_id_storage.dart';

class CreateSkill extends StatefulWidget {
  // ... (existing code)
  @override
  _CreateSkillState createState() => _CreateSkillState();
}

class _CreateSkillState extends State<CreateSkill> {
  // ... (existing code)

  Future<void> _createSkill() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final userId = await UserIdStorage.getLoggedInUserId();
        
        if (userId == null) {
          throw Exception('User ID not found. Please log in again.');
        }
        
        // Use direct Supabase query for better error handling
        final skillData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'cost': double.parse(_costController.text.trim()),
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
        
        // Insert skill data
        final result = await supabase
          .from('skills')
          .insert(skillData)
          .select();
          
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating skill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
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
    // ... (rest of the existing code)
  }
} 