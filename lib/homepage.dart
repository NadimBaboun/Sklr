import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/service-categories.dart';
import 'package:sklr/Profile.dart';
import 'package:sklr/notfication-control.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Responsive Example',
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(200.0),
          child: AppBar(
            backgroundColor: const Color(0xFF6296FF),
            flexibleSpace: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'Hello, User!',
                        style: GoogleFonts.lexend(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth > 600 ? 28 : 20,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Let's find the best talent for you",
                        style: GoogleFonts.lexend(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth > 600 ? 36 : 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Adjusting the Search Bar
                      Flexible(
                        child: SizedBox(
                          width: constraints.maxWidth * 0.8,  // Dynamic width (80% of screen width)
                          child: TextField(
                            onChanged: (value) {
                              // search term
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF6296FF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Search service',
                              hintStyle: GoogleFonts.lexend(
                                textStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: constraints.maxWidth > 600 ? 18 : 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Service Category',
                        style: GoogleFonts.lexend(
                          textStyle: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ServiceCategoryPage(),
                            ),
                          );
                        },
                        child: Text(
                          'See All',
                          style: GoogleFonts.lexend(
                            textStyle: const TextStyle(
                              color: Color(0xFF6296FF),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: constraints.maxWidth > 600 ? 1 : 0.9,
                      children: _buildServiceCategoryCards(constraints),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Popular Services',
                    style: GoogleFonts.lexend(
                      textStyle: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  List<Widget> _buildServiceCategoryCards(BoxConstraints constraints) {
    const categories = [
      {'icon': 'assets/images/paintbrush.png', 'label': 'Graphic Design'},
      {'icon': 'assets/images/marketing.png', 'label': 'Digital Marketing'},
      {'icon': 'assets/images/video.png', 'label': 'Video & Animation'},
      {'icon': 'assets/images/tech.png', 'label': 'Program & Tech'},
      {'icon': 'assets/images/music.png', 'label': 'Music & Audio'},
      {'icon': 'assets/images/photography.png', 'label': 'Product Photography'},
      {'icon': 'assets/images/design.png', 'label': 'UI/UX Design'},
      {'icon': 'assets/images/ai.png', 'label': 'Build AI Services'},
    ];

    return categories
        .map(
          (category) => InkWell(
            onTap: () {
              // Navigate to the respective category page
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  width: constraints.maxWidth > 600 ? 80 : 74,
                  height: constraints.maxWidth > 600 ? 80 : 74,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      category['icon']!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category['label']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    textStyle: TextStyle(
                      color: Colors.black,
                      fontSize: constraints.maxWidth > 600 ? 15 : 13,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 2.0,
          ),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, color: Color(0xFF6296FF)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          // Navigate to respective pages
        },
        selectedItemColor: const Color(0xFF6296FF),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
// the media query has been changed to be responsive 
// there are a problem of the search box size 