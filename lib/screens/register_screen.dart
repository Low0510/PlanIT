import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planit_schedule_manager/widgets/glassmorphic_animated_background.dart';
import 'package:planit_schedule_manager/widgets/terms_privacy_widget.dart';
import 'package:planit_schedule_manager/widgets/main_layout.dart';
import '../services/authentication_service.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _agreedToTerms = false;
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassmorphicAnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 32),
                    _buildInputFields(),
                    SizedBox(height: 24),
                    // _buildTermsAgreement(),
                    TermsAndPrivacyWidget(
                      onAgreementChanged: (agreed) {
                        setState(() {
                          _agreedToTerms = agreed;
                        });
                      },
                    ),
                    SizedBox(height: 32),
                    _buildCreateAccountButton(),
                    SizedBox(height: 16),
                    _buildLoginPrompt(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sign up now to get started with an account. Time Is Money!',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInputField(firstNameController, 'First Name', Icons.person_outline)),
            SizedBox(width: 16),
            Expanded(child: _buildInputField(lastNameController, 'Last Name', Icons.person_outline)),
          ],
        ),
        SizedBox(height: 16),
        _buildInputField(usernameController, 'Username', Icons.account_circle_outlined),
        SizedBox(height: 16),
        _buildInputField(emailController, 'E-Mail', Icons.email_outlined),
        SizedBox(height: 16),
        _buildInputField(phoneController, 'Phone Number', Icons.phone_outlined),
        SizedBox(height: 16),
        _buildPasswordField(),
      ],
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label is required.';
        }
        if (label == 'E-Mail' && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Enter a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).primaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required.';
        }
        if (value.length < 8) {
          return 'At least 8 characters long.';
        }
        if (!RegExp(r'(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[!@#\$&*~])').hasMatch(value)) {
          return 'Include uppercase, lowercase, number, and special character.';
        }
        return null;
      },
    );
  }


  Widget _buildCreateAccountButton() {
    return ElevatedButton(
      onPressed: _agreedToTerms ? _handleRegistration : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Create Account', style: TextStyle(fontSize: 18)),
      ),
      style: ElevatedButton.styleFrom(
        // primary: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }


  Widget _buildSocialButton(IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // Add social sign-up logic here
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
        ),
        child: FaIcon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account?'),
        TextButton(
          onPressed: () {
            // Navigate to login screen
            Navigator.pop(context);
          },
          child: Text('Log In', style: TextStyle(color: Theme.of(context).primaryColor)),
        ),
      ],
    );
  }

 void _handleRegistration() async {
  if (_formKey.currentState!.validate()) {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Registration Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Colors.blue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loading Indicator
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loading Text
                  const Text(
                    'Creating Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait while we set up your account...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Attempt registration
      User? user = await AuthenticationService().register(
        email: emailController.text,
        password: passwordController.text,
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        username: usernameController.text,
        phone: phoneController.text,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (user != null) {
        await AuthenticationService().setFirstTimeFalse();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainLayout(user: user)),
          (Route<dynamic> route) => false,
        );
        SuccessToast.show(context, 'Registration successful!');
      } else {
        _showErrorMessage('Registration failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      // Close loading dialog if it's showing
      Navigator.of(context).pop();
      
      String errorMessage = _getErrorMessage(e);
      _showErrorMessage(errorMessage);
    } catch (e) {
      // Close loading dialog if it's showing
      Navigator.of(context).pop();
      
      _showErrorMessage('An unexpected error occurred: $e');
    }
  }
}

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'operation-not-allowed':
        return 'Account creation is currently disabled. Please try again later.';
      default:
        return 'Registration error: ${e.message}';
    }
  }

  void _showErrorMessage(String message) {
    ErrorToast.show(context, message);
  }
}