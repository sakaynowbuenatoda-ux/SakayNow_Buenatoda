import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/registration_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/registration_image_preview.dart';

class PassengerDocumentVerificationPage extends StatefulWidget {
  final String userId;

  const PassengerDocumentVerificationPage({super.key, required this.userId});

  @override
  State<PassengerDocumentVerificationPage> createState() =>
      _PassengerDocumentVerificationPageState();
}

class _PassengerDocumentVerificationPageState
    extends State<PassengerDocumentVerificationPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isVerified = false;
  String _uploadStatus = 'none';
  String _passengerType = 'regular';

  RegistrationImageSelection? _idFile;
  RegistrationImageSelection? _selfieFile;

  @override
  void initState() {
    super.initState();
    _loadUserVerificationState();
  }

  Future<void> _loadUserVerificationState() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _isVerified =
              data['is_verified'] == true || data['isVerified'] == true;
          _uploadStatus = data['document_upload_status'] as String? ?? 'none';
          _passengerType = data['passenger_type'] as String? ?? 'regular';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickIdImage() async {
    final selection = await _pickImage(ImageSource.gallery);
    if (selection != null && mounted) {
      setState(() => _idFile = selection);
    }
  }

  Future<void> _captureSelfie() async {
    final selection = await _pickImage(ImageSource.camera);
    if (selection != null && mounted) {
      setState(() => _selfieFile = selection);
    }
  }

  Future<RegistrationImageSelection?> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return null;
      return await RegistrationImageSelection.fromXFile(file);
    } on PlatformException {
      _showSnackBar(
        source == ImageSource.camera
            ? 'Unable to open camera. Please check app permissions.'
            : 'Unable to open gallery. Please check app permissions.',
      );
    } on RegistrationImageSelectionException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Unable to load image. Please try another file.');
    }
    return null;
  }

  Future<void> _uploadDocuments() async {
    if (_idFile == null && _selfieFile == null) {
      _showSnackBar('Please select at least an ID photo or selfie to upload.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final updates = <String, dynamic>{};
      final storage = FirebaseStorage.instance;

      if (_idFile != null) {
        final idRef = storage.ref('users/${widget.userId}/id_upload.jpg');
        await idRef.putData(
          _idFile!.bytes,
          SettableMetadata(
            contentType: _idFile!.contentType,
            customMetadata: {
              'owner_id': widget.userId,
              'field_name': 'id_image_url',
            },
          ),
        );
        updates['id_image_url'] = await idRef.getDownloadURL();
      }

      if (_selfieFile != null) {
        final selfieRef = storage.ref('users/${widget.userId}/selfie.jpg');
        await selfieRef.putData(
          _selfieFile!.bytes,
          SettableMetadata(
            contentType: _selfieFile!.contentType,
            customMetadata: {
              'owner_id': widget.userId,
              'field_name': 'selfie_url',
            },
          ),
        );
        updates['selfie_url'] = await selfieRef.getDownloadURL();
      }

      updates['document_upload_status'] = 'uploaded';
      updates['document_upload_error'] = FieldValue.delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(updates);

      if (!mounted) return;
      setState(() {
        _uploadStatus = 'uploaded';
        _isUploading = false;
        _idFile = null;
        _selfieFile = null;
      });
      _showSnackBar('Verification documents uploaded successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showSnackBar(
        userFacingErrorMessage(
          e,
          fallback:
              'Failed to upload verification documents. Please try again.',
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Document & ID Verification', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    _buildUploadSection(
                      title: 'School or Government ID',
                      subtitle:
                          'Select a clear, readable photo of your Student or Senior Citizen ID.',
                      icon: Icons.upload_file_rounded,
                      buttonText: _idFile == null
                          ? 'Choose ID Photo'
                          : 'Change Photo',
                      onTap: _isUploading ? null : _pickIdImage,
                      file: _idFile,
                    ),
                    const SizedBox(height: 16),
                    _buildUploadSection(
                      title: 'Live Selfie Photo',
                      subtitle:
                          'Take a clean portrait photo using your device camera for facial recognition.',
                      icon: Icons.camera_alt_outlined,
                      buttonText: _selfieFile == null
                          ? 'Capture Selfie'
                          : 'Recapture Selfie',
                      onTap: _isUploading ? null : _captureSelfie,
                      file: _selfieFile,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_idFile == null && _selfieFile == null) ||
                                _isUploading
                            ? null
                            : _uploadDocuments,
                        icon: _isUploading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _isUploading
                              ? 'Uploading Documents...'
                              : 'Submit Verification Documents',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PassengerUi.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    String statusLabel = 'Pending Submission';

    if (_isVerified) {
      statusLabel = 'Verified';
    } else if (_uploadStatus == 'uploaded') {
      statusLabel = 'In Review (Uploaded)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PassengerUi.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              _isVerified
                  ? Icons.verified_rounded
                  : Icons.pending_actions_rounded,
              color: PassengerUi.dark,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Status: $statusLabel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PassengerUi.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registered Passenger Type: ${_passengerType.toUpperCase()}',
                  style: TextStyle(fontSize: 13, color: PassengerUi.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonText,
    required VoidCallback? onTap,
    required RegistrationImageSelection? file,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PassengerUi.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PassengerUi.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: PassengerUi.body),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(buttonText),
              style: OutlinedButton.styleFrom(
                foregroundColor: PassengerUi.primary,
                side: BorderSide(color: PassengerUi.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: 14),
            RegistrationImagePreview(
              selection: file,
              height: 200,
              borderRadius: 12,
            ),
          ],
        ],
      ),
    );
  }
}
