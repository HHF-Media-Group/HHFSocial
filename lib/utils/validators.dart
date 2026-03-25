/// Utility class for form field validation
/// Provides world-class validation with clear, user-friendly error messages
class Validators {
  // RFC 5322 compliant email regex (simplified but robust)
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  // Username regex: alphanumeric, underscores, periods (3-30 chars)
  static final RegExp _usernameRegex = RegExp(
    r'^[a-zA-Z0-9._]{3,30}$',
  );

  /// Validates email address format
  /// Returns null if valid, error message if invalid
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    
    final trimmed = value.trim();
    
    if (!trimmed.contains('@')) {
      return 'Please enter a valid email address';
    }
    
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    
    // Check for common typos
    final domain = trimmed.split('@').last.toLowerCase();
    final commonDomains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com'];
    final typos = {
      'gmial.com': 'gmail.com',
      'gmai.com': 'gmail.com',
      'gamil.com': 'gmail.com',
      'gmail.co': 'gmail.com',
      'yaho.com': 'yahoo.com',
      'yahooo.com': 'yahoo.com',
      'hotmal.com': 'hotmail.com',
      'outlok.com': 'outlook.com',
    };
    
    if (typos.containsKey(domain)) {
      return 'Did you mean ${trimmed.split('@').first}@${typos[domain]}?';
    }
    
    return null;
  }

  /// Validates password strength
  /// Returns null if valid, error message if invalid
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    // Optional: Add stronger password requirements
    // if (!value.contains(RegExp(r'[A-Z]'))) {
    //   return 'Password must contain at least one uppercase letter';
    // }
    // if (!value.contains(RegExp(r'[0-9]'))) {
    //   return 'Password must contain at least one number';
    // }
    
    return null;
  }

  /// Validates username format
  /// Returns null if valid, error message if invalid
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    
    final trimmed = value.trim().toLowerCase();
    
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (trimmed.length > 30) {
      return 'Username must be less than 30 characters';
    }
    
    if (!_usernameRegex.hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, underscores, and periods';
    }
    
    if (trimmed.startsWith('.') || trimmed.endsWith('.')) {
      return 'Username cannot start or end with a period';
    }
    
    if (trimmed.contains('..')) {
      return 'Username cannot contain consecutive periods';
    }
    
    return null;
  }

  /// Validates full name
  /// Returns null if valid, error message if invalid
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    
    if (value.trim().length < 2) {
      return 'Please enter a valid name';
    }
    
    return null;
  }

  /// Validates confirm password matches original
  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  /// Validates bio (optional, max 150 characters)
  static String? validateBio(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Bio is optional
    }
    
    if (value.length > 150) {
      return 'Bio must be 150 characters or less';
    }
    
    return null;
  }

  /// Validates website URL (optional, must be valid URL if provided)
  static String? validateWebsite(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Website is optional
    }
    
    final trimmed = value.trim();
    
    // Basic URL pattern check
    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-._~:\/?#\[\]@!$&()*+,;=]*)?$',
      caseSensitive: false,
    );
    
    if (!urlRegex.hasMatch(trimmed)) {
      return 'Please enter a valid URL';
    }
    
    return null;
  }
}
