import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';

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
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
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
            dialogBackgroundColor: const Color(0xFF1F1F1F),
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

        // 1. Create User in Auth
        final userCredential = await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (userCredential != null && userCredential.user != null) {
          // 2. Create User Model
          final newUser = UserModel(
            uid: userCredential.user!.uid,
            email: _emailController.text.trim(),
            username: _usernameController.text.trim(),
            fullName: _fullNameController.text.trim(),
            birthDate: _selectedDate!,
            createdAt: DateTime.now(),
          );

          // 3. Save to Firestore
          await databaseService.saveUser(newUser);

          // 4. Pop back to Login (AuthWrapper will handle navigation to Home)
          if (mounted) {
            Navigator.pop(context); 
          }
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your full name' : null,
                ),
                const SizedBox(height: 16),

                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a username' : null,
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
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your email' : null,
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
                  validator: (value) => value!.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
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
                const SizedBox(height: 32),

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
