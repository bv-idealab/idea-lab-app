import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'main.dart';

// ⚠️ PASTE YOUR GEMINI API KEY HERE
const String _kGeminiApiKey = 'AIzaSyAcbj1nMTVT74CwX5fkCjurO3jrarIz9d0';

const String _kSystemInstruction = '''
You are the IDEA Lab Assistant at Bharati Vidyapeeth College of Engineering, Pune.
Your role is to help students with everything related to the AICTE IDEA Lab.

PERSONALITY:
- Speak like a friendly, knowledgeable senior student or lab technician
- Use simple, clear English — avoid jargon unless explaining a technical concept
- Be encouraging and supportive, especially for project ideas
- Keep responses concise (2–4 sentences for simple questions, slightly longer for technical ones)
- Always be professional but approachable

KNOWLEDGE AREAS YOU COVER:
1. Lab machines: Laser Cutter, Vinyl Cutter, 3D Printer, 3D Scanner, CNC Router, Wood Lathe, PCB Milling Machine, Raspberry Pi, ESP32, Beagle Board
2. How to book machines via the app
3. Safety rules and lab etiquette
4. Project ideas for electronics, IoT, robotics, mechanical, and software domains
5. How to register a project in the app
6. How to report machine issues
7. General lab access and QR code entry pass
8. Faculty mentors and team collaboration

RESPONSE STYLE:
- Start with a direct answer, then add helpful context
- For machine usage questions, always mention safety first
- For project ideas, give 2–3 specific, actionable suggestions
- If you don't know something specific to this lab, say "I'd recommend checking with the lab admin or faculty mentor for that."
- Never make up machine availability — tell users to check the Machine Status section in the app
''';

// Moved ChatMessageModel here so the file is self-contained
class ChatMessageModel {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessageModel({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with TickerProviderStateMixin {
  final List<ChatMessageModel> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  late final GenerativeModel _geminiModel;
  late final ChatSession _chatSession;

  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  String _voiceInput = '';

  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;
  late AnimationController _micPulseController;

  final List<String> suggestedQuestions = [
    "How to use the 3D printer?",
    "Available machines lab",
    "Suggest robotics project ideas",
    "Suggest Iot projects",
    "How to book a CNC machine?",
    "How to access lab"
  ];

  @override
  void initState() {
    super.initState();

    _geminiModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _kGeminiApiKey,
      systemInstruction: Content.system(_kSystemInstruction),
    );
    _chatSession = _geminiModel.startChat();

    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _configureTts();

    _sendButtonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut));

    _micPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

    _messages.add(ChatMessageModel(
      text: "Hello ${AppData.currentUser.firstName}! How can I help you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _configureTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _tts.setCancelHandler(() => setState(() => _isSpeaking = false));
  }

  @override
  void dispose() {
    _sendButtonController.dispose();
    _micPulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<String> _fetchAIResponse(String query) async {
    try {
      final response = await _chatSession.sendMessage(Content.text(query));
      return response.text ?? "I'm sorry, I couldn't generate a response.";
    } catch (e) {
      return "ERROR: ${e.toString()}\n\n(If this says 'SocketException', check your phone's Wi-Fi or mobile data.)";
    }
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    if (_isSpeaking) await _tts.stop();

    setState(() {
      _messages.insert(0, ChatMessageModel(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });

    _scrollToBottom();

    String responseText = await _fetchAIResponse(text);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.insert(0, ChatMessageModel(text: responseText, isUser: false, timestamp: DateTime.now()));
      });
      _scrollToBottom();
      await _tts.speak(responseText);
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_voiceInput.isNotEmpty) {
            _handleSubmitted(_voiceInput);
            _voiceInput = '';
          }
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mic error: ${error.errorMsg}'), backgroundColor: Colors.redAccent));
      },
    );

    if (available) {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _voiceInput = result.recognizedWords;
            _textController.text = _voiceInput;
          });
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission not granted.'), backgroundColor: Colors.redAccent));
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _toggleSpeaking(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      await _tts.speak(text);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Widget _buildSuggestedChip(String text, Color primaryColor, bool isMain) {
    return GestureDetector(
      onTap: () => _handleSubmitted(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMain ? const Color(0xFF6A93D8) : const Color(0xFFC7D6F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: isMain ? Colors.white : const Color(0xFF6A93D8), fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false, // NO BACK BUTTON
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 16),
            ),
            const SizedBox(width: 8),
            const Text("IDEA Lab Assistant", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.record_voice_over_rounded, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Voice-enabled AI Assistant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade900)),
                        const SizedBox(height: 2),
                        Text("Tap 🎤 to speak, or type your question below.", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (_, index) {
                  return AnimatedChatMessage(
                    message: _messages[index],
                    primaryColor: primaryColor,
                    isSpeaking: _isSpeaking && index == 0,
                    onSpeakerTapped: () => _toggleSpeaking(_messages[index].text),
                  );
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(0, primaryColor),
                        const SizedBox(width: 4),
                        _buildDot(200, primaryColor),
                        const SizedBox(width: 4),
                        _buildDot(400, primaryColor),
                      ],
                    ),
                  ),
                ),
              ),

            if (_isListening)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.shade100),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _micPulseController,
                      builder: (_, __) => Icon(Icons.mic_rounded, color: Color.lerp(Colors.redAccent, Colors.red.shade800, _micPulseController.value), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_voiceInput.isEmpty ? "Listening... speak now" : _voiceInput, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14))),
                    GestureDetector(onTap: _stopListening, child: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 22)),
                  ],
                ),
              ),

            if (!_isListening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      for (int i = 0; i < suggestedQuestions.length; i++)
                        _buildSuggestedChip(suggestedQuestions[i], primaryColor, i % 2 == 0),
                    ],
                  ),
                ),
              ),

            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _isListening ? Colors.redAccent : primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(_isListening ? Icons.mic_off_rounded : Icons.mic_rounded, color: _isListening ? Colors.white : primaryColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: "Ask something about the lab...",
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        filled: true,
                        fillColor: const Color(0xFFF4F7FB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTapDown: (_) => _sendButtonController.forward(),
                    onTapUp: (_) {
                      _sendButtonController.reverse();
                      _handleSubmitted(_textController.text);
                    },
                    onTapCancel: () => _sendButtonController.reverse(),
                    child: ScaleTransition(
                      scale: _sendButtonScale,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFF6A93D8),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int delayMs, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, v, __) => Opacity(opacity: v, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
    );
  }
}

class AnimatedChatMessage extends StatefulWidget {
  final ChatMessageModel message;
  final Color primaryColor;
  final bool isSpeaking;
  final VoidCallback onSpeakerTapped;

  const AnimatedChatMessage({
    super.key,
    required this.message,
    required this.primaryColor,
    required this.isSpeaking,
    required this.onSpeakerTapped,
  });

  @override
  State<AnimatedChatMessage> createState() => _AnimatedChatMessageState();
}

class _AnimatedChatMessageState extends State<AnimatedChatMessage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: Offset(widget.message.isUser ? 0.2 : -0.2, 0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  String _formatTime(DateTime time) {
    String hour = time.hour > 12 ? (time.hour - 12).toString() : (time.hour == 0 ? "12" : time.hour.toString());
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}";
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isUser) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))], border: Border.all(color: Colors.grey.shade200)),
                      child: Icon(Icons.auto_awesome_rounded, color: widget.primaryColor, size: 16),
                    ),
                  ],
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                          color: isUser ? widget.primaryColor.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isUser ? 20 : 4), bottomRight: Radius.circular(isUser ? 4 : 20)),
                          boxShadow: isUser ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          border: isUser ? null : Border.all(color: Colors.grey.shade200)
                      ),
                      child: Text(widget.message.text, style: TextStyle(color: Colors.grey.shade900, fontSize: 15, height: 1.4, fontWeight: FontWeight.w400)),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: EdgeInsets.only(top: 6, left: isUser ? 0 : 44, right: isUser ? 8 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatTime(widget.message.timestamp), style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),

                    if (!isUser) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.onSpeakerTapped,
                        child: Icon(
                          widget.isSpeaking ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          size: 16,
                          color: widget.isSpeaking ? widget.primaryColor : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
