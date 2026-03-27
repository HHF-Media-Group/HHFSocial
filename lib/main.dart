import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_page.dart';
import 'screens/profile/profile_page.dart';
import 'screens/post/create_post_page.dart';
import 'screens/search/search_page.dart';
import 'screens/feed/feed_page.dart';
import 'models/post_model.dart';

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
              padding: const EdgeInsets.symmetric(vertical: 16),
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
      return const HomePage();
    }
    return const LoginPage();
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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      FeedPage(key: _feedKey),
      const SearchPage(),
      const SizedBox.shrink(),
      ProfilePage(key: _profileKey),
    ];
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Create Post - navigate to create page instead of switching tab
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
            // Refresh the profile grid and feed instantly
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
      _profileKey.currentState?.reload();
    }

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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 28),
              activeIcon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search, size: 28),
              activeIcon: Icon(Icons.search, size: 28),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined, size: 28),
              activeIcon: Icon(Icons.add_box, size: 28),
              label: 'Create',
            ),
            BottomNavigationBarItem(
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
