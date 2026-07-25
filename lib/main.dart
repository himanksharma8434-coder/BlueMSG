import 'package:flutter/material.dart';
import 'services/mesh_service.dart';
import 'ui/screens/conversation_list_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final meshService = MeshService();
  final hasIdentity = await meshService.initialize();

  runApp(BitmsgApp(meshService: meshService, hasIdentity: hasIdentity));
}

class BitmsgApp extends StatelessWidget {
  final MeshService meshService;
  final bool hasIdentity;

  const BitmsgApp({
    super.key,
    required this.meshService,
    required this.hasIdentity,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bitmsg Mesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: hasIdentity
          ? ConversationListScreen(meshService: meshService)
          : OnboardingScreen(meshService: meshService),
    );
  }
}
