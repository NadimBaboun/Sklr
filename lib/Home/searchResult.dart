import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/Skills/skillInfo.dart';

class SearchResultsPage extends StatefulWidget {
  final String search;
  const SearchResultsPage({super.key, required this.search});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late Future<Map<String, List<Map<String, dynamic>>>> _searchResults;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchResults = _fetchSearchResults();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchSearchResults() async {
    if (widget.search.trim().isEmpty) {
      return {
        'skills': [],
        'users': [],
        'categories': []
      };
    }

    try {
      // Search across multiple entities
      final results = await DatabaseHelper.searchAll(widget.search.trim());
      
      // Sort each category by relevance
      for (var category in results.keys) {
        results[category]?.sort((a, b) {
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();
          final searchLower = widget.search.toLowerCase();
          
          if (aName == searchLower && bName != searchLower) return -1;
          if (bName == searchLower && aName != searchLower) return 1;
          
          final aContains = aName.contains(searchLower);
          final bContains = bName.contains(searchLower);
          if (aContains && !bContains) return -1;
          if (bContains && !aContains) return 1;
          
          return aName.compareTo(bName);
        });
      }

      return results;
    } catch (error) {
      throw Exception('Failed to fetch search results: $error');
    }
  }

  List<Map<String, dynamic>> _getFilteredResults(Map<String, List<Map<String, dynamic>>> results) {
    if (_selectedFilter == 'All') {
      return [
        ...results['skills'] ?? [],
        ...results['users'] ?? [],
        ...results['categories'] ?? []
      ];
    } else {
      return results[_selectedFilter.toLowerCase()] ?? [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Results for "${widget.search}"',
          style: GoogleFonts.mulish(
            color: Colors.white,
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (String value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'All',
                child: Text('All Results'),
              ),
              const PopupMenuItem<String>(
                value: 'Skills',
                child: Text('Skills Only'),
              ),
              const PopupMenuItem<String>(
                value: 'Users',
                child: Text('Users Only'),
              ),
              const PopupMenuItem<String>(
                value: 'Categories',
                child: Text('Categories Only'),
              ),
            ],
          ),
        ],
        backgroundColor: const Color(0xFF6296FF),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _searchResults,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.mulish(
                      fontSize: isLargeScreen ? 18 : 16,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            );
          }

          final results = snapshot.data ?? {};
          final filteredResults = _getFilteredResults(results);

          if (filteredResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 60, color: Color(0xFF9094A7)),
                  const SizedBox(height: 16),
                  Text(
                    'No $_selectedFilter results found for "${widget.search}"',
                    style: GoogleFonts.mulish(
                      fontSize: isLargeScreen ? 20 : 18,
                      color: const Color(0xFF9094A7),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
            itemCount: filteredResults.length,
            itemBuilder: (context, index) {
              final item = filteredResults[index];
              final itemType = item['type'] ?? 'unknown';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    if (itemType == 'skill') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Skillinfo(id: item['id']),
                        ),
                      );
                    }
                    // Add navigation for other types as needed
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item['name'] ?? 'No Name',
                                style: GoogleFonts.mulish(
                                  fontSize: isLargeScreen ? 22 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2D3142),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6296FF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  itemType.toUpperCase(),
                                  style: GoogleFonts.mulish(
                                    fontSize: 12,
                                    color: const Color(0xFF6296FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item['description'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              item['description'],
                              style: GoogleFonts.mulish(
                                fontSize: isLargeScreen ? 16 : 14,
                                color: const Color(0xFF9094A7),
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
