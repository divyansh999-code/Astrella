import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine_console_screen.dart';
import 'nav_screen.dart';
import 'science_screen.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('mission_sessions');
    if (sessionsJson != null) {
      final List<dynamic> loadedSessions = jsonDecode(sessionsJson);
      setState(() {
        _sessions = loadedSessions.reversed.toList();
        _isLoading = false;
      });
    } else {
      setState(() {
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
                        "ASTRELLA",
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFFF5A623),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "MISSION STATUS: OPERATIONAL",
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
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Text(
                            "FLIGHT RECORDER",
                            style: GoogleFonts.spaceMono(
                              color: const Color(0xFFF5F5F0),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "ARCHIVE CLUSTER: 04-X",
                                style: GoogleFonts.spaceMono(
                                  color: const Color(0xFFF5A623),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                "TOTAL LOGS: ${_sessions.length}",
                                style: GoogleFonts.spaceMono(
                                  color: const Color(0xFFF5A623),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Search Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Color(0xFFF5F5F0), size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    cursorColor: const Color(0xFFF5A623),
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5F5F0),
                                      fontSize: 12,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "FILTER BY MISSION ID...",
                                      hintStyle: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5F5F0).withOpacity(0.3),
                                        fontSize: 12,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.tune, color: Color(0xFFF5F5F0), size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Session Cards
                          if (_sessions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Center(
                                child: Text(
                                  "NO MISSION DATA RECORDED",
                                  style: GoogleFonts.spaceMono(
                                    color: const Color(0xFFF5A623).withOpacity(0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._sessions.map((session) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildSessionCard(
                                  status: session['status'],
                                  serial: session['id'],
                                  chrono: session['chronoStamp'],
                                  duration: "${session['duration']}",
                                  missionName: session['missionName'],
                                ),
                            )).toList(),

                          const SizedBox(height: 12),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildSessionCard({
    required String status,
    required String serial,
    required String chrono,
    required String duration,
    String? missionName,
  }) {
    final bool isAborted = status == "ABORTED";
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: isAborted ? const Border(left: BorderSide(color: Color(0xFFFF3B30), width: 4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SERIAL NUMBER: $serial",
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFF5F5F0),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                "MISSION: ",
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFF5F5F0).withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
              Text(
                (missionName == null || missionName.isEmpty) ? "UNDESIGNATED" : missionName,
                style: GoogleFonts.spaceMono(
                  color: (missionName == null || missionName.isEmpty) 
                    ? const Color(0xFFF5A623).withOpacity(0.5) 
                    : const Color(0xFFF5A623),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailRow("CHRONO STAMP", chrono),
          const SizedBox(height: 8),
          _buildDetailRow("DURATION", duration),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status == "ABORTED") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          color: Color(0xFFFF3B30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFF000000), size: 10),
            const SizedBox(width: 4),
            Text(
              status,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF000000),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (status == "PARTIAL") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF5F5F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom, color: Color(0xFFF5F5F0), size: 10),
            const SizedBox(width: 4),
            Text(
              status,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFFF5F5F0),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      // SUCCESS
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF5A623)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: Color(0xFFF5A623), size: 10),
            const SizedBox(width: 4),
            Text(
              status,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFFF5A623),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFF5F5F0).withOpacity(0.5),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFF5F5F0),
            fontSize: 10,
          ),
        ),
      ],
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
            _buildNavItem(context, "SCIENCE", Icons.science, false),
            _buildNavItem(context, "LOG", Icons.assignment, true),
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
            target = EngineConsoleScreen();
          } else if (label == "NAV") {
            target = NavScreen();
          } else if (label == "SCIENCE") {
            target = ScienceScreen();
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
