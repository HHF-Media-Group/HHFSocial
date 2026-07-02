import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'screens/auth/login_page.dart';
import 'screens/legal/terms_page.dart';
import 'screens/profile/profile_page.dart';
import 'screens/post/create_post_page.dart';
import 'screens/search/search_page.dart';
import 'screens/feed/feed_page.dart';
import 'screens/chat/inbox_page.dart';
import 'screens/notifications/notifications_page.dart';
import 'models/post_model.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HHFSocialApp());
}

class HHFSocialApp extends StatelessWidget {
  const HHFSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        StreamProvider(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'HHF Social',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1F1F1F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF29F05),
            surface: Color(0xFF333333),
            background: Color(0xFF1F1F1F),
            onPrimary: Colors.black,
            onSurface: Color(0xFFE0E0E0),
          ),
          textTheme: TextTheme(
            displayLarge: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            displayMedium: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            bodyLarge: GoogleFonts.roboto(color: const Color(0xFFE0E0E0)),
            bodyMedium: GoogleFonts.roboto(color: const Color(0xFFE0E0E0)),
            titleMedium: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF333333),
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF29F05), width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF29F05),
              foregroundColor: Colors.black,
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFF444444),
            thickness: 1,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();

    if (firebaseUser != null && firebaseUser.emailVerified) {
      return TermsGate(uid: firebaseUser.uid, child: const HomePage());
    }
    return const LoginPage();
  }
}

/// Blocks access to the app until the user has accepted the Terms of Use
/// (EULA). Covers accounts created before terms acceptance was added at
/// signup — required by App Store Guideline 1.2.
class TermsGate extends StatefulWidget {
  final String uid;
  final Widget child;

  const TermsGate({super.key, required this.uid, required this.child});

  @override
  State<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<TermsGate> {
  bool _isLoading = true;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _checkAcceptance();
  }

  Future<void> _checkAcceptance() async {
    final user = await DatabaseService().getUser(widget.uid);
    if (mounted) {
      setState(() {
        // If the user doc is missing, don't lock the account out —
        // acceptance was already required at signup.
        _accepted = user == null || user.termsAcceptedAt != null;
        _isLoading = false;
      });
    }
  }

  Future<void> _accept() async {
    await DatabaseService().updateUserProfile(widget.uid, {
      'termsAcceptedAt': Timestamp.now(),
    });
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF29F05)),
        ),
      );
    }
    if (!_accepted) {
      return TermsPage(
        requireAcceptance: true,
        onAccepted: _accept,
        onDeclined: () => context.read<AuthService>().signOut(),
      );
    }
    return widget.child;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();
  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();
  final GlobalKey<NotificationsPageState> _notifKey = GlobalKey<NotificationsPageState>();
  final GlobalKey<InboxPageState> _inboxKey = GlobalKey<InboxPageState>();
  int _unreadCount = 0;
  int _unreadMessages = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      FeedPage(key: _feedKey),
      const SearchPage(),
      const SizedBox.shrink(), // Create placeholder
      InboxPage(key: _inboxKey),
      NotificationsPage(key: _notifKey),
      ProfilePage(key: _profileKey),
    ];
    _refreshUnreadCount();
    _refreshUnreadMessages();
  }

  void _refreshUnreadCount() async {
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final count = await NotificationService().getUnreadCount(uid);
    if (mounted) setState(() => _unreadCount = count);
  }

  void _refreshUnreadMessages() async {
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final count = await ChatService().getTotalUnreadCount(uid);
    if (mounted) setState(() => _unreadMessages = count);
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Create Post
      final authService = context.read<AuthService>();
      final uid = authService.currentUser?.uid;
      if (uid != null) {
        Navigator.push<PostModel>(
          context,
          MaterialPageRoute(
            builder: (context) => CreatePostPage(uid: uid),
          ),
        ).then((newPost) {
          if (newPost != null) {
            _profileKey.currentState?.addPost(newPost);
            _feedKey.currentState?.reload();
          }
        });
      }
      return;
    }

    // Reload data when switching to a tab
    if (index == 0) {
      _feedKey.currentState?.reload();
    } else if (index == 3) {
      _inboxKey.currentState?.reload();
      // Clear badge when viewing messages
      setState(() => _unreadMessages = 0);
    } else if (index == 4) {
      _notifKey.currentState?.reload();
      // Clear badge when viewing notifications
      setState(() => _unreadCount = 0);
    } else if (index == 5) {
      _profileKey.currentState?.reload();
    }

    // Refresh badges on every tab switch
    if (index != 4) _refreshUnreadCount();
    if (index != 3) _refreshUnreadMessages();

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF333333), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: const Color(0xFF1F1F1F),
          selectedItemColor: const Color(0xFFF29F05),
          unselectedItemColor: Colors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 28),
              activeIcon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search, size: 28),
              activeIcon: Icon(Icons.search, size: 28),
              label: 'Search',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined, size: 28),
              activeIcon: Icon(Icons.add_box, size: 28),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 26),
                  if (_unreadMessages > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF29F05),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.chat_bubble, size: 26),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.favorite_border, size: 28),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF29F05),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.favorite, size: 28),
              label: 'Notifications',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 28),
              activeIcon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
