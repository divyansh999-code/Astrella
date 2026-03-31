import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine_console_screen.dart';
import 'nav_screen.dart';
import 'log_screen.dart';
import 'anomalies.dart';

class ScienceScreen extends StatefulWidget {
  const ScienceScreen({super.key});

  @override
  State<ScienceScreen> createState() => _ScienceScreenState();
}

class _ScienceScreenState extends State<ScienceScreen> {
  Map<String, int> _discoveryCounts = {};
  int _totalDiscoveries = 0;
  bool _isLoading = true;
  final List<Anomaly> _sortedAnomalies = [];

  @override
  void initState() {
    super.initState();
    _prepareAnomalies();
    _loadDiscoveryLog();
  }

  void _prepareAnomalies() {
    // Sort: Legendary (0), Rare (1), Common (2)
    _sortedAnomalies.clear();
    _sortedAnomalies.addAll(allAnomalies);
    _sortedAnomalies.sort((a, b) {
      final rarityOrder = {'LEGENDARY': 0, 'RARE': 1, 'COMMON': 2};
      return (rarityOrder[a.rarity] ?? 3).compareTo(rarityOrder[b.rarity] ?? 3);
    });
  }

  Future<void> _loadDiscoveryLog() async {
    final prefs = await SharedPreferences.getInstance();
    final discoveryJson = prefs.getString('discovery_log');
    
    Map<String, int> counts = {};
    int total = 0;

    if (discoveryJson != null) {
      final List<dynamic> log = jsonDecode(discoveryJson);
      total = log.length;
      for (var entry in log) {
        final id = entry['id'] as String?;
        if (id != null) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
    }

    if (mounted) {
      setState(() {
        _discoveryCounts = counts;
        _totalDiscoveries = total;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch, color: Color(0xFFF5A623), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        "MISSION STATUS: OPERATIONAL",
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFFF5A623),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "CORRIDOR: #RCVR_C",
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFFF5F5F0),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFF5A623), height: 1, thickness: 1),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5A623)))
                : _buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "SCIENCE ARCHIVE",
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFF5F5F0),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "TOTAL_DISCOVERIES: $_totalDiscoveries",
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFF5A623),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              mainAxisExtent: 180, // Specific height
            ),
            itemCount: _sortedAnomalies.length,
            itemBuilder: (context, index) {
              final anomaly = _sortedAnomalies[index];
              final count = _discoveryCounts[anomaly.id] ?? 0;
              return _buildAnomalyGridCard(anomaly, count);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnomalyGridCard(Anomaly anomaly, int count) {
    final bool isDiscovered = count > 0;
    
    Color rarityColor;
    if (anomaly.rarity == 'LEGENDARY') {
      rarityColor = const Color(0xFFF5A623);
    } else if (anomaly.rarity == 'RARE') {
      rarityColor = const Color(0xFF1A3A5C);
    } else {
      rarityColor = const Color(0xFF333333);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: isDiscovered 
            ? const Border(left: BorderSide(color: Color(0xFFF5A623), width: 3))
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              anomaly.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF222222)),
            ),
          ),
          
          // Overlay for undiscovered
          if (!isDiscovered)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
              ),
            ),
            
          // Lock Icon for undiscovered
          if (!isDiscovered)
            const Center(
              child: Icon(
                Icons.lock_outline,
                color: Color(0xFF333333),
                size: 32,
              ),
            ),
            
          // Rarity Tag Top-Left
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: rarityColor,
              child: Text(
                anomaly.rarity,
                style: GoogleFonts.spaceMono(
                  color: anomaly.rarity == 'LEGENDARY' ? Colors.black : Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Count Badge Top-Right
          if (isDiscovered)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  "×$count",
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFFF5A623),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
          // Name at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                anomaly.name,
                style: GoogleFonts.spaceMono(
                  color: isDiscovered ? Colors.white : Colors.grey.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      color: const Color(0xFF000000),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(context, "ENGINE", Icons.tune, false),
            _buildNavItem(context, "NAV", Icons.explore, false),
            _buildNavItem(context, "SCIENCE", Icons.science, true),
            _buildNavItem(context, "LOG", Icons.assignment, false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String label, IconData icon, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isActive) return;
          Widget target;
          if (label == "ENGINE") {
            target = const EngineConsoleScreen();
          } else if (label == "NAV") {
            target = const NavScreen();
          } else if (label == "LOG") {
            target = const LogScreen();
          } else {
            return;
          }
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => target,
              transitionDuration: Duration.zero,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: isActive ? const Color(0xFFF5A623) : const Color(0xFF1A1A1A),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF000000) : const Color(0xFFF5F5F0),
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: isActive ? const Color(0xFF000000) : const Color(0xFFF5F5F0),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
