import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../messages/chat_page.dart';

class HelpAndSupportPage extends StatefulWidget {
  final String? userId;
  final String userName;
  final String userRole;

  const HelpAndSupportPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<HelpAndSupportPage> createState() => _HelpAndSupportPageState();
}

class _HelpAndSupportPageState extends State<HelpAndSupportPage> {
  final ChatService _chatService = ChatService();
  bool _isOpeningChat = false;

  Future<void> _openAdminChat() async {
    final userId = widget.userId?.trim() ?? '';
    if (userId.isEmpty || _isOpeningChat) {
      return;
    }

    setState(() => _isOpeningChat = true);
    try {
      final conversationId = await _chatService.ensureSupportConversation(
        userId: userId,
        userName: widget.userName,
        userRole: widget.userRole,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: userId,
            currentUserRole: widget.userRole,
            title: 'SakayNow Support',
            subtitle: 'Admin',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open support: $error')));
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedRole = widget.userRole.trim().toLowerCase();
    final isAdmin = normalizedRole == 'admin';
    final canMessageAdmin =
        !isAdmin && widget.userId?.trim().isNotEmpty == true;

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Help and Support', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PassengerSurfaceCard(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: PassengerUi.blueSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: PassengerUi.accentBlue,
                      size: 30,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Need help with SakayNow Buenatoda?',
                    textAlign: TextAlign.center,
                    style: PassengerUi.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'Review support channels and contact details for SakayNow assistance.'
                        : 'Message an admin for account, booking, or driver support.',
                    textAlign: TextAlign.center,
                    style: PassengerUi.bodyText,
                  ),
                  if (!isAdmin) ...<Widget>[
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canMessageAdmin && !_isOpeningChat
                            ? _openAdminChat
                            : null,
                        icon: _isOpeningChat
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PassengerUi.surface,
                                ),
                              )
                            : Icon(Icons.chat_bubble_outline_rounded),
                        label: Text(
                          _isOpeningChat ? 'Opening chat...' : 'Message Admin',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Contact Channels',
              style: PassengerUi.sectionTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            const _SupportContactCard(
              icon: Icons.facebook_rounded,
              title: 'Facebook',
              value: 'Facebook page coming soon',
            ),
            SizedBox(height: 12),
            const _SupportContactCard(
              icon: Icons.mail_outline_rounded,
              title: 'Gmail',
              value: 'support@sakaynow.example',
            ),
            SizedBox(height: 12),
            const _SupportContactCard(
              icon: Icons.phone_outlined,
              title: 'Phone Number',
              value: '+63 900 000 0000',
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SupportContactCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: PassengerUi.accentBlue),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: PassengerUi.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
