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
  MeshIdentity? _generatedIdentity;
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _generateIdentity();
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
    await widget.meshService.setIdentity(_generatedIdentity!);
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
              const SizedBox(height: 20),
              // App Icon / Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  size: 40,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to bitmsg',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '100% Offline Bluetooth Mesh Messaging.\nNo internet, accounts, or central servers required.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Identity QR Code & Details Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
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
                                'YOUR MESH IDENTITY',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryCyan,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // QR Code container
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: QrImageView(
                                  data: _generatedIdentity!.deviceId,
                                  version: QrVersions.auto,
                                  size: 140.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Device ID pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fingerprint,
                                        size: 18, color: AppTheme.accentMint),
                                    const SizedBox(width: 8),
                                    Text(
                                      _generatedIdentity!.deviceId,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
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
                              const SizedBox(height: 12),
                              Text(
                                'Cryptographic keypair derived locally.\nShare this ID or QR code with nearby contacts.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(27),
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
