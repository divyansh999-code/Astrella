import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'log_screen.dart';
import 'engine_console_screen.dart';
import 'science_screen.dart';
import 'dart:async';
import 'dart:convert';

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> with SingleTickerProviderStateMixin {
  // Generate random stars once
  final List<Offset> _stars = List.generate(
      100, (index) => Offset(math.Random().nextDouble(), math.Random().nextDouble()));
  final List<double> _starSizes =
      List.generate(100, (index) => math.Random().nextDouble() * 2 + 1);

  int _totalLyTraveled = 0;
  int _totalSessions = 0;
  int _bestStreak = 0;
  
  double _alphaV = 184.22;
  double _gammaR = -0.045;
  double _deltaZ = 99.10;
  Timer? _coordTimer;
  late AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _startCoordAnimation();
    
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..repeat();
  }

  @override
  void dispose() {
    _coordTimer?.cancel();
    _driftController.dispose();
    super.dispose();
  }

  void _startCoordAnimation() {
    _coordTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _alphaV += (math.Random().nextDouble() * 0.002) - 0.001;
          _gammaR += (math.Random().nextDouble() * 0.002) - 0.001;
          _deltaZ += (math.Random().nextDouble() * 0.002) - 0.001;
        });
      }
    });
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString('mission_sessions');
    
    int ly = prefs.getInt('total_ly_traveled') ?? 0;
    int sessionsCount = 0;
    int bestStr = 0;

    if (sessionsJson != null) {
      final List<dynamic> sessions = jsonDecode(sessionsJson);
      sessionsCount = sessions.length;
      
      Set<String> activeDates = {};
      for (var session in sessions) {
        final chrono = session['chronoStamp'] as String;
        activeDates.add(chrono.split(' | ')[0]);
      }
      bestStr = _calculateBestStreak(activeDates);
    }

    if (mounted) {
      setState(() {
        _totalLyTraveled = ly;
        _totalSessions = sessionsCount;
        _bestStreak = bestStr;
      });
    }
  }

  int _calculateBestStreak(Set<String> activeDates) {
    if (activeDates.isEmpty) return 0;
    
    List<DateTime> sortedDates = activeDates.map((d) {
      final p = d.split('.');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }).toList()..sort();

    int maxStreak = 0;
    int currentStreak = 0;
    DateTime? prevDate;

    for (var date in sortedDates) {
      if (prevDate == null) {
        currentStreak = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          currentStreak++;
        } else if (diff > 1) {
          currentStreak = 1;
        }
      }
      if (currentStreak > maxStreak) maxStreak = currentStreak;
      prevDate = date;
    }
    return maxStreak;
  }

  String _formatDistance(int val) {
    return val.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Top Status Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "MISSION STATUS: OPERATIONAL",
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFFF5A623),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      "ASTRELLA",
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFFF5A623),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: SizedBox(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFF5A623), height: 1, thickness: 1),

            // Main Content Area
            Expanded(
              child: Stack(
                children: [
                  // Star Chart Background
                  CustomPaint(
                    size: Size.infinite,
                    painter: StarChartPainter(
                      stars: _stars,
                      starSizes: _starSizes,
                      travelProgress: (_totalLyTraveled / 10000.0).clamp(0.0, 1.0),
                      scrollOffset: _driftController.value,
                    ),
                  ),
                  
                  // Content Overlay
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Distance Card
                        Align(
                          alignment: Alignment.topCenter,
                          child: CustomPaint(
                            painter: BracketPainter(),
                            child: Container(
                              color: const Color(0xFF1A1A1A),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "TOTAL DISTANCE",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5A623),
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_formatDistance(_totalLyTraveled)} LY",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5F5F0),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "TRAVELED",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5A623),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Bottom Coordinates Panel
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A1A),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.tag, color: Color(0xFFF5F5F0), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "REALTIME_COORDINATES",
                                        style: GoogleFonts.spaceMono(
                                          color: const Color(0xFFF5F5F0),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "${DateTime.now().toUtc().toString().substring(11, 16)} UTC",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5F5F0),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildCoordinateColumn("ALPHA_V", _alphaV.toStringAsFixed(3))),
                                  const VerticalDivider(color: Color(0xFFF5A623), width: 1, thickness: 1),
                                  Expanded(child: _buildCoordinateColumn("GAMMA_R", _gammaR.toStringAsFixed(3))),
                                  const VerticalDivider(color: Color(0xFFF5A623), width: 1, thickness: 1),
                                  Expanded(child: _buildCoordinateColumn("DELTA_Z", _deltaZ.toStringAsFixed(3))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Side Readouts
                  Positioned(
                    right: 16,
                    top: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildSideReadout("TOTAL_SESSIONS", _totalSessions.toString()),
                        const SizedBox(height: 16),
                        _buildSideReadout("BEST_STREAK", "$_bestStreak DAYS"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildCoordinateColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFF5F5F0).withOpacity(0.6),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFF5A623),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSideReadout(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(left: BorderSide(color: Color(0xFFF5A623), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: const Color(0xFFF5F5F0).withOpacity(0.6),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: const Color(0xFFF5F5F0),
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
            _buildNavItem(context, "NAV", Icons.explore, true),
            _buildNavItem(context, "SCIENCE", Icons.science, false),
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
          if (label == "ENGINE") {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => EngineConsoleScreen(),
                transitionDuration: Duration.zero,
              ),
            );
          } else if (label == "SCIENCE") {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => ScienceScreen(),
                transitionDuration: Duration.zero,
              ),
            );
          } else if (label == "LOG") {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => LogScreen(),
                transitionDuration: Duration.zero,
              ),
            );
          }
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

class StarChartPainter extends CustomPainter {
  final List<Offset> stars;
  final List<double> starSizes;
  final double travelProgress;
  final double scrollOffset;

  StarChartPainter({
    required this.stars,
    required this.starSizes,
    required this.travelProgress,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stars
    final starPaint = Paint()..color = const Color(0xFFF5F5F0);
    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];
      final dx = star.dx * size.width;
      // Formula: final adjustedY = (star.dy - scrollOffset * size.height) % size.height
      // Note: star.dy is normalized (0..1), so we scale it to screen height first
      final starY = star.dy * size.height;
      final adjustedY = (starY - scrollOffset * size.height) % size.height;
      canvas.drawCircle(Offset(dx, adjustedY), starSizes[i], starPaint);
    }

    // Draw dashed trajectory line
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.9); // bottom-left
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.7, // control point
      size.width * 0.9, size.height * 0.1, // top-right
    );

    final linePaint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    _drawDashedPath(canvas, path, linePaint);

    // Draw ship icon at mid-path
    final p0x = size.width * 0.1, p0y = size.height * 0.9;
    final p1x = size.width * 0.5, p1y = size.height * 0.7;
    final p2x = size.width * 0.9, p2y = size.height * 0.1;

    // Evaluate quadratic bezier at t=travelProgress
    final t = travelProgress;
    final shipX = (1 - t) * (1 - t) * p0x + 2 * (1 - t) * t * p1x + t * t * p2x;
    final shipY = (1 - t) * (1 - t) * p0y + 2 * (1 - t) * t * p1y + t * t * p2y;

    // Evaluate tangent vector at P'(t) = 2(1-t)(P1-P0) + 2t(P2-P1)
    final dx = 2 * (1 - t) * (p1x - p0x) + 2 * t * (p2x - p1x);
    final dy = 2 * (1 - t) * (p1y - p0y) + 2 * t * (p2y - p1y);
    final angle = math.atan2(dy, dx);

    // Compass arrow icon
    final iconPaint = Paint()
      ..color = const Color(0xFFF5F5F0)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(shipX, shipY);
    // Point arrow in direction of tangent. Added pi/2 because the icon is drawn pointing UP.
    canvas.rotate(angle + math.pi / 2);

    final iconPath = Path();
    iconPath.moveTo(0, -12);
    iconPath.lineTo(8, 8);
    iconPath.lineTo(0, 4);
    iconPath.lineTo(-8, 8);
    iconPath.close();

    canvas.drawPath(iconPath, iconPaint);
    canvas.restore();
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    double distance = 0.0;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarChartPainter oldDelegate) => true;
}

class BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F5F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const length = 12.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, length), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
