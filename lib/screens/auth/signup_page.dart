import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../utils/validators.dart';
import '../legal/terms_page.dart';

import '../../utils/auth_exception_handler.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  String? _errorMessage;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFF29F05),
              onPrimary: Colors.black,
              surface: const Color(0xFF333333),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1F1F1F),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        setState(() {
          _errorMessage = "Please select your birth date";
        });
        return;
      }

      // Terms of Use (EULA) agreement is required
      if (!_agreedToTerms) {
        setState(() {
          _errorMessage =
              "You must agree to the Terms of Use (EULA) to create an account.";
        });
        return;
      }

      // Age Validation: Must be at least 18
      final DateTime now = DateTime.now();
      final DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
      if (_selectedDate!.isAfter(eighteenYearsAgo)) {
        setState(() {
          _errorMessage = "You must be at least 18 years old to sign up.";
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final authService = context.read<AuthService>();
        final databaseService = DatabaseService();
        final username = _usernameController.text.trim().toLowerCase();

        print('DEBUG SIGNUP: Step 1 - Checking username availability');
        // 1. Check if username is available (public read - no auth needed)
        final isTaken = await databaseService.isUsernameTaken(username);
        print('DEBUG SIGNUP: Username taken: $isTaken');
        if (isTaken) {
          setState(() {
            _errorMessage = "Username is already taken. Please choose another.";
            _isLoading = false;
          });
          return;
        }

        print('DEBUG SIGNUP: Step 2 - Creating Auth user');
        // 2. Create User in Auth
        final userCredential = await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        print('DEBUG SIGNUP: Auth user created: ${userCredential?.user?.uid}');

        if (userCredential != null && userCredential.user != null) {
          final uid = userCredential.user!.uid;

          print('DEBUG SIGNUP: Step 3 - Reserving username');
          // 3. Reserve the username (now authenticated, can write)
          try {
            await databaseService.reserveUsername(username, uid);
            print('DEBUG SIGNUP: Username reserved');
          } catch (e) {
            print('DEBUG SIGNUP: Username reservation failed: $e');
            await authService.deleteUser();
            throw Exception("Failed to reserve username. Please try again.");
          }

          // 4. Create User Model
          final newUser = UserModel(
            uid: uid,
            email: _emailController.text.trim(),
            username: username,
            fullName: _fullNameController.text.trim(),
            birthDate: _selectedDate!,
            createdAt: DateTime.now(),
            termsAcceptedAt: DateTime.now(),
          );

          print('DEBUG SIGNUP: Step 4 - Saving to Firestore');
          // 5. Save to Firestore (with Rollback)
          try {
            await databaseService.saveUser(newUser);
            print('DEBUG SIGNUP: User saved to Firestore');
          } catch (e) {
            print('DEBUG SIGNUP: Firestore save failed: $e');
            // Rollback: Delete username and auth user
            await databaseService.releaseUsername(username);
            await authService.deleteUser();
            throw Exception("Failed to save user profile. Please try again.");
          }

          print('DEBUG SIGNUP: Step 4 - Sending verification email');
          // 5. Send Verification Email
          await authService.sendEmailVerification();

          // 6. Sign Out to prevent auto-login
          await authService.signOut();

          if (mounted) {
            // 7. Show Dialog and Navigate
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF333333),
                title: const Text('Verify Your Email', style: TextStyle(color: Colors.white)),
                content: const Text(
                  'Account created successfully! Please check your email to verify your account before logging in.',
                  style: TextStyle(color: Color(0xFFE0E0E0)),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to Login
                    },
                    child: const Text('OK', style: TextStyle(color: Color(0xFFF29F05))),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        print('DEBUG SIGNUP: Error caught: $e');
        setState(() {
          _errorMessage = AuthExceptionHandler.generateErrorMessage(e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          // Extra bottom padding keeps the button clear of the system
          // navigation bar on edge-to-edge Android
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join HHF Social',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Error Message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.validateFullName,
                ),
                const SizedBox(height: 16),

                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'letters, numbers, underscores',
                  ),
                  validator: Validators.validateUsername,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) => value!.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Birth Date
                TextFormField(
                  controller: _birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Birth Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator: (value) =>
                      value!.isEmpty ? 'Please select your birth date' : null,
                ),
                const SizedBox(height: 24),

                // Terms of Use (EULA) agreement
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: const Color(0xFFF29F05),
                        checkColor: Colors.black,
                        side: BorderSide(color: Colors.grey[500]!),
                        onChanged: (value) {
                          setState(() => _agreedToTerms = value ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                setState(() => _agreedToTerms = !_agreedToTerms),
                          children: [
                            TextSpan(
                              text: 'Terms of Use (EULA)',
                              style: const TextStyle(
                                color: Color(0xFFF29F05),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const TermsPage()),
                                  );
                                },
                            ),
                            TextSpan(
                              text: ' and ',
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => setState(
                                    () => _agreedToTerms = !_agreedToTerms),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: Color(0xFFF29F05),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final uri = Uri.parse(
                                      'https://hhf-social.web.app/privacy-policy.html');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                            ),
                            TextSpan(
                              text:
                                  '. I understand there is zero tolerance for objectionable content or abusive users.',
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => setState(
                                    () => _agreedToTerms = !_agreedToTerms),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('SIGN UP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
