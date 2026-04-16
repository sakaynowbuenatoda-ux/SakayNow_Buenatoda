import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../pages/auth/login_page.dart';

class PassengerSignup extends StatefulWidget {
  const PassengerSignup({super.key});

  @override
  State<PassengerSignup> createState() => _PassengerSignupState();
}

class _PassengerSignupState extends State<PassengerSignup> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _agreeToPolicies = false;

  String? _gender;
  String _role = 'regular';
  File? _idFile;
  File? _selfieFile;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickId() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _idFile = File(file.path));
  }

  Future<void> _captureSelfie() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    setState(() => _selfieFile = File(file.path));
  }

  Future<String?> _uploadFile({
    required String uid,
    required File? file,
    required String fileName,
  }) async {
    if (file == null) return null;
    final ref = FirebaseStorage.instance.ref('users/$uid/$fileName');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  void _showPoliciesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Terms and Conditions & Privacy Policy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2432),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    '''
By creating an account, you agree to provide accurate information and valid documents for verification.

Your submitted information, uploaded identification, and selfie may be used for verification, security, fraud prevention, and platform-related operations.

SakayNow may review your submitted details before allowing access to certain services. False, misleading, or invalid information may result in denial, suspension, or removal of the account.

Your personal information will be handled with reasonable care and used only for legitimate platform-related purposes.

Replace this placeholder with your actual Terms and Conditions and Privacy Policy text.
                    ''',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4BDB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _currentStep = 0);
      return;
    }

    if (_idFile == null) {
      setState(() => _currentStep = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an ID.')),
      );
      return;
    }

    if (_selfieFile == null) {
      setState(() => _currentStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a live selfie.')),
      );
      return;
    }

    if (!_agreeToPolicies) {
      setState(() => _currentStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must agree to the Terms and Conditions and Privacy Policy.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      final idUrl = await _uploadFile(
        uid: uid,
        file: _idFile,
        fileName: 'id_upload.jpg',
      );
      final selfieUrl = await _uploadFile(
        uid: uid,
        file: _selfieFile,
        fileName: 'selfie.jpg',
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'user_id': uid,
        'email': _emailController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'gender': _gender,
        'role': _role,
        'id_image_url': idUrl,
        'selfie_url': selfieUrl,
        'nbi_clearance_url': null,
        'drivers_license_url': null,
        'isVerified': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      await cred.user?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passenger account created. Please log in from the login page.',
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Signup failed.';
      if (e.code == 'email-already-in-use') {
        message = 'That email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF5B4BDB), width: 1.4),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2432),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _uploadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required File? file,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF5B4BDB), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: Color(0xFF1E2432),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(file == null ? 'Choose file' : 'Replace file'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4BDB),
                side: const BorderSide(color: Color(0xFFD9DDF0)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                file,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      ('1', 'Basic Info'),
      ('2', 'ID Upload'),
      ('3', 'Selfie'),
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = _currentStep == index;
        final isDone = _currentStep > index;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive || isDone
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive || isDone
                          ? const Color(0xFFC7D2FE)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isDone || isActive
                            ? const Color(0xFF5B4BDB)
                            : const Color(0xFFD1D5DB),
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : Text(
                                steps[index].$1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? const Color(0xFF4338CA)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != steps.length - 1) const SizedBox(width: 10),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons() {
    final isLast = _currentStep == 2;

    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() => _currentStep -= 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : isLast && !_agreeToPolicies
                    ? null
                    : () {
                        if (isLast) {
                          _submit();
                        } else {
                          if (_currentStep == 0 &&
                              !(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setState(() => _currentStep += 1);
                        }
                      },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4BDB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Text(
                    isLast ? 'Create Account' : 'Continue',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoStep() {
    return _sectionCard(
      title: 'Basic Information',
      subtitle: 'Please enter your details accurately.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                label: 'Email',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: _inputDecoration(
                      label: 'First Name',
                      icon: Icons.person_outline,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: _inputDecoration(
                      label: 'Last Name',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      label: 'Age',
                      icon: Icons.cake_outlined,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: _inputDecoration(
                      label: 'Gender',
                      icon: Icons.wc_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                    validator: (value) =>
                        value == null ? 'Gender is required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: _inputDecoration(
                label: 'Passenger Type',
                icon: Icons.school_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'regular', child: Text('Regular')),
                DropdownMenuItem(value: 'student', child: Text('Student')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _role = value);
                }
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Password must be at least 8 characters'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: _inputDecoration(
                label: 'Confirm Password',
                icon: Icons.verified_user_outlined,
              ),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdStep() {
    return _sectionCard(
      title: 'ID Verification',
      subtitle: 'Upload a clear and readable school ID or valid government ID.',
      child: _uploadTile(
        title: 'Identification Upload',
        subtitle: 'Accepted: school ID or valid government-issued ID.',
        icon: Icons.badge_outlined,
        onTap: _pickId,
        file: _idFile,
      ),
    );
  }

  Widget _buildSelfieStep() {
    return _sectionCard(
      title: 'Selfie Verification',
      subtitle: 'Take a live selfie using your camera for identity checking.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF5B4BDB),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Camera only. Gallery images are not allowed for selfie verification.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _captureSelfie,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Capture Selfie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4BDB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_selfieFile != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selfieFile!,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: CheckboxListTile(
              value: _agreeToPolicies,
              onChanged: (value) {
                setState(() => _agreeToPolicies = value ?? false);
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF5B4BDB),
              title: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Color(0xFF374151),
                  ),
                  children: [
                    const TextSpan(
                      text:
                          'I agree to the Terms and Conditions and Privacy Policy ',
                    ),
                    TextSpan(
                      text: 'View',
                      style: const TextStyle(
                        color: Color(0xFF5B4BDB),
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = _showPoliciesSheet,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_agreeToPolicies)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 12),
              child: Text(
                'You must agree before creating an account.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFCFD),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEAECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Passenger Registration',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2432),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete the steps below to create your passenger account.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _buildStepIndicator(),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_currentStep),
                    child: Column(
                      children: [
                        if (_currentStep == 0) _buildBasicInfoStep(),
                        if (_currentStep == 1) _buildIdStep(),
                        if (_currentStep == 2) _buildSelfieStep(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
