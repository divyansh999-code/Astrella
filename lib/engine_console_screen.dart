import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

import 'log_screen.dart';
import 'anomalies.dart';
import 'nav_screen.dart';
import 'science_screen.dart';

class EngineConsoleScreen extends StatefulWidget {
  const EngineConsoleScreen({super.key});

  @override
  State<EngineConsoleScreen> createState() => _EngineConsoleScreenState();
}

class _EngineConsoleScreenState extends State<EngineConsoleScreen> with WidgetsBindingObserver {
  int totalBurnSeconds = 25 * 60; // 25:00
  int remainingSeconds = 25 * 60;
  Timer? _countdownTimer;
  Timer? _clockTimer;
  bool isBurning = false;
  bool _isPreFlight = true;
  String _missionName = "AWAITING PARAMETERS";
  
  AudioPlayer? _audioPlayer;
  bool _ambientSoundEnabled = false;
  
  final TextEditingController _missionNameController = TextEditingController();
  final TextEditingController _burnDurationController = TextEditingController(text: '25');

  int todayBurn = 0;
  int activeStreak = 0;
  int lyToday = 0;
  int hullIntegrity = 100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSession();
    _loadStats();
    _loadAmbientSoundPreference();
    _audioPlayer = AudioPlayer();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _clockTimer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _missionNameController.dispose();
    _burnDurationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSession();
    }
  }

  Future<void> _saveSession(String missionName, int totalSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('burn_mission_name', missionName);
    await prefs.setInt('burn_start_time', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('burn_total_seconds', totalSeconds);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('burn_mission_name');
    await prefs.remove('burn_start_time');
    await prefs.remove('burn_total_seconds');
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString('mission_sessions');
    hullIntegrity = prefs.getInt('hull_integrity') ?? 100;

    if (sessionsJson != null) {
      final List<dynamic> sessions = jsonDecode(sessionsJson);
      final now = DateTime.now();
      final todayStr = "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}";

      todayBurn = 0;
      lyToday = 0;
      Set<String> activeDates = {};

      for (var session in sessions) {
        final chrono = session['chronoStamp'] as String;
        final dateStr = chrono.split(' | ')[0];
        activeDates.add(dateStr);

        if (dateStr == todayStr) {
          final durationParts = (session['duration'] as String).split(':');
          final minutes = int.tryParse(durationParts[0]) ?? 0;
          todayBurn += minutes;
          lyToday += (session['ly_earned'] as int? ?? 0);
        }
      }
      activeStreak = _calculateCurrentStreak(activeDates);
    }
    if (mounted) setState(() {});
  }

  int _calculateCurrentStreak(Set<String> activeDates) {
    if (activeDates.isEmpty) return 0;
    int streak = 0;
    DateTime checkDate = DateTime.now();
    bool first = true;

    while (true) {
      final dateStr = "${checkDate.year}.${checkDate.month.toString().padLeft(2, '0')}.${checkDate.day.toString().padLeft(2, '0')}";
      if (activeDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
        first = false;
      } else {
        if (first) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          final yesterdayStr = "${checkDate.year}.${checkDate.month.toString().padLeft(2, '0')}.${checkDate.day.toString().padLeft(2, '0')}";
          if (!activeDates.contains(yesterdayStr)) return 0;
          first = false;
          continue;
        }
        break;
      }
    }
    return streak;
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeMs = prefs.getInt('burn_start_time');
    final totalSeconds = prefs.getInt('burn_total_seconds');
    final missionName = prefs.getString('burn_mission_name');

    if (startTimeMs != null && totalSeconds != null && missionName != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (nowMs - startTimeMs) ~/ 1000;
      final remaining = totalSeconds - elapsedSeconds;

      if (remaining > 0) {
        setState(() {
          _isPreFlight = false;
          _missionName = missionName;
          totalBurnSeconds = totalSeconds;
          remainingSeconds = remaining;
          isBurning = true;
        });
        _startCountdown();
      } else {
        // Burn completed while backgrounded
        setState(() {
          _isPreFlight = false;
          _missionName = missionName;
          totalBurnSeconds = totalSeconds;
          remainingSeconds = 0;
          isBurning = false;
        });
        _endBurn();
      }
    }
  }

  Future<void> _loadAmbientSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ambientSoundEnabled = prefs.getBool('ambient_sound_enabled') ?? false;
    });
  }

  Future<void> _updateAmbientSoundPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ambient_sound_enabled', enabled);
    setState(() {
      _ambientSoundEnabled = enabled;
    });
    
    if (isBurning) {
      if (enabled) {
        _startAmbientSound();
      } else {
        _stopAmbientSound();
      }
    }
  }

  void _startAmbientSound() async {
    if (_ambientSoundEnabled && _audioPlayer != null) {
      try {
        await _audioPlayer!.setAsset('assets/sounds/burn_ambient.mp3');
        await _audioPlayer!.setLoopMode(LoopMode.one);
        _audioPlayer!.play();
      } catch (e) {
        debugPrint("AUDIO_ERROR: $e");
      }
    }
  }

  void _stopAmbientSound() {
    _audioPlayer?.stop();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (remainingSeconds > 0) {
            remainingSeconds--;
          } else {
            _endBurn();
          }
        });
      }
    });
  }

  void _startBurn() {
    if (_isPreFlight) {
      final missionName = _missionNameController.text.trim();
      final durationText = _burnDurationController.text.trim();
      final duration = int.tryParse(durationText);

      if (missionName.isEmpty || duration == null || duration < 1 || duration > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A1A1A),
            content: Text(
              "MISSION PARAMETERS INVALID",
              style: GoogleFonts.spaceMono(color: const Color(0xFFFF3B30)),
            ),
          ),
        );
        return;
      }

      setState(() {
        _isPreFlight = false;
        _missionName = missionName;
        totalBurnSeconds = duration * 60;
        remainingSeconds = totalBurnSeconds;
        isBurning = true;
      });
      
      _saveSession(missionName, totalBurnSeconds);
      _startAmbientSound();
      _startCountdown();
    } else {
      if (isBurning || remainingSeconds <= 0) return;
      
      setState(() {
        isBurning = true;
      });
      
      _saveSession(_missionName, totalBurnSeconds);
      _startAmbientSound();
      _startCountdown();
    }
  }

  Future<void> _processBurnResult(String status) async {
    final prefs = await SharedPreferences.getInstance();
    
    final int durationMinutes = totalBurnSeconds ~/ 60;
    int lyEarned = 0;
    
    if (status == "SUCCESS") {
      lyEarned = durationMinutes * 10;
    } else if (status == "PARTIAL") {
      lyEarned = durationMinutes * 5;
    } else {
      lyEarned = 0;
    }
    
    int currentTotalLy = prefs.getInt('total_ly_traveled') ?? 0;
    int newTotalLy = currentTotalLy + lyEarned;
    await prefs.setInt('total_ly_traveled', newTotalLy);

    final String? sessionsJson = prefs.getString('mission_sessions');
    List<dynamic> sessions = [];
    if (sessionsJson != null) {
      sessions = jsonDecode(sessionsJson);
    }

    final int sessionIdCount = sessions.length + 1;
    final String sessionId = "MS-${sessionIdCount.toString().padLeft(3, '0')}";
    final DateTime now = DateTime.now();
    final String chronoStamp = "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final String durationStr = "${durationMinutes.toString().padLeft(2, '0')}:00";

    final Map<String, dynamic> newSession = {
      "id": sessionId,
      "missionName": _missionName,
      "chronoStamp": chronoStamp,
      "duration": durationStr,
      "status": status,
      "ly_earned": lyEarned,
    };

    sessions.add(newSession);
    await prefs.setString('mission_sessions', jsonEncode(sessions));

    int currentHull = prefs.getInt('hull_integrity') ?? 100;
    if (status == "SUCCESS") {
      currentHull = math.min(100, currentHull + 5);
    } else if (status == "ABORTED") {
      currentHull = math.max(0, currentHull - 10);
    }
    await prefs.setInt('hull_integrity', currentHull);
    
    _loadStats();

    // Discovery Roll Implementation
    if (durationMinutes < 10 || status == "ABORTED") {
      return;
    }

    Anomaly? discovered;
    final int roll = math.Random().nextInt(100); // 0-99 provides 100 possible outcomes

    if (status == "SUCCESS") {
      if (durationMinutes >= 90) {
        if (roll < 10) { /* NOTHING */ } 
        else if (roll < 40) discovered = _pickByRarity('COMMON');
        else if (roll < 80) discovered = _pickByRarity('RARE');
        else discovered = _pickByRarity('LEGENDARY');
      } else if (durationMinutes >= 50) {
        if (roll < 20) { /* NOTHING */ }
        else if (roll < 60) discovered = _pickByRarity('COMMON');
        else if (roll < 90) discovered = _pickByRarity('RARE');
        else discovered = _pickByRarity('LEGENDARY');
      } else if (durationMinutes >= 25) {
        if (roll < 40) { /* NOTHING */ }
        else if (roll < 85) discovered = _pickByRarity('COMMON');
        else if (roll < 98) discovered = _pickByRarity('RARE');
        else discovered = _pickByRarity('LEGENDARY');
      } else if (durationMinutes >= 10) {
        if (roll < 70) { /* NOTHING */ }
        else if (roll < 98) discovered = _pickByRarity('COMMON');
        else discovered = _pickByRarity('RARE');
      }
    } else if (status == "PARTIAL") {
      if (durationMinutes >= 90) {
        if (roll < 30) { /* NOTHING */ }
        else if (roll < 75) discovered = _pickByRarity('COMMON');
        else if (roll < 95) discovered = _pickByRarity('RARE');
        else discovered = _pickByRarity('LEGENDARY');
      } else if (durationMinutes >= 50) {
        if (roll < 45) { /* NOTHING */ }
        else if (roll < 85) discovered = _pickByRarity('COMMON');
        else if (roll < 98) discovered = _pickByRarity('RARE');
        else discovered = _pickByRarity('LEGENDARY');
      } else if (durationMinutes >= 25) {
        if (roll < 65) { /* NOTHING */ }
        else if (roll < 95) discovered = _pickByRarity('COMMON');
        else discovered = _pickByRarity('RARE');
      } else if (durationMinutes >= 10) {
        if (roll < 85) { /* NOTHING */ }
        else discovered = _pickByRarity('COMMON');
      }
    }

    if (discovered != null) {
      await _showDiscoveryOverlay(discovered);
    }
  }

  Future<void> _endBurn() async {
    _stopAmbientSound();
    _countdownTimer?.cancel();
    _clearSession();
    setState(() {
      isBurning = false;
    });

    final String? status = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
              side: BorderSide(color: Color(0xFFF5A623)),
              borderRadius: BorderRadius.zero),
          title: Text(
            "BURN COMPLETE — MISSION LOG UPDATED",
            style: GoogleFonts.spaceMono(
              color: const Color(0xFFF5A623),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Text(
            "Engine thrust normalized. Selecting an option below will log the mission parameters and reset the console system.",
            style: GoogleFonts.spaceMono(
              color: const Color(0xFFF5F5F0),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop("SUCCESS"),
              child: Text(
                "FULL BURN",
                style: GoogleFonts.spaceMono(color: const Color(0xFFF5A623)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop("PARTIAL"),
              child: Text(
                "PARTIAL BURN",
                style: GoogleFonts.spaceMono(color: const Color(0xFFF5F5F0)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop("ABORTED"),
              child: Text(
                "ABORTED",
                style: GoogleFonts.spaceMono(color: const Color(0xFFFF3B30)),
              ),
            ),
          ],
        );
      },
    );

    if (status != null) {
      await _processBurnResult(status);
      _resetConsole();
    }
  }

  void _resetConsole() {
    _clearSession();
    setState(() {
      _isPreFlight = true;
      isBurning = false;
      _missionNameController.clear();
      _burnDurationController.text = '25';
    });
  }

  Anomaly? _pickByRarity(String rarity) {
    final pool = allAnomalies.where((a) => a.rarity == rarity).toList();
    if (pool.isEmpty) return null;
    return pool[math.Random().nextInt(pool.length)];
  }

  Future<void> _showDiscoveryOverlay(Anomaly anomaly) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(
                "ANOMALY DETECTED",
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFF5A623),
                  fontSize: 12,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.asset(
                  'assets/anomalies/${anomaly.id}.jpg',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: const Color(0xFF2A2A2A),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: anomaly.rarity == 'LEGENDARY' 
                    ? const Color(0xFFF5A623) 
                    : (anomaly.rarity == 'RARE' ? const Color(0xFF1A3A5C) : const Color(0xFF2A2A2A)),
                ),
                child: Text(
                  anomaly.rarity,
                  style: GoogleFonts.spaceMono(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                anomaly.name,
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  anomaly.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: OutlinedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final discoveryLogJson = prefs.getString('discovery_log');
                    List<dynamic> discoveryLog = [];
                    if (discoveryLogJson != null) {
                      discoveryLog = jsonDecode(discoveryLogJson);
                    }
                    
                    final now = DateTime.now();
                    final timestamp = "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                    
                    final newEntry = {
                      "id": anomaly.id,
                      "name": anomaly.name,
                      "rarity": anomaly.rarity,
                      "description": anomaly.description,
                      "discoveredAt": timestamp,
                    };
                    
                    discoveryLog.add(newEntry);
                    await prefs.setString('discovery_log', jsonEncode(discoveryLog));
                    
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF5A623), width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(
                    "ADD TO ARCHIVE",
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFFF5A623),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _stationTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = totalBurnSeconds > 0 ? remainingSeconds / totalBurnSeconds : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isPreFlight ? "SYSTEM STATUS: PRE-FLIGHT" : "SYSTEM STATUS: OPERATIONAL",
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFFF5A623),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    "STATION_TIME: $_stationTime",
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(height: 16),

                          if (_isPreFlight) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "MISSION_DESIGNATION",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5A623),
                                      fontSize: 10,
                                    ),
                                  ),
                                  TextField(
                                    controller: _missionNameController,
                                    textCapitalization: TextCapitalization.characters,
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5F5F0),
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1A1A1A),
                                      hintText: "ENTER MISSION NAME...",
                                      hintStyle: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5F5F0).withOpacity(0.4),
                                      ),
                                      enabledBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFFF5A623)),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFFF5A623), width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    "BURN_DURATION (MINUTES)",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5A623),
                                      fontSize: 10,
                                    ),
                                  ),
                                  TextField(
                                    controller: _burnDurationController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5F5F0),
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1A1A1A),
                                      hintText: "25",
                                      hintStyle: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5F5F0).withOpacity(0.4),
                                      ),
                                      enabledBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFFF5A623)),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFFF5A623), width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ] else ...[
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: CustomPaint(
                                    painter: TimerPainter(progress: progress),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "REMAINING_BURN",
                                      style: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5F5F0),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTime(remainingSeconds),
                                      style: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5F5F0),
                                        fontSize: 56,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isBurning ? "BURN_ACTIVE" : "SEC_STABLE",
                                      style: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5A623),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              border: Border(
                                left: BorderSide(color: Color(0xFFF5A623), width: 4),
                                right: BorderSide(color: Color(0xFFF5A623), width: 4),
                              ),
                            ),
                            child: Text(
                              _missionName,
                              style: GoogleFonts.spaceMono(
                                color: const Color(0xFFF5F5F0),
                                fontSize: 16,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTelemetryColumn("TODAY_BURN", "$todayBurn MIN"),
                                  ),
                                  const VerticalDivider(color: Color(0xFFF5A623), width: 1, thickness: 1),
                                  Expanded(
                                    child: _buildTelemetryColumn("ACTIVE_STREAK", "$activeStreak DAYS"),
                                  ),
                                  const VerticalDivider(color: Color(0xFFF5A623), width: 1, thickness: 1),
                                  Expanded(
                                    child: _buildTelemetryColumn("LY_TODAY", "$lyToday LY"),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                    Text(
                                      "HULL_INTEGRITY_PROTOCOL",
                                      style: GoogleFonts.spaceMono(
                                        color: const Color(0xFFF5F5F0),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      hullIntegrity >= 80 ? "NOMINAL" : (hullIntegrity >= 50 ? "DEGRADED" : "CRITICAL"),
                                      style: GoogleFonts.spaceMono(
                                        color: hullIntegrity >= 80 
                                          ? const Color(0xFFF5F5F0) 
                                          : (hullIntegrity >= 50 ? const Color(0xFFF5A623) : const Color(0xFFFF3B30)),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      color: const Color(0xFF444444),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: hullIntegrity / 100.0,
                                      child: Container(
                                        height: 6,
                                        color: hullIntegrity >= 80 
                                          ? const Color(0xFFF5A623) 
                                          : (hullIntegrity >= 50 ? const Color(0xFFF5A623) : const Color(0xFFFF3B30)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (!_isPreFlight && isBurning) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.volume_up, color: Color(0xFFF5A623), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    "AMBIENT_SOUND",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF5A623),
                                      fontSize: 10,
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildToggleOption("OFF", !_ambientSoundEnabled),
                                  _buildToggleOption("ON", _ambientSoundEnabled),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GestureDetector(
                              onTap: _startBurn,
                              child: Container(
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(color: const Color(0xFFF5A623), width: 2),
                                ),
                                child: Text(
                                  "INITIATE BURN",
                                  style: GoogleFonts.spaceMono(
                                    color: const Color(0xFFF5A623),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTelemetryColumn(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFF5F5F0).withOpacity(0.6),
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFF5F5F0),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      color: const Color(0xFF000000),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(context, "ENGINE", Icons.tune, true),
            _buildNavItem(context, "NAV", Icons.explore, false),
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
          if (label == "NAV") {
            Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => NavScreen(), transitionDuration: Duration.zero));
          } else if (label == "SCIENCE") {
            Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => ScienceScreen(), transitionDuration: Duration.zero));
          } else if (label == "LOG") {
            Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => LogScreen(), transitionDuration: Duration.zero));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: isActive ? const Color(0xFFF5A623) : const Color(0xFF1A1A1A),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? const Color(0xFF000000) : const Color(0xFFF5F5F0), size: 28),
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

  Widget _buildToggleOption(String label, bool active) {
    return GestureDetector(
      onTap: () => _updateAmbientSoundPreference(label == "ON"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF5A623) : const Color(0xFF1A1A1A),
          border: active ? null : Border.all(color: const Color(0xFFF5F5F0).withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            color: active ? Colors.black : const Color(0xFFF5F5F0).withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class TimerPainter extends CustomPainter {
  final double progress;
  TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    final arcPaint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square; 

    final startAngle = -math.pi / 2 + 2 * math.pi * (1.0 - progress);
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, arcPaint);
    }

    final tickPaint = Paint()..color = const Color(0xFFF5F5F0)..style = PaintingStyle.stroke..strokeWidth = 2;
    for (int i = 0; i < 4; i++) {
        final angle = i * math.pi / 2;
        canvas.drawLine(
          Offset(center.dx + (radius - 16.0) * math.cos(angle), center.dy + (radius - 16.0) * math.sin(angle)),
          Offset(center.dx + (radius + 8.0) * math.cos(angle), center.dy + (radius + 8.0) * math.sin(angle)),
          tickPaint
        );
    }
  }

  @override
  bool shouldRepaint(TimerPainter oldDelegate) => oldDelegate.progress != progress;
}
