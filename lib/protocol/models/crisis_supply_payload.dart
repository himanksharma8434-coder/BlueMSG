import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Categories of emergency supplies and disaster relief assistance.
enum DisasterSupplyCategory {
  medical,
  food,
  water,
  shelter,
  rescue,
  power,
  other;

  String get label {
    switch (this) {
      case DisasterSupplyCategory.medical:
        return 'Medical & First Aid';
      case DisasterSupplyCategory.food:
        return 'Food & Rations';
      case DisasterSupplyCategory.water:
        return 'Drinking Water';
      case DisasterSupplyCategory.shelter:
        return 'Shelter & Warmth';
      case DisasterSupplyCategory.rescue:
        return 'Search & Rescue';
      case DisasterSupplyCategory.power:
        return 'Power & Lighting';
      case DisasterSupplyCategory.other:
        return 'General Supplies';
    }
  }

  String get emoji {
    switch (this) {
      case DisasterSupplyCategory.medical:
        return '💊';
      case DisasterSupplyCategory.food:
        return '🥫';
      case DisasterSupplyCategory.water:
        return '💧';
      case DisasterSupplyCategory.shelter:
        return '⛺';
      case DisasterSupplyCategory.rescue:
        return '🆘';
      case DisasterSupplyCategory.power:
        return '⚡';
      case DisasterSupplyCategory.other:
        return '📦';
    }
  }

  IconData get iconData {
    switch (this) {
      case DisasterSupplyCategory.medical:
        return Icons.medical_services_rounded;
      case DisasterSupplyCategory.food:
        return Icons.restaurant_rounded;
      case DisasterSupplyCategory.water:
        return Icons.water_drop_rounded;
      case DisasterSupplyCategory.shelter:
        return Icons.holiday_village_rounded;
      case DisasterSupplyCategory.rescue:
        return Icons.emergency_rounded;
      case DisasterSupplyCategory.power:
        return Icons.bolt_rounded;
      case DisasterSupplyCategory.other:
        return Icons.inventory_2_rounded;
    }
  }

  Color get themeColor {
    switch (this) {
      case DisasterSupplyCategory.medical:
        return const Color(0xFF00E5FF);
      case DisasterSupplyCategory.food:
        return const Color(0xFFFFB300);
      case DisasterSupplyCategory.water:
        return const Color(0xFF00B0FF);
      case DisasterSupplyCategory.shelter:
        return const Color(0xFF00E676);
      case DisasterSupplyCategory.rescue:
        return const Color(0xFFFF334B);
      case DisasterSupplyCategory.power:
        return const Color(0xFFE040FB);
      case DisasterSupplyCategory.other:
        return const Color(0xFF9E9E9E);
    }
  }

  static DisasterSupplyCategory fromString(String? value) {
    if (value == null) return DisasterSupplyCategory.other;
    return DisasterSupplyCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DisasterSupplyCategory.other,
    );
  }
}

/// Request (Need Help) vs Offer (Providing Help)
enum CrisisRequestType {
  request,
  offer;

  String get label {
    switch (this) {
      case CrisisRequestType.request:
        return 'Supply Need / SOS';
      case CrisisRequestType.offer:
        return 'Supply Offer / Resource';
    }
  }

  String get actionVerb {
    switch (this) {
      case CrisisRequestType.request:
        return 'SEEKING';
      case CrisisRequestType.offer:
        return 'OFFERING';
    }
  }

  static CrisisRequestType fromString(String? value) {
    if (value == null) return CrisisRequestType.request;
    return CrisisRequestType.values.firstWhere(
      (t) => t.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CrisisRequestType.request,
    );
  }
}

/// Urgency level for natural crisis requests.
enum CrisisUrgency {
  critical,
  urgent,
  standard;

  String get label {
    switch (this) {
      case CrisisUrgency.critical:
        return 'CRITICAL (Immediate)';
      case CrisisUrgency.urgent:
        return 'HIGH (Urgent)';
      case CrisisUrgency.standard:
        return 'NORMAL';
    }
  }

  Color get color {
    switch (this) {
      case CrisisUrgency.critical:
        return const Color(0xFFFF334B);
      case CrisisUrgency.urgent:
        return const Color(0xFFFF9100);
      case CrisisUrgency.standard:
        return const Color(0xFFFFD600);
    }
  }

  static CrisisUrgency fromString(String? value) {
    if (value == null) return CrisisUrgency.standard;
    return CrisisUrgency.values.firstWhere(
      (u) => u.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CrisisUrgency.standard,
    );
  }
}

/// Structured payload for disaster relief supplies & emergency beacons.
class CrisisSupplyPayload {
  static const String protocolPrefix = '[CRISIS_RELIEF_V1]:';

  final String id;
  final CrisisRequestType type;
  final DisasterSupplyCategory category;
  final String title;
  final String details;
  final CrisisUrgency urgency;
  final int adultsCount;
  final int childrenCount;
  final int injuredCount;
  final String locationDescription;
  final String contactName;
  final String senderId;
  final int timestamp;
  final bool isResolved;
  final List<String> neededItems;
  final List<String> responders;

  const CrisisSupplyPayload({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.details,
    required this.urgency,
    this.adultsCount = 1,
    this.childrenCount = 0,
    this.injuredCount = 0,
    required this.locationDescription,
    required this.contactName,
    required this.senderId,
    required this.timestamp,
    this.isResolved = false,
    this.neededItems = const [],
    this.responders = const [],
  });

  /// Factory to quickly create a new crisis beacon.
  factory CrisisSupplyPayload.create({
    String? id,
    required CrisisRequestType type,
    required DisasterSupplyCategory category,
    required String title,
    required String details,
    required CrisisUrgency urgency,
    int adultsCount = 1,
    int childrenCount = 0,
    int injuredCount = 0,
    required String locationDescription,
    required String contactName,
    required String senderId,
    int? timestamp,
    bool isResolved = false,
    List<String>? neededItems,
    List<String>? responders,
  }) {
    return CrisisSupplyPayload(
      id: id ?? const Uuid().v4(),
      type: type,
      category: category,
      title: title,
      details: details,
      urgency: urgency,
      adultsCount: adultsCount,
      childrenCount: childrenCount,
      injuredCount: injuredCount,
      locationDescription: locationDescription,
      contactName: contactName,
      senderId: senderId,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isResolved: isResolved,
      neededItems: neededItems ?? [],
      responders: responders ?? [],
    );
  }

  /// Total number of people affected.
  int get totalPeople => adultsCount + childrenCount;

  /// Serializes the beacon into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'category': category.name,
      'title': title,
      'details': details,
      'urgency': urgency.name,
      'adultsCount': adultsCount,
      'childrenCount': childrenCount,
      'injuredCount': injuredCount,
      'location': locationDescription,
      'contact': contactName,
      'senderId': senderId,
      'timestamp': timestamp,
      'isResolved': isResolved,
      'items': neededItems,
      'responders': responders,
    };
  }

  /// Encodes the payload into a mesh broadcast message body.
  String toEncodedMessage() {
    return '$protocolPrefix${jsonEncode(toJson())}';
  }

  /// Creates a human-readable text fallback.
  String toHumanReadableSummary() {
    final verb = type == CrisisRequestType.request ? 'NEED' : 'OFFERING';
    final buffer = StringBuffer();
    buffer.writeln('${category.emoji} [$verb] ${category.label.toUpperCase()}: $title');
    buffer.writeln('Urgency: ${urgency.label}');
    if (locationDescription.isNotEmpty) {
      buffer.writeln('📍 Location: $locationDescription');
    }
    if (totalPeople > 0) {
      buffer.writeln('👥 Affected: $totalPeople people ($adultsCount adults, $childrenCount children${injuredCount > 0 ? ', $injuredCount injured' : ''})');
    }
    if (neededItems.isNotEmpty) {
      buffer.writeln('📦 Items: ${neededItems.join(', ')}');
    }
    if (details.isNotEmpty) {
      buffer.writeln('Details: $details');
    }
    return buffer.toString().trim();
  }

  /// Attempts to parse a message body as a CrisisSupplyPayload.
  static CrisisSupplyPayload? tryParse(String rawBody) {
    final trimmed = rawBody.trim();
    String jsonStr;

    if (trimmed.startsWith(protocolPrefix)) {
      jsonStr = trimmed.substring(protocolPrefix.length);
    } else if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      jsonStr = trimmed;
    } else {
      return null;
    }

    try {
      final map = jsonDecode(jsonStr);
      if (map is! Map<String, dynamic>) return null;

      // Validate required core fields
      if (!map.containsKey('category') || !map.containsKey('title')) {
        return null;
      }

      return CrisisSupplyPayload.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  factory CrisisSupplyPayload.fromJson(Map<String, dynamic> json) {
    return CrisisSupplyPayload(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: CrisisRequestType.fromString(json['type'] as String?),
      category: DisasterSupplyCategory.fromString(json['category'] as String?),
      title: json['title'] as String? ?? 'Relief Request',
      details: json['details'] as String? ?? '',
      urgency: CrisisUrgency.fromString(json['urgency'] as String?),
      adultsCount: (json['adultsCount'] as num?)?.toInt() ?? 1,
      childrenCount: (json['childrenCount'] as num?)?.toInt() ?? 0,
      injuredCount: (json['injuredCount'] as num?)?.toInt() ?? 0,
      locationDescription: json['location'] as String? ?? '',
      contactName: json['contact'] as String? ?? 'Anonymous',
      senderId: json['senderId'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      isResolved: json['isResolved'] as bool? ?? false,
      neededItems: (json['items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      responders: (json['responders'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  CrisisSupplyPayload copyWith({
    bool? isResolved,
    List<String>? responders,
    String? details,
  }) {
    return CrisisSupplyPayload(
      id: id,
      type: type,
      category: category,
      title: title,
      details: details ?? this.details,
      urgency: urgency,
      adultsCount: adultsCount,
      childrenCount: childrenCount,
      injuredCount: injuredCount,
      locationDescription: locationDescription,
      contactName: contactName,
      senderId: senderId,
      timestamp: timestamp,
      isResolved: isResolved ?? this.isResolved,
      neededItems: neededItems,
      responders: responders ?? this.responders,
    );
  }
}
