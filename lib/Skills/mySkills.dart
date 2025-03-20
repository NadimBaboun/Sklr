class _MySkillsState extends State<MySkills> {
  late Future<List<Map<String, dynamic>>> skillsFuture;
  bool isLoading = false;
  int? userId;
  String? username;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentUserId = await UserIdStorage.getLoggedInUserId();
    if (currentUserId != null) {
      final user = await DatabaseHelper.fetchUserFromId(currentUserId);
      if (user.success && mounted) {
        setState(() {
          userId = currentUserId;
          username = user.data['username'];
          skillsFuture = DatabaseHelper.fetchSkills(userId);
        });
      }
    }
  }

  Future<void> _refreshSkills() async {
    setState(() {
      skillsFuture = DatabaseHelper.fetchSkills(userId);
    });
  }
  
  void _showAddSkillDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    String? selectedCategory;
    List<String> categories = [];
    
    // Fetch categories
    DatabaseHelper.fetchCategories().then((cats) {
      if (mounted) {
        setState(() {
          categories = cats.map((cat) => cat['name'] as String).toList();
          if (categories.isNotEmpty) {
            selectedCategory = categories.first;
          }
        });
      }
    });
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Add New Skill',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Skill Name',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cost (credits)',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || 
                        descriptionController.text.isEmpty || 
                        costController.text.isEmpty || 
                        selectedCategory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }
                    
                    final cost = double.tryParse(costController.text);
                    if (cost == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid cost')),
                      );
                      return;
                    }
                    
                    Navigator.of(context).pop();
                    
                    setState(() {
                      isLoading = true;
                    });
                    
                    try {
                      await supabase.from('skills').insert({
                        'name': nameController.text,
                        'description': descriptionController.text,
                        'cost': cost,
                        'category': selectedCategory,
                        'user_id': userId.toString(),
                        'created_at': DateTime.now().toIso8601String(),
                        'status': 'Active',
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Skill added successfully')),
                        );
                        _refreshSkills();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding skill: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    'Add Skill',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Skills',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSkills,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSkillDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add New Skill',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: skillsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No skills found'));
          } else {
            final skills = snapshot.data!;
            return ListView.builder(
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return ListTile(
                  title: Text(skill['name']),
                  subtitle: Text(skill['description']),
                );
              },
            );
          }
        },
      ),
    );
  }
} 