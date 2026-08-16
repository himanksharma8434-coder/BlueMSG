import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitmsg/protocol/identity/identity_storage.dart';
import 'package:bitmsg/protocol/identity/mesh_identity.dart';
import 'package:bitmsg/protocol/models/crisis_supply_payload.dart';
import 'package:bitmsg/services/mesh_service.dart';
import 'package:bitmsg/storage/database_helper.dart';
import 'package:bitmsg/transport/mock_transport.dart';

void main() {
  sqfliteFfiInit();

  group('CrisisSupplyPayload Unit Tests', () {
    test('Creates and serializes/deserializes valid crisis supply request', () {
      final payload = CrisisSupplyPayload.create(
        type: CrisisRequestType.request,
        category: DisasterSupplyCategory.medical,
        title: 'Need Insulin and Sterile Gauze',
        details: 'Type 1 diabetic patient requiring cold insulin',
        urgency: CrisisUrgency.critical,
        adultsCount: 2,
        childrenCount: 1,
        injuredCount: 1,
        locationDescription: 'St. Mary High School Shelter, Room 204',
        contactName: 'Alice',
        senderId: 'device-alice-1234',
        neededItems: ['Insulin (100u)', 'Sterile Gauze', 'Antiseptic'],
      );

      expect(payload.category, DisasterSupplyCategory.medical);
      expect(payload.type, CrisisRequestType.request);
      expect(payload.urgency, CrisisUrgency.critical);
      expect(payload.totalPeople, 3);
      expect(payload.injuredCount, 1);
      expect(payload.neededItems.length, 3);

      final json = payload.toJson();
      expect(json['category'], 'medical');
      expect(json['type'], 'request');
      expect(json['urgency'], 'critical');

      final reconstructed = CrisisSupplyPayload.fromJson(json);
      expect(reconstructed.id, payload.id);
      expect(reconstructed.category, DisasterSupplyCategory.medical);
      expect(reconstructed.title, payload.title);
      expect(reconstructed.locationDescription, payload.locationDescription);
      expect(reconstructed.neededItems, payload.neededItems);
    });

    test('toEncodedMessage and tryParse round-trip correctly', () {
      final payload = CrisisSupplyPayload.create(
        type: CrisisRequestType.offer,
        category: DisasterSupplyCategory.water,
        title: '100 Litres Clean Drinking Water Available',
        details: 'Purified water distribution point open until 6 PM',
        urgency: CrisisUrgency.standard,
        locationDescription: 'Town Hall Main Entrance',
        contactName: 'Rescue Team Delta',
        senderId: 'device-team-delta',
        neededItems: ['Potable Water', 'Water Purification Tablets'],
      );

      final encoded = payload.toEncodedMessage();
      expect(encoded.startsWith(CrisisSupplyPayload.protocolPrefix), isTrue);

      final parsed = CrisisSupplyPayload.tryParse(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.category, DisasterSupplyCategory.water);
      expect(parsed.type, CrisisRequestType.offer);
      expect(parsed.urgency, CrisisUrgency.standard);
      expect(parsed.title, '100 Litres Clean Drinking Water Available');
      expect(parsed.neededItems, contains('Potable Water'));
    });

    test('tryParse safely handles non-crisis raw messages without throwing', () {
      expect(CrisisSupplyPayload.tryParse('Hello world!'), isNull);
      expect(CrisisSupplyPayload.tryParse(''), isNull);
      expect(CrisisSupplyPayload.tryParse('{"invalid": "json"}'), isNull);
      expect(CrisisSupplyPayload.tryParse('[CRISIS_RELIEF_V1]:invalid_json'), isNull);
    });

    test('Category and Urgency helpers provide accurate labels and icons', () {
      expect(DisasterSupplyCategory.medical.label, contains('Medical'));
      expect(DisasterSupplyCategory.food.label, contains('Food'));
      expect(DisasterSupplyCategory.water.label, contains('Water'));
      expect(DisasterSupplyCategory.shelter.label, contains('Shelter'));
      expect(DisasterSupplyCategory.rescue.label, contains('Rescue'));
      expect(DisasterSupplyCategory.power.label, contains('Power'));

      expect(DisasterSupplyCategory.medical.emoji, '💊');
      expect(DisasterSupplyCategory.food.emoji, '🥫');
      expect(DisasterSupplyCategory.water.emoji, '💧');
      expect(DisasterSupplyCategory.rescue.emoji, '🆘');

      expect(DisasterSupplyCategory.fromString('medical'), DisasterSupplyCategory.medical);
      expect(DisasterSupplyCategory.fromString('unknown_category'), DisasterSupplyCategory.other);

      expect(CrisisUrgency.fromString('critical'), CrisisUrgency.critical);
      expect(CrisisUrgency.fromString('urgent'), CrisisUrgency.urgent);
      expect(CrisisUrgency.fromString('unknown'), CrisisUrgency.standard);
    });

    test('Human readable summary contains all vital emergency parameters', () {
      final payload = CrisisSupplyPayload.create(
        type: CrisisRequestType.request,
        category: DisasterSupplyCategory.food,
        title: 'Baby formula needed',
        details: 'Infant 4 months old',
        urgency: CrisisUrgency.urgent,
        adultsCount: 1,
        childrenCount: 1,
        locationDescription: 'Block 4 Community Shelter',
        contactName: 'Bob',
        senderId: 'device-bob',
        neededItems: ['Baby Formula Stage 1', 'Clean Bottles'],
      );

      final summary = payload.toHumanReadableSummary();
      expect(summary, contains('🥫'));
      expect(summary, contains('Baby formula needed'));
      expect(summary, contains('Block 4 Community Shelter'));
      expect(summary, contains('Baby Formula Stage 1'));
      expect(summary, contains('2 people'));
    });
  });

  group('MeshService Crisis Supply Integration Tests', () {
    late DatabaseHelper dbHelper;
    late InMemoryIdentityStorage identityStorage;
    late MockTransport mockTransport;
    late MeshService meshService;

    setUp(() async {
      dbHelper = DatabaseHelper(
        factory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      identityStorage = InMemoryIdentityStorage();
      mockTransport = MockTransport();

      final testIdentity = await MeshIdentity.generate(nickname: 'CrisisResponder');
      await identityStorage.saveIdentity(testIdentity);

      meshService = MeshService(
        identityStorage: identityStorage,
        dbHelper: dbHelper,
        customTransport: mockTransport,
      );
      await meshService.initialize();
    });

    tearDown(() async {
      meshService.dispose();
      await dbHelper.close();
    });

    test('broadcastCrisisSupply writes structured beacon and retrieves in getCrisisBeacons', () async {
      final payload = CrisisSupplyPayload.create(
        type: CrisisRequestType.request,
        category: DisasterSupplyCategory.food,
        title: 'Dry Rations & Canned Food Needed',
        details: 'Supplies ran out after flood cutoff',
        urgency: CrisisUrgency.urgent,
        adultsCount: 4,
        childrenCount: 2,
        locationDescription: 'East River Bridge Camp',
        contactName: 'Camp Leader',
        senderId: meshService.currentIdentity!.deviceId,
        neededItems: ['Canned Beans', 'Rice', 'Water Packets'],
      );

      final stored = await meshService.broadcastCrisisSupply(payload);
      expect(stored.conversationId, 'broadcast');

      final beacons = await meshService.getCrisisBeacons();
      expect(beacons.length, 1);
      expect(beacons.first.title, 'Dry Rations & Canned Food Needed');
      expect(beacons.first.category, DisasterSupplyCategory.food);
      expect(beacons.first.neededItems, contains('Canned Beans'));
    });

    test('broadcastQuickSos immediately broadcasts a Critical Rescue beacon', () async {
      final stored = await meshService.broadcastQuickSos(
        location: 'Roof of Blue 2-Story House',
        details: 'Flood water rising fast, 3 trapped',
        adultsCount: 2,
        childrenCount: 1,
        injuredCount: 1,
        neededItems: ['Boat Rescue', 'First Aid'],
      );

      expect(stored.conversationId, 'broadcast');

      final beacons = await meshService.getCrisisBeacons();
      expect(beacons.isNotEmpty, isTrue);

      final sosBeacon = beacons.firstWhere((b) => b.urgency == CrisisUrgency.critical);
      expect(sosBeacon.category, DisasterSupplyCategory.rescue);
      expect(sosBeacon.locationDescription, 'Roof of Blue 2-Story House');
      expect(sosBeacon.injuredCount, 1);
      expect(sosBeacon.totalPeople, 3);
    });
  });
}
