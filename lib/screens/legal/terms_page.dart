import 'package:flutter/material.dart';

/// Terms of Use (EULA) page.
///
/// Read-only by default (opened from signup, login, or settings).
/// With [requireAcceptance] it shows an Accept button and is used as a
/// blocking gate for accounts that have not yet accepted the terms.
class TermsPage extends StatelessWidget {
  final bool requireAcceptance;
  final Future<void> Function()? onAccepted;
  final VoidCallback? onDeclined;

  const TermsPage({
    super.key,
    this.requireAcceptance = false,
    this.onAccepted,
    this.onDeclined,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        automaticallyImplyLeading: !requireAcceptance,
        title: const Text(
          'Terms of Use (EULA)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // In read-only mode there is no bottom bar, so pad the scroll
              // end past the system navigation bar (edge-to-edge Android)
              padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  requireAcceptance
                      ? 20
                      : 20 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title('HHF Social — Terms of Use (End User License Agreement)'),
                  _text('Last updated: July 3, 2026'),
                  _section('1. Acceptance of Terms'),
                  _text(
                    'By creating an account or using HHF Social ("the App"), you agree to be bound by these Terms of Use. If you do not agree, do not use the App.',
                  ),
                  _section('2. Eligibility'),
                  _text(
                    'You must be at least 18 years old to use HHF Social. By registering, you confirm that you meet this age requirement.',
                  ),
                  _section('3. Zero Tolerance for Objectionable Content and Abusive Users'),
                  _text(
                    'HHF Social has ZERO TOLERANCE for objectionable content and abusive behavior. You may not post, share, or send content that includes:\n\n'
                    '•  Nudity, pornography, or sexually explicit material\n'
                    '•  Harassment, bullying, or threats toward any person\n'
                    '•  Hate speech or discrimination of any kind\n'
                    '•  Violence, gore, or content that promotes harm\n'
                    '•  Spam, scams, or deceptive content\n'
                    '•  Illegal content or content that promotes illegal activity\n\n'
                    'Violating this policy will result in removal of the content and permanent termination of your account.',
                  ),
                  _section('4. Content Moderation'),
                  _text(
                    'To keep the community safe, HHF Social provides:\n\n'
                    '•  Content filtering that screens posts and comments\n'
                    '•  A flagging mechanism to report objectionable posts, comments, messages, and users\n'
                    '•  A blocking mechanism that instantly removes a blocked user\'s content from your feed\n\n'
                    'We review all reports within 24 hours. Content that violates these terms will be removed, and the user who provided it will be ejected from the App.',
                  ),
                  _section('5. Your Content'),
                  _text(
                    'You retain ownership of the content you post, but you are solely responsible for it. By posting, you confirm your content complies with these Terms and grant HHF Social a license to display it within the App.',
                  ),
                  _section('6. Termination'),
                  _text(
                    'We may suspend or permanently terminate your account without prior notice if you violate these Terms, including any instance of posting objectionable content or abusive behavior.',
                  ),
                  _section('7. Privacy'),
                  _text(
                    'Your use of the App is also governed by our Privacy Policy, available at https://hhf-social.web.app/privacy-policy.html.',
                  ),
                  _section('8. Changes to These Terms'),
                  _text(
                    'We may update these Terms from time to time. Continued use of the App after changes take effect constitutes acceptance of the revised Terms.',
                  ),
                  _section('9. Contact'),
                  _text(
                    'Questions about these Terms or reports of objectionable content can be sent to the developer through the App\'s reporting tools.',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (requireAcceptance)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                border: Border(top: BorderSide(color: Color(0xFF333333))),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AcceptButton(onAccepted: onAccepted),
                    if (onDeclined != null)
                      TextButton(
                        onPressed: onDeclined,
                        child: Text(
                          'Decline and sign out',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFF29F05),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _text(String text) => Text(
        text,
        style: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.5),
      );
}

class _AcceptButton extends StatefulWidget {
  final Future<void> Function()? onAccepted;

  const _AcceptButton({this.onAccepted});

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isAccepting
          ? null
          : () async {
              setState(() => _isAccepting = true);
              try {
                await widget.onAccepted?.call();
              } finally {
                if (mounted) setState(() => _isAccepting = false);
              }
            },
      child: _isAccepting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : const Text('AGREE & CONTINUE'),
    );
  }
}
