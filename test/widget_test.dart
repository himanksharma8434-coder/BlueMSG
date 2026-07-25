import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitmsg/main.dart';
import 'package:bitmsg/protocol/identity/identity_storage.dart';
import 'package:bitmsg/services/mesh_service.dart';
import 'package:bitmsg/storage/database_helper.dart';
import 'package:bitmsg/transport/mock_transport.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('BitmsgApp renders onboarding when no identity exists', (WidgetTester tester) async {
    final dbHelper = DatabaseHelper(
      factory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    final identityStorage = InMemoryIdentityStorage();
    final mockTransport = MockTransport();

    final meshService = MeshService(
      identityStorage: identityStorage,
      dbHelper: dbHelper,
      customTransport: mockTransport,
    );

    await tester.pumpWidget(BitmsgApp(
      meshService: meshService,
      hasIdentity: false,
    ));

    // Wait for async identity generation in OnboardingScreen to complete
    await tester.pumpAndSettle();

    expect(find.text('Welcome to bitmsg'), findsOneWidget);
    expect(find.text('YOUR MESH IDENTITY'), findsOneWidget);
    expect(find.text('Join Mesh Network'), findsOneWidget);
  });
}
