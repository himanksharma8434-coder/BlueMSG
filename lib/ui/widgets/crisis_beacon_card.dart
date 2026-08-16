import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models/crisis_supply_payload.dart';
import '../../services/mesh_service.dart';
import '../screens/chat_screen.dart';
import '../theme/app_theme.dart';

class CrisisBeaconCard extends StatelessWidget {
  final CrisisSupplyPayload beacon;
  final MeshService meshService;
  final VoidCallback? onUpdated;
  final bool compact;

  const CrisisBeaconCard({
    super.key,
    required this.beacon,
    required this.meshService,
    this.onUpdated,
    this.compact = false,
  });

  bool get isMyBeacon =>
      meshService.currentIdentity?.deviceId == beacon.senderId;

  @override
  Widget build(BuildContext context) {
    final isCritical = beacon.urgency == CrisisUrgency.critical;
    final isOffer = beacon.type == CrisisRequestType.offer;
    final categoryColor = beacon.category.themeColor;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 16,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical
              ? AppTheme.sosRed.withValues(alpha: 0.8)
              : categoryColor.withValues(alpha: 0.4),
          width: isCritical ? 2.0 : 1.2,
        ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: AppTheme.sosRed.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: 1,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Urgency + Type + Category Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCritical
                    ? AppTheme.sosRed.withValues(alpha: 0.2)
                    : categoryColor.withValues(alpha: 0.15),
                border: Border(
                  bottom: BorderSide(
                    color: isCritical
                        ? AppTheme.sosRed.withValues(alpha: 0.4)
                        : categoryColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isCritical ? AppTheme.sosRed : categoryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      beacon.category.iconData,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isOffer ? 'SUPPLY OFFER' : 'SUPPLY NEED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: isOffer
                                    ? AppTheme.accentMint
                                    : (isCritical
                                        ? AppTheme.sosRed
                                        : categoryColor),
                              ),
                            ),
                            const Text(' • ',
                                style: TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Text(
                                beacon.category.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Urgency Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: beacon.urgency.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: beacon.urgency.color,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCritical)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: AppTheme.sosRed,
                            ),
                          ),
                        Text(
                          isCritical
                              ? 'SOS CRITICAL'
                              : (beacon.urgency == CrisisUrgency.urgent
                                  ? 'URGENT'
                                  : 'NORMAL'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: beacon.urgency.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body Details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    beacon.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Details Description
                  if (beacon.details.isNotEmpty) ...[
                    Text(
                      beacon.details,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[300],
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Needed items chips
                  if (beacon.neededItems.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: beacon.neededItems.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: categoryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '📦 $item',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[200],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // People and Location info row
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Location Row
                        if (beacon.locationDescription.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 16,
                                color: AppTheme.accentAmber,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  beacon.locationDescription,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (beacon.locationDescription.isNotEmpty &&
                            beacon.totalPeople > 0)
                          const Divider(
                              color: AppTheme.cardBorder, height: 12),

                        // People Counts
                        if (beacon.totalPeople > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                size: 16,
                                color: AppTheme.primaryCyan,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${beacon.totalPeople} Total (${beacon.adultsCount} Adults, ${beacon.childrenCount} Children)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[300],
                                ),
                              ),
                              if (beacon.injuredCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.sosRed.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppTheme.sosRed, width: 0.8),
                                  ),
                                  child: Text(
                                    '🩹 ${beacon.injuredCount} Injured',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.sosRed,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Footer: Sender & Action Buttons
                  Row(
                    children: [
                      Icon(
                        Icons.person_pin_circle_rounded,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${beacon.contactName} (${_formatTime(beacon.timestamp)})',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      // Copy / Share button
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        color: Colors.grey[400],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Share Beacon Summary',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: beacon.toHumanReadableSummary()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Crisis Beacon copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Direct Chat Action Button
                      if (!isMyBeacon)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCritical
                                ? AppTheme.sosRed
                                : AppTheme.primaryCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  meshService: meshService,
                                  conversationId: beacon.senderId,
                                  peerNickname: beacon.contactName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 14),
                          label: Text(isOffer ? 'Request Info' : 'Offer Help'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
