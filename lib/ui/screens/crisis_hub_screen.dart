import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models/crisis_supply_payload.dart';
import '../../services/mesh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/crisis_beacon_card.dart';
import '../widgets/crisis_supply_dialog.dart';

class CrisisHubScreen extends StatefulWidget {
  final MeshService meshService;

  const CrisisHubScreen({super.key, required this.meshService});

  @override
  State<CrisisHubScreen> createState() => _CrisisHubScreenState();
}

class _CrisisHubScreenState extends State<CrisisHubScreen>
    with SingleTickerProviderStateMixin {
  List<CrisisSupplyPayload> _beacons = [];
  bool _isLoading = true;

  DisasterSupplyCategory? _selectedCategory; // null = All
  CrisisRequestType? _selectedType; // null = All, or request / offer
  bool _criticalOnly = false;

  late AnimationController _pulseController;
  StreamSubscription? _msgSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _loadBeacons();

    _msgSubscription = widget.meshService.onMessageReceived.listen((_) {
      _loadBeacons();
    });

    widget.meshService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _msgSubscription?.cancel();
    widget.meshService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    _loadBeacons();
  }

  Future<void> _loadBeacons() async {
    final list = await widget.meshService.getCrisisBeacons();
    if (mounted) {
      setState(() {
        _beacons = list;
        _isLoading = false;
      });
    }
  }

  List<CrisisSupplyPayload> get _filteredBeacons {
    return _beacons.where((b) {
      if (_selectedCategory != null && b.category != _selectedCategory) {
        return false;
      }
      if (_selectedType != null && b.type != _selectedType) {
        return false;
      }
      if (_criticalOnly && b.urgency != CrisisUrgency.critical) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _criticalCount =>
      _beacons.where((b) => b.urgency == CrisisUrgency.critical).length;

  void _showQuickSosDialog() {
    final locationController = TextEditingController();
    final detailsController = TextEditingController();
    int peopleCount = 1;
    int injuredCount = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.sosRed, width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.sosRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '🚨 QUICK SOS BEACON',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.sosRed,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Broadcasts an immediate CRITICAL Search & Rescue beacon across the entire Bluetooth mesh network without internet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: locationController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Location / Landmark',
                    hintText: 'e.g. 3rd Floor Rooftop, Near Water Tank',
                    prefixIcon: Icon(Icons.place, color: AppTheme.sosRed),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Details',
                    hintText: 'e.g. Water rising, 1 elderly with asthma',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('People Count:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (peopleCount > 1) {
                          setDialogState(() => peopleCount--);
                        }
                      },
                    ),
                    Text('$peopleCount',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setDialogState(() => peopleCount++),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Injured:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.sosRed)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.sosRed),
                      onPressed: () {
                        if (injuredCount > 0) {
                          setDialogState(() => injuredCount--);
                        }
                      },
                    ),
                    Text('$injuredCount',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.sosRed)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppTheme.sosRed),
                      onPressed: () => setDialogState(() => injuredCount++),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sosRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final loc = locationController.text.trim();
                final details = detailsController.text.trim();
                Navigator.pop(ctx);

                await widget.meshService.broadcastQuickSos(
                  location: loc,
                  details: details,
                  adultsCount: peopleCount,
                  injuredCount: injuredCount,
                );

                await _loadBeacons();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.sosRed,
                      content: Text(
                        '🚨 CRITICAL SOS BEACON BROADCASTED TO MESH!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
              },
              child: const Text('BROADCAST SOS NOW'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSupplyDialog({CrisisRequestType type = CrisisRequestType.request}) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (_) => CrisisSupplyDialog(
        meshService: widget.meshService,
        initialType: type,
        initialCategory: _selectedCategory,
      ),
    ).then((val) {
      if (val == true) {
        _loadBeacons();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBeacons;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.sosGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.sosGlow(blur: 8, opacity: 0.4),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disaster & SOS Hub',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Offline Crisis Supply Coordination',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Beacons',
            onPressed: _loadBeacons,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.sosRed,
        backgroundColor: AppTheme.surface,
        onRefresh: _loadBeacons,
        child: Column(
          children: [
            // Top Emergency SOS Quick Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A0A10), Color(0xFF1B1124)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.sosRed.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.sosRed.withValues(
                            alpha: 0.7 + (_pulseController.value * 0.3),
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.sosRed.withValues(
                                alpha: 0.3 + (_pulseController.value * 0.5),
                              ),
                              blurRadius: 10 + (_pulseController.value * 8),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sos_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Life-Threatening Emergency?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _criticalCount > 0
                              ? '$_criticalCount active Critical SOS beacons in mesh'
                              : 'Broadcast instant 1-tap beacon',
                          style: TextStyle(
                            fontSize: 11,
                            color: _criticalCount > 0
                                ? AppTheme.sosRed
                                : Colors.grey[400],
                            fontWeight: _criticalCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sosRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _showQuickSosDialog,
                    child: const Text(
                      '🚨 1-TAP SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Mode Filter: All / Requests (Needs) / Offers (Resources)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildTypeTab(label: 'All Beacons', type: null),
                  const SizedBox(width: 8),
                  _buildTypeTab(
                    label: '📢 Supply Needs',
                    type: CrisisRequestType.request,
                  ),
                  const SizedBox(width: 8),
                  _buildTypeTab(
                    label: '📦 Supply Offers',
                    type: CrisisRequestType.offer,
                  ),
                ],
              ),
            ),

            // Supply Category Filter Pills (Horizontal Scroll)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  // All Categories Pill
                  FilterChip(
                    label: const Text('All Supplies'),
                    selected: _selectedCategory == null,
                    selectedColor: AppTheme.primaryCyan,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedCategory == null
                          ? Colors.black
                          : Colors.white,
                    ),
                    backgroundColor: AppTheme.surfaceLight,
                    onSelected: (_) {
                      setState(() => _selectedCategory = null);
                    },
                  ),
                  const SizedBox(width: 6),

                  // Critical Only Filter Pill
                  FilterChip(
                    avatar: const Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppTheme.sosRed),
                    label: Text(
                      'Critical Only ($_criticalCount)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _criticalOnly ? Colors.white : AppTheme.sosRed,
                      ),
                    ),
                    selected: _criticalOnly,
                    selectedColor: AppTheme.sosRed,
                    checkmarkColor: Colors.white,
                    backgroundColor: AppTheme.surfaceLight,
                    onSelected: (val) {
                      setState(() => _criticalOnly = val);
                    },
                  ),
                  const SizedBox(width: 6),

                  // Individual Categories
                  ...DisasterSupplyCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        avatar: Text(cat.emoji,
                            style: const TextStyle(fontSize: 14)),
                        label: Text(cat.label),
                        selected: isSelected,
                        selectedColor: cat.themeColor,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                        backgroundColor: AppTheme.surfaceLight,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = isSelected ? null : cat;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Beacons Feed
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.sosRed),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80, top: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final beacon = filtered[index];
                            return CrisisBeaconCard(
                              beacon: beacon,
                              meshService: widget.meshService,
                              onUpdated: _loadBeacons,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.sosRed,
        foregroundColor: Colors.white,
        onPressed: () => _openSupplyDialog(),
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text(
          'Request / Offer Supplies',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required CrisisRequestType? type,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedType = type);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryCyan : AppTheme.cardBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryCyan : Colors.grey[400],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.satellite_alt_rounded,
                size: 48,
                color: AppTheme.primaryCyan,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Crisis Beacons Active in Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are monitoring the offline Bluetooth mesh channel.\nTap the button below to broadcast emergency needs (Medic, Food, Water, Shelter, Rescue, Power) or offer relief resources to nearby survivors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceLight,
                foregroundColor: AppTheme.primaryCyan,
                side: const BorderSide(color: AppTheme.primaryCyan),
              ),
              onPressed: () => _openSupplyDialog(type: CrisisRequestType.offer),
              icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
              label: const Text('Offer Relief Supplies to Mesh'),
            ),
          ],
        ),
      ),
    );
  }
}
