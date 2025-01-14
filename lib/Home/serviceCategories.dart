import 'package:flutter/material.dart';

class ServiceCategoryPage extends StatelessWidget {
  const ServiceCategoryPage({super.key});

  final List<Map<String, dynamic>> categories = const [
    {
      'icon': "assets/images/paintbrush.png",
      'title': 'Graphic Design',
      'subtitle': 'Logo & brand identity',
    },
    {
      'icon': "assets/images/marketing.png",
      'title': 'Digital Marketing',
      'subtitle': 'Social media marketing, SEO',
    },
    {
      'icon': "assets/images/video.png",
      'title': 'Video & Animation',
      'subtitle': 'Video editing & Video Ads',
    },
    {
      'icon': "assets/images/music.png",
      'title': 'Music & Audio',
      'subtitle': 'Producers & Composers',
    },
    {
      'icon': "assets/images/tech.png",
      'title': 'Program & Tech',
      'subtitle': 'Website & App development',
    },
    {
      'icon': "assets/images/photography.png",
      'title': 'Product Photography',
      'subtitle': 'Product photographers',
    },
    {
      'icon': "assets/images/ai.png",
      'title': 'Build AI Service',
      'subtitle': 'Build your AI app',
    },
    {
      'icon': "assets/images/data.png",
      'title': 'Data',
      'subtitle': 'Data science & AI',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service Category',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,  // Centers the title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 60, // Adjust height of the AppBar to bring the title a little closer to the top
      ),
      body: ListView.separated(
        itemCount: categories.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50), // Adds space on the sides of the divider
          child: Divider(
            thickness: 1, // Sets the thickness of the line
            color: Colors.grey.shade400.withOpacity(0.3), // 50% less transparent
            ),
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ListTile(
            leading: Container(
              width: 48, // Set width of the square (adjust size as needed)
              height: 48, // Set height of the square (same as width for a square)
              decoration: BoxDecoration(
                color: Colors.grey.shade200.withOpacity(0.4), // Less transparent background
                borderRadius: BorderRadius.circular(12), // Rounded corners
              ),
              child: Image.asset(
                category['icon'],  // Use Image.asset to load the image
                width: 28,  // Adjust the width of the image
                height: 28, // Adjust the height of the image
                fit: BoxFit.cover,  // Ensure the image scales appropriately
              ),
            ),

            title: Text(
              category['title'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              category['subtitle'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              // Handle tap event
            },
          );
        },
      ),
      backgroundColor: Colors.white,
    );
  }
}