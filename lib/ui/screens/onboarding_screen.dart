import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../protocol/identity/mesh_identity.dart';
import '../../services/mesh_service.dart';
import '../theme/app_theme.dart';
import 'conversation_list_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final MeshService meshService;

  const OnboardingScreen({super.key, required this.meshService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  MeshIdentity? _generatedIdentity;
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _generateIdentity();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _generateIdentity() async {
    final identity = await MeshIdentity.generate();
    if (mounted) {
      setState(() {
        _generatedIdentity = identity;
        _isGenerating = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_generatedIdentity == null) return;
    final nicknameText = _nicknameController.text.trim();
    final nickname = nicknameText.isNotEmpty
        ? nicknameText
        : 'User-${_generatedIdentity!.deviceId.substring(0, 4)}';

    final updatedIdentity = _generatedIdentity!.copyWith(nickname: nickname);
    await widget.meshService.setIdentity(updatedIdentity);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConversationListScreen(meshService: widget.meshService),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // App Icon / Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  size: 36,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Welcome to bitmsg',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '100% Offline Bluetooth Mesh Messaging.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),

              // Identity QR Code & Details Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: _isGenerating
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'CHOOSE YOUR DISPLAY USERNAME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryCyan,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Username Input Field
                              TextField(
                                controller: _nicknameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter nickname (e.g. Alice)',
                                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryCyan),
                                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),

                              // QR Code container
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: QrImageView(
                                  data: _generatedIdentity!.deviceId,
                                  version: QrVersions.auto,
                                  size: 130.0,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Device ID pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fingerprint,
                                        size: 16, color: AppTheme.accentMint),
                                    const SizedBox(width: 6),
                                    Text(
                                      _generatedIdentity!.deviceId,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 14),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                          text: _generatedIdentity!.deviceId,
                                        ));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Device ID copied to clipboard'),
                                          ),
                                        );
                                      },
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        'Join Mesh Network',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
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
}
