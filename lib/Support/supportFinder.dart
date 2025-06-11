import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Util/navigationbar-bar.dart';

class SupportFinderPage extends StatefulWidget {
  const SupportFinderPage({super.key});

  @override
  State<SupportFinderPage> createState() => _SupportFinderPageState();
}

class _SupportFinderPageState extends State<SupportFinderPage> 
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = [];
  bool _isTyping = false;
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animation controllers
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
    
    // Clean welcome message (no emojis)
    _addBotMessage("Hello! I'm your intelligent SKLR support assistant. I'm here to help you navigate our skill-sharing platform, troubleshoot issues, and make the most of your experience. What can I help you with today?");
    
    // Enhanced system message with emoji restriction
    _conversationHistory.add({
      'role': 'system', 
      'content': '''You are an advanced AI support assistant for SKLR, a comprehensive skill-sharing platform. Your role is to be helpful, creative, and knowledgeable about all aspects of the platform.

IMPORTANT: Do NOT use any emojis, emoticons, or special Unicode characters in your responses. Use only standard text characters.

SKLR PLATFORM OVERVIEW:
- A skill-sharing marketplace where users offer and request skills
- Users can create detailed skill listings with descriptions, pricing, and categories
- Features include user profiles, skill browsing, category filtering, and contact systems
- Payment system integration (currently in development)
- User authentication and profile management
- Rating and review systems
- Search and discovery features

YOUR CAPABILITIES:
- Answer questions about platform features and functionality
- Help troubleshoot technical issues
- Provide step-by-step guidance for common tasks
- Suggest best practices for skill listings and profiles
- Explain platform policies and guidelines
- Offer creative solutions to user challenges
- Provide tips for maximizing success on the platform

COMMUNICATION STYLE:
- Be friendly, professional, and encouraging
- Use clear, concise language with helpful examples
- Provide actionable advice and specific steps
- Ask clarifying questions when needed
- Offer multiple solutions when possible
- Be creative in your responses while staying helpful and accurate
- Use bullet points and formatting for clarity
- NO EMOJIS OR SPECIAL CHARACTERS

Always strive to be comprehensive yet concise, and provide creative suggestions that enhance the user experience without using any emojis or special characters.'''
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Simple emoji removal function
  String _removeEmojis(String text) {
    return text.replaceAll(RegExp(r'[\u{1f300}-\u{1f5ff}]|[\u{1f600}-\u{1f64f}]|[\u{1f680}-\u{1f6ff}]|[\u{1f700}-\u{1f77f}]|[\u{1f780}-\u{1f7ff}]|[\u{1f800}-\u{1f8ff}]|[\u{2600}-\u{26ff}]|[\u{2700}-\u{27bf}]', unicode: true), '');
  }

  void _addBotMessage(String text) {
    // Clean the message of any emojis before adding
    final cleanText = _removeEmojis(text);
    setState(() {
      _messages.add(ChatMessage(
        text: cleanText,
        isUser: false,
      ));
    });
    _scrollToBottom();
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    
    final message = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
      ));
      _isTyping = true;
    });
    
    _conversationHistory.add({
      'role': 'user',
      'content': message
    });
    
    _scrollToBottom();

    try {
      final response = await _sendMessageToAI(message);
      
      if (!mounted) return;
      
      // Clean the AI response of emojis before storing
      final cleanResponse = _removeEmojis(response);
      
      _conversationHistory.add({
        'role': 'assistant',
        'content': cleanResponse
      });
      
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: cleanResponse,
          isUser: false,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: "I apologize, but I'm experiencing technical difficulties. Please try again in a moment, or feel free to contact our human support team if the issue persists.",
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<String> _sendMessageToAI(String userMessage) async {
    setState(() {
      _isTyping = true;
    });

    try {
      List<Map<String, dynamic>> messages = [];
      
      // Enhanced system message with strict emoji prohibition
      messages.add({
        "role": "system",
        "content": '''You are an expert AI support assistant for SKLR, a skill-sharing platform. Be creative, comprehensive, and helpful in your responses. 

CRITICAL REQUIREMENT: You must NEVER use emojis, emoticons, or any special Unicode characters in your responses. Use only standard ASCII text characters.

ENHANCED TRAINING CONTEXT:
- Provide detailed, step-by-step guidance for complex questions
- Offer multiple approaches to solve problems
- Include practical examples and use cases
- Suggest proactive tips and best practices
- Be encouraging and supportive in your tone
- Use formatting like bullet points when helpful
- Provide context about why certain features work the way they do
- Anticipate follow-up questions and address them proactively

PLATFORM EXPERTISE AREAS:
• Account Management: Registration, profile setup, verification, security
• Skill Listings: Creation, optimization, pricing, categories, descriptions
• Discovery: Search, filtering, browsing, recommendations
• Communication: Messaging, contact methods, professional etiquette
• Safety: Best practices, reporting, privacy, secure transactions
• Technical: App navigation, troubleshooting, feature explanations
• Business: Pricing strategies, market positioning, success tips

RESPONSE FORMAT:
- Use clear headings and bullet points
- Write in a professional yet friendly tone
- Provide specific examples when helpful
- End responses with actionable next steps
- NO EMOJIS OR SPECIAL CHARACTERS ALLOWED

Always aim to exceed user expectations with thorough, creative, and actionable responses using only standard text.'''
      });
      
      // Maintain conversation context (last 12 messages for better continuity)
      final historyToSend = _conversationHistory.length > 12 
          ? _conversationHistory.sublist(_conversationHistory.length - 12) 
          : _conversationHistory;
      
      for (var msg in historyToSend) {
        messages.add({
          "role": msg['role'],
          "content": msg['content']
        });
      }
      
      messages.add({
        "role": "user",
        "content": userMessage
      });

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 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',
          'HTTP-Referer': 'https://sklr.app',
          'X-Title': 'SKLR Advanced Support Assistant',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3.2-3b-instruct:free',
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1500,
          'top_p': 0.9,
          'frequency_penalty': 0.1,
          'presence_penalty': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];
        
        // Double-check: Clean any emojis that might have slipped through
        final cleanResponse = _removeEmojis(aiResponse);
        return cleanResponse;
      } else {
        print('Error: ${response.statusCode}');
        print('Response: ${response.body}');
        return 'I apologize for the technical difficulty. Our AI system is temporarily experiencing issues. Please try rephrasing your question or contact our human support team for immediate assistance.';
      }
    } catch (e) {
      print('Exception: $e');
      return 'I encountered an unexpected error while processing your request. Please check your internet connection and try again. If the problem persists, our human support team is available to help.';
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2196F3),
                Color(0xFF1976D2),
                Color(0xFF0D47A1),
              ],
            ),
          ),
        ),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'AI Support Assistant',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[50]!,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 24,
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
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: _messages.isEmpty
                    ? _buildEnhancedEmptyState()
                    : Container(
                        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _messages[index];
                          },
                        ),
                      ),
              ),
              
              if (_isTyping) _buildEnhancedTypingIndicator(),
              _buildEnhancedInputArea(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 4),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2196F3).withOpacity(0.1),
                          const Color(0xFF1976D2).withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      size: 72,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your Intelligent Support Companion',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D29),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'I\'m here to provide comprehensive assistance with SKLR. Ask me about features, troubleshooting, best practices, or anything else you need help with.',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildSuggestedQuestions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = [
      'How do I create an effective skill listing?',
      'How can I find the right skills on SKLR?',
      'Help me set up my profile',
      'What are the best pricing strategies?',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try asking:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(height: 12),
        ...suggestions.map((suggestion) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              _messageController.text = suggestion;
              _handleSubmitted(_messageController.text);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                ),
              ),
              child: Text(
                suggestion,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildEnhancedTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2196F3).withOpacity(0.05),
            const Color(0xFF1976D2).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEnhancedAnimatedDots(),
          const SizedBox(width: 16),
          Text(
            'AI is analyzing...',
            style: GoogleFonts.poppins(
              color: const Color(0xFF2196F3),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAnimatedDots() {
    return Row(
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final animationValue = (_animationController.value + index * 0.3) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -4 * animationValue + 4 * (1 - animationValue)),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2196F3).withOpacity(0.4 + animationValue * 0.6),
                        Color(0xFF1976D2).withOpacity(0.4 + animationValue * 0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF2196F3).withOpacity(0.3 * animationValue),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildEnhancedInputArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask me anything about SKLR...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, 
                  vertical: 16,
                ),
              ),
              style: GoogleFonts.poppins(
                color: const Color(0xFF1A1D29),
                fontSize: 15,
              ),
              onSubmitted: (_) {
                if (_messageController.text.trim().isNotEmpty) {
                  _handleSubmitted(_messageController.text);
                }
              },
              maxLines: null,
              textInputAction: TextInputAction.send,
              cursorColor: const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Container(
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
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  if (_messageController.text.trim().isNotEmpty) {
                    _handleSubmitted(_messageController.text);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2196F3),
                      Color(0xFF1976D2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enhanced AI Assistant',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1A1D29),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This advanced AI assistant is trained to provide comprehensive, creative, and detailed responses about SKLR. It can help with platform features, troubleshooting, best practices, and much more.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your conversations are processed securely and not stored permanently.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40, 
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Got it!',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildBotAvatar(),
          if (!isUser) const SizedBox(width: 16),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: isUser 
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2196F3),
                          Color(0xFF1976D2),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2196F3).withOpacity(0.05),
                          const Color(0xFF1976D2).withOpacity(0.02),
                        ],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 24 : 8),
                  topRight: Radius.circular(isUser ? 8 : 24),
                  bottomLeft: const Radius.circular(24),
                  bottomRight: const Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? const Color(0xFF2196F3).withOpacity(0.3)
                        : const Color(0xFF2196F3).withOpacity(0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: !isUser ? Border.all(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  width: 1,
                ) : null,
              ),
              child: SelectableText(
                text,
                style: GoogleFonts.poppins(
                  color: isUser ? Colors.white : const Color(0xFF1A1D29),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 16),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2196F3).withOpacity(0.1),
            const Color(0xFF1976D2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.psychology_rounded,
        color: Color(0xFF2196F3),
        size: 22,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 40,
      height: 40,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
