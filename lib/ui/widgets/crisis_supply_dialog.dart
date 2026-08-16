import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models/crisis_supply_payload.dart';
import '../../services/mesh_service.dart';
import '../theme/app_theme.dart';

class CrisisSupplyDialog extends StatefulWidget {
  final MeshService meshService;
  final CrisisRequestType initialType;
  final DisasterSupplyCategory? initialCategory;
  final CrisisUrgency? initialUrgency;

  const CrisisSupplyDialog({
    super.key,
    required this.meshService,
    this.initialType = CrisisRequestType.request,
    this.initialCategory,
    this.initialUrgency,
  });

  @override
  State<CrisisSupplyDialog> createState() => _CrisisSupplyDialogState();
}

class _CrisisSupplyDialogState extends State<CrisisSupplyDialog> {
  late CrisisRequestType _type;
  late DisasterSupplyCategory _category;
  late CrisisUrgency _urgency;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _customItemController = TextEditingController();

  int _adultsCount = 1;
  int _childrenCount = 0;
  int _injuredCount = 0;
  final List<String> _selectedItems = [];
  bool _isBroadcasting = false;

  final Map<DisasterSupplyCategory, List<String>> _presetTagsByCategory = {
    DisasterSupplyCategory.medical: [
      'Insulin',
      'Bandages & Gauze',
      'Pain Relief',
      'Antibiotics',
      'First Aid Kit',
      'Oxygen / Inhaler',
      'Doctor / Medic Needed',
    ],
    DisasterSupplyCategory.food: [
      'Baby Formula',
      'Canned Food',
      'Ready-to-eat Meals',
      'Energy Bars',
      'Rice / Grains',
      'Baby Food',
    ],
    DisasterSupplyCategory.water: [
      'Bottled Drinking Water',
      'Water Purification Tablets',
      'Bulk Water Tank',
      'Electrolyte Packets',
    ],
    DisasterSupplyCategory.shelter: [
      'Tents',
      'Warm Blankets',
      'Sleeping Bags',
      'Dry Clothing',
      'Tarpaulins',
    ],
    DisasterSupplyCategory.rescue: [
      'Trapped on Roof',
      'Rising Water Level',
      'Elderly Evacuation',
      'Boat / Raft Needed',
      'Structural Collapse',
      'Stretcher Needed',
    ],
    DisasterSupplyCategory.power: [
      'Batteries (AA/AAA)',
      'Flashlights / Torches',
      'Power Bank / Charging',
      'Generator / Fuel',
      'Solar Charger',
    ],
    DisasterSupplyCategory.other: [
      'Hygiene & Sanitation',
      'Rope & Tools',
      'Radio Communication',
      'Diapers',
    ],
  };

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory ?? DisasterSupplyCategory.medical;
    _urgency = widget.initialUrgency ??
        (_type == CrisisRequestType.request
            ? CrisisUrgency.urgent
            : CrisisUrgency.standard);

    // Initial default title
    _updateDefaultTitle();
  }

  void _updateDefaultTitle() {
    if (_titleController.text.isEmpty ||
        _titleController.text.startsWith('Need ') ||
        _titleController.text.startsWith('Offering ')) {
      final prefix =
          _type == CrisisRequestType.request ? 'Need ' : 'Offering ';
      _titleController.text = '$prefix${_category.label}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _locationController.dispose();
    _customItemController.dispose();
    super.dispose();
  }

  void _toggleItem(String item) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _addCustomItem() {
    final text = _customItemController.text.trim();
    if (text.isNotEmpty && !_selectedItems.contains(text)) {
      setState(() {
        _selectedItems.add(text);
        _customItemController.clear();
      });
    }
  }

  Future<void> _broadcastBeacon() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the beacon')),
      );
      return;
    }

    setState(() {
      _isBroadcasting = true;
    });

    HapticFeedback.heavyImpact();

    try {
      final identity = widget.meshService.currentIdentity;
      final payload = CrisisSupplyPayload.create(
        type: _type,
        category: _category,
        title: title,
        details: _detailsController.text.trim(),
        urgency: _urgency,
        adultsCount: _adultsCount,
        childrenCount: _childrenCount,
        injuredCount: _injuredCount,
        locationDescription: _locationController.text.trim(),
        contactName: identity?.nickname ??
            'User-${identity?.deviceId.substring(0, 4) ?? "0000"}',
        senderId: identity?.deviceId ?? '',
        neededItems: _selectedItems,
      );

      await widget.meshService.broadcastCrisisSupply(payload);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentMint,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_category.emoji} Beacon broadcasted to offline mesh!',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBroadcasting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.sosRed,
            content: Text('Failed to broadcast: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = _urgency == CrisisUrgency.critical;

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isCritical
              ? AppTheme.sosRed
              : AppTheme.primaryCyan.withValues(alpha: 0.3),
          width: isCritical ? 2.0 : 1.0,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: isCritical ? AppTheme.sosGradient : AppTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCritical
                        ? Icons.emergency_share_rounded
                        : Icons.wifi_tethering_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _type == CrisisRequestType.request
                          ? 'BROADCAST SUPPLY NEED / SOS'
                          : 'BROADCAST SUPPLY OFFER',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Switch: Request vs Offer
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _type = CrisisRequestType.request;
                                  _updateDefaultTitle();
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _type == CrisisRequestType.request
                                      ? AppTheme.sosRed
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sos_rounded,
                                        size: 16,
                                        color: _type == CrisisRequestType.request
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Need Supplies',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _type == CrisisRequestType.request
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _type = CrisisRequestType.offer;
                                  _updateDefaultTitle();
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _type == CrisisRequestType.offer
                                      ? AppTheme.accentMint
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.volunteer_activism_rounded,
                                        size: 16,
                                        color: _type == CrisisRequestType.offer
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Offer Supplies',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _type == CrisisRequestType.offer
                                              ? Colors.black
                                              : Colors.grey,
                                        ),
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
                    const SizedBox(height: 18),

                    // Category Selector
                    const Text(
                      'SUPPLY CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DisasterSupplyCategory.values.map((cat) {
                        final isSelected = _category == cat;
                        return ChoiceChip(
                          avatar: Icon(
                            cat.iconData,
                            size: 16,
                            color: isSelected ? Colors.black : cat.themeColor,
                          ),
                          label: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: cat.themeColor,
                          backgroundColor: AppTheme.surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? cat.themeColor
                                  : AppTheme.cardBorder,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _category = cat;
                                _updateDefaultTitle();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Urgency Selector
                    const Text(
                      'URGENCY LEVEL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: CrisisUrgency.values.map((urg) {
                        final isSelected = _urgency == urg;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _urgency = urg;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? urg.color.withValues(alpha: 0.25)
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? urg.color
                                      : AppTheme.cardBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    urg == CrisisUrgency.critical
                                        ? Icons.emergency_rounded
                                        : (urg == CrisisUrgency.urgent
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle_outline),
                                    size: 18,
                                    color: urg.color,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    urg == CrisisUrgency.critical
                                        ? 'CRITICAL'
                                        : (urg == CrisisUrgency.urgent
                                            ? 'HIGH'
                                            : 'NORMAL'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? urg.color
                                          : Colors.grey[300],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    const Text(
                      'TITLE / SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Need Insulin & Sterile Bandages',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Preset Quick Tags
                    if (_presetTagsByCategory[_category] != null) ...[
                      const Text(
                        'QUICK ITEMS / REQUIREMENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _presetTagsByCategory[_category]!.map((tag) {
                          final isChecked = _selectedItems.contains(tag);
                          return FilterChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            selected: isChecked,
                            selectedColor: _category.themeColor.withValues(alpha: 0.3),
                            checkmarkColor: _category.themeColor,
                            backgroundColor: AppTheme.surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isChecked
                                    ? _category.themeColor
                                    : AppTheme.cardBorder,
                              ),
                            ),
                            onSelected: (_) => _toggleItem(tag),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // Custom item input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customItemController,
                              decoration: const InputDecoration(
                                hintText: 'Add custom item (e.g. Baby formula 5 cans)',
                                isDense: true,
                              ),
                              onSubmitted: (_) => _addCustomItem(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.primaryCyan,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: _addCustomItem,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Affected People Counters
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 16, color: AppTheme.primaryCyan),
                              SizedBox(width: 6),
                              Text(
                                'PEOPLE INVOLVED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryCyan,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildCounter(
                                label: 'Adults',
                                count: _adultsCount,
                                min: 1,
                                onIncrement: () =>
                                    setState(() => _adultsCount++),
                                onDecrement: () => setState(() {
                                  if (_adultsCount > 1) _adultsCount--;
                                }),
                              ),
                              _buildCounter(
                                label: 'Children',
                                count: _childrenCount,
                                min: 0,
                                onIncrement: () =>
                                    setState(() => _childrenCount++),
                                onDecrement: () => setState(() {
                                  if (_childrenCount > 0) _childrenCount--;
                                }),
                              ),
                              _buildCounter(
                                label: 'Injured',
                                count: _injuredCount,
                                min: 0,
                                isWarning: true,
                                onIncrement: () =>
                                    setState(() => _injuredCount++),
                                onDecrement: () => setState(() {
                                  if (_injuredCount > 0) _injuredCount--;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location / Physical Landmark
                    const Text(
                      'LOCATION / LANDMARK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. North High School, 2nd Floor Room 12',
                        prefixIcon: Icon(
                          Icons.place_outlined,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detailed Notes
                    const Text(
                      'ADDITIONAL DETAILS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Provide additional specifics: access routes, water level, power availability...',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Broadcast Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCritical
                        ? AppTheme.sosRed
                        : (_type == CrisisRequestType.offer
                            ? AppTheme.accentMint
                            : AppTheme.primaryCyan),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isBroadcasting ? null : _broadcastBeacon,
                  icon: _isBroadcasting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Icon(
                          isCritical
                              ? Icons.emergency_rounded
                              : Icons.broadcast_on_personal_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _isBroadcasting
                        ? 'BROADCASTING OVER MESH...'
                        : (isCritical
                            ? '🚨 BROADCAST CRITICAL SOS'
                            : 'BROADCAST OVER MESH'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter({
    required String label,
    required int count,
    required int min,
    bool isWarning = false,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isWarning && count > 0 ? AppTheme.sosRed : Colors.grey[300],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: count > min ? Colors.white : Colors.grey[600],
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: count > min ? onDecrement : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isWarning && count > 0 ? AppTheme.sosRed : Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: Colors.white,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}
