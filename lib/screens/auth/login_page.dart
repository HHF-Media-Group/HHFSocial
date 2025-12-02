import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'signup_page.dart';

import '../../utils/auth_exception_handler.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final authService = context.read<AuthService>();
        await authService.signInWithEmailAndPassword(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
        
        // Check Email Verification
        if (authService.currentUser != null && !authService.currentUser!.emailVerified) {
          await authService.signOut();
          setState(() {
            _errorMessage = "Please verify your email address to log in.";
          });
        }
        // Else: Navigation is handled by AuthWrapper
      } catch (e) {
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

  Future<void> _showForgotPasswordDialog(BuildContext parentContext) async {
    final TextEditingController resetEmailController = TextEditingController();
    final authService = parentContext.read<AuthService>();

    return showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address to receive a password reset link.',
                style: TextStyle(color: Color(0xFFE0E0E0)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter your email')),
                  );
                  return;
                }

                try {
                  Navigator.pop(dialogContext); // Close input dialog
                  await authService.sendPasswordResetEmail(email);
                  
                  if (parentContext.mounted) {
                    await showDialog(
                      context: parentContext, // Use parent context for success dialog
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF333333),
                        icon: const Icon(Icons.mark_email_read, size: 48, color: Color(0xFFF29F05)),
                        title: const Text('Check Your Email', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'We have sent a password reset link to $email.\n\nPlease check your inbox and spam folder.',
                          style: const TextStyle(color: Color(0xFFE0E0E0)),
                          textAlign: TextAlign.center,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK', style: TextStyle(color: Color(0xFFF29F05))),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(AuthExceptionHandler.generateErrorMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send Link', style: TextStyle(color: Color(0xFFF29F05))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or Title
                Image.asset(
                  'assets/icon.png',
                  height: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  'HHF Social',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),

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

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('LOGIN'),
                ),
                const SizedBox(height: 16),

                // Forgot Password
                TextButton(
                  onPressed: () {
                    _showForgotPasswordDialog(context);
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpPage()),
                        ).then((_) {
                          // Clear fields when returning from Sign Up
                          _emailController.clear();
                          _passwordController.clear();
                          setState(() {
                            _errorMessage = null;
                          });
                        });
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
