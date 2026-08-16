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

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  MeshIdentity? _generatedIdentity;
  bool _isGenerating = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _generateIdentity();
  }

  @override
  void dispose() {
    _animController.dispose();
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
      _animController.forward();
    }
  }

  Future<void> _completeOnboarding() async {
    if (_generatedIdentity == null) return;
    HapticFeedback.mediumImpact();

    final nicknameText = _nicknameController.text.trim();
    final nickname = nicknameText.isNotEmpty
        ? nicknameText
        : 'User-${_generatedIdentity!.deviceId.substring(0, 4)}';

    final updatedIdentity = _generatedIdentity!.copyWith(nickname: nickname);
    await widget.meshService.setIdentity(updatedIdentity);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, anim, secondaryAnim) => FadeTransition(
            opacity: anim,
            child: ConversationListScreen(meshService: widget.meshService),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1527), AppTheme.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // App Logo with glowing shadow
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cyanGlow(blur: 18, opacity: 0.45),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to bitmsg',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '100% Offline Bluetooth Mesh Messaging.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),

                // Main Identity Card
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) => FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: AppTheme.glassDecoration(
                        borderRadius: 24,
                        borderColor: AppTheme.cardBorder,
                      ),
                      child: _isGenerating
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: AppTheme.primaryCyan,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Generating cryptographic identity...',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.shield_outlined,
                                        size: 14,
                                        color: AppTheme.primaryCyan,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'CHOOSE YOUR DISPLAY NAME',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryCyan,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Username Input Field
                                  TextField(
                                    controller: _nicknameController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter nickname (e.g. Alice)',
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                        color: AppTheme.primaryCyan,
                                      ),
                                      hintStyle: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // QR Code container with rounded glow border
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryCyan
                                              .withValues(alpha: 0.15),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
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
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: AppTheme.cardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.fingerprint,
                                          size: 16,
                                          color: AppTheme.accentMint,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _generatedIdentity!.deviceId,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            Clipboard.setData(ClipboardData(
                                              text:
                                                  _generatedIdentity!.deviceId,
                                            ));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Device ID copied to clipboard',
                                                ),
                                                duration:
                                                    Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: const Icon(
                                            Icons.copy,
                                            size: 15,
                                            color: AppTheme.primaryCyan,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Join Button
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
                        boxShadow: AppTheme.cyanGlow(blur: 14, opacity: 0.35),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Join Mesh Network',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
