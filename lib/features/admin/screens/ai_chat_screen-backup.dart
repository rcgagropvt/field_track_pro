import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'admin_shell.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  final _suggestions = [
    'How is Advait performing this month?',
    'Which parties are at churn risk?',
    'Show me today\'s anomalies',
    'Who has the most ghost visits?',
    'What\'s our total revenue this month?',
    'Which reps have low attendance?',
    'Compare all employee performance',
    'Any geofence violations this week?',
    'Which parties need urgent visits?',
    'Summarize today\'s field operations',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages
          .add(_ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await SupabaseService.client.functions.invoke(
        'ai-chat',
        body: {'question': text},
      );

      Map<String, dynamic>? data;
      if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else if (response.data is String) {
        try {
          data = jsonDecode(response.data) as Map<String, dynamic>;
        } catch (_) {
          data = {'answer': response.data.toString()};
        }
      }

      if (data != null && data['answer'] != null) {
        final model = data['model_used']?.toString() ?? 'unknown';
        final context = data['context_summary'] as Map<String, dynamic>? ?? {};
        setState(() {
          _messages.add(_ChatMessage(
            text: data!['answer'].toString(),
            isUser: false,
            time: DateTime.now(),
            model: model,
            contextInfo:
                '${context['employees'] ?? 0} employees · ${context['parties'] ?? 0} parties · ${context['anomalies'] ?? 0} anomalies analyzed',
          ));
        });
      } else if (data != null && data['error'] != null) {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Error: ${data!['error']}',
            isUser: false,
            isError: true,
            time: DateTime.now(),
          ));
        });
      } else {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Unexpected response format. Please try again.',
            isUser: false,
            isError: true,
            time: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      debugPrint('AI Chat error: $e');
      setState(() {
        _messages.add(_ChatMessage(
          text:
              'Connection error. Please check your internet and try again.\n\nDetails: $e',
          isUser: false,
          isError: true,
          time: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
      backgroundColor: const Color(0xFF0F1123),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1123),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3DBFFF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vartmaan AI',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Ask anything about your business',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ]),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38),
              onPressed: () => setState(() => _messages.clear()),
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty ? _buildWelcome() : _buildMessages(),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3DBFFF)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child:
                const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('Vartmaan AI Assistant',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('Powered by real-time data from your field operations',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const SizedBox(height: 30),
        const Text('Try asking:',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map((s) => GestureDetector(
                    onTap: () => _sendMessage(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2D3E)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 14, color: Color(0xFF6C63FF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(s,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                      ]),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 50 : 0,
          right: isUser ? 0 : 50,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isError
              ? Colors.red.withOpacity(0.15)
              : isUser
                  ? const Color(0xFF6C63FF)
                  : const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: const Color(0xFF2A2D3E)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isUser && !msg.isError) ...[
            Row(children: [
              const Icon(Icons.auto_awesome,
                  size: 12, color: Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              const Text('Vartmaan AI',
                  style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (msg.model != null)
                Text(msg.model!,
                    style: const TextStyle(color: Colors.white24, fontSize: 9)),
            ]),
            const SizedBox(height: 8),
          ],
          SelectableText(
            msg.text,
            style: TextStyle(
              color: msg.isError ? Colors.red.shade300 : Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text(
              DateFormat('hh:mm a').format(msg.time),
              style:
                  TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9),
            ),
            if (msg.contextInfo != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(msg.contextInfo!,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.2), fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            if (!isUser) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1)),
                  );
                },
                child: Icon(Icons.copy,
                    size: 14, color: Colors.white.withOpacity(0.3)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 50),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2D3E)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6C63FF)),
          ),
          const SizedBox(width: 10),
          Text('Analyzing your data...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Color(0xFF151729),
        border: Border(top: BorderSide(color: Color(0xFF2A2D3E))),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2A2D3E)),
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask about your team, visits, revenue...',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _isLoading ? null : _sendMessage,
              maxLines: 3,
              minLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isLoading ? null : () => _sendMessage(_controller.text),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: _isLoading
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3DBFFF)]),
              color: _isLoading ? Colors.grey.shade800 : null,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              _isLoading ? Icons.hourglass_empty : Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime time;
  final String? model;
  final String? contextInfo;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isError = false,
    this.model,
    this.contextInfo,
  });
}
