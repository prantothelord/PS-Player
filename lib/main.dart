import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF050505),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PSPlayerApp());
}

class PSPlayerApp extends StatelessWidget {
  const PSPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2A2A),
          secondary: Colors.white,
          surface: Color(0xFF121212),
        ),
      ),
      home: const PSPlayerHome(),
    );
  }
}

class TrackItem {
  final String title;
  final String artist;
  final Duration duration;
  final Color accent;

  const TrackItem({
    required this.title,
    required this.artist,
    required this.duration,
    required this.accent,
  });
}

class PSPlayerHome extends StatefulWidget {
  const PSPlayerHome({super.key});

  @override
  State<PSPlayerHome> createState() => _PSPlayerHomeState();
}

class _PSPlayerHomeState extends State<PSPlayerHome>
    with SingleTickerProviderStateMixin {
  final List<TrackItem> _tracks = const [
    TrackItem(
      title: 'Night Pulse // 01',
      artist: 'PS Studio',
      duration: Duration(minutes: 3, seconds: 24),
      accent: Color(0xFFFF2A2A),
    ),
    TrackItem(
      title: 'Glass Horizon',
      artist: 'Nothing Lab',
      duration: Duration(minutes: 4, seconds: 10),
      accent: Color(0xFF64D2FF),
    ),
    TrackItem(
      title: 'Dot Matrix Echo',
      artist: 'Dhaka Synth',
      duration: Duration(minutes: 2, seconds: 58),
      accent: Color(0xFFFF2A2A),
    ),
    TrackItem(
      title: 'Midnight Drift',
      artist: 'Mono Collective',
      duration: Duration(minutes: 3, seconds: 45),
      accent: Color(0xFFFF9F0A),
    ),
  ];

  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  int _selectedTab = 0;
  String _query = '';
  Duration _position = const Duration(seconds: 42);
  Timer? _ticker;

  final List<double> _eqBands = [2.0, 4.0, 0.0, 3.0, 5.0];
  final List<String> _eqLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPlaying || !mounted) return;
      setState(() {
        final total = _tracks[_currentIndex].duration.inSeconds;
        if (_position.inSeconds + 1 >= total) {
          _nextTrack();
        } else {
          _position += const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  TrackItem get _currentTrack => _tracks[_currentIndex];

  void _selectTrack(int index) {
    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
      _isPlaying = true;
    });
  }

  void _nextTrack() {
    setState(() {
      if (_isRepeat) {
        _position = Duration.zero;
        return;
      }
      if (_isShuffle) {
        _currentIndex = Random().nextInt(_tracks.length);
      } else {
        _currentIndex = (_currentIndex + 1) % _tracks.length;
      }
      _position = Duration.zero;
    });
  }

  void _prevTrack() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _tracks.length) % _tracks.length;
      _position = Duration.zero;
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final visibleTracks = _tracks.where((t) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotMatrixPainter())),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF2A2A).withOpacity(0.14),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildSearchField(),
                _buildTabRow(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: visibleTracks.length,
                    itemBuilder: (context, i) {
                      final item = visibleTracks[i];
                      final realIndex = _tracks.indexOf(item);
                      final active = realIndex == _currentIndex;
                      return _buildTrackTile(item, realIndex, active);
                    },
                  ),
                ),
                _buildLiquidMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2A2A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'PS PLAYER',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _circleAction(Icons.graphic_eq_rounded, _openEqualizer),
              const SizedBox(width: 8),
              _circleAction(Icons.tune_rounded, _openNowPlaying),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                icon: Icon(Icons.search_rounded, size: 18, color: Colors.white54),
                hintText: 'SEARCH TRACKS...',
                hintStyle: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.white38,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabRow() {
    final labels = ['LIBRARY', 'ALBUMS', 'ARTISTS'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _selectedTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFF2A2A)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFF2A2A)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                labels[i],
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrackTile(TrackItem item, int index, bool active) {
    return GestureDetector(
      onTap: () => _selectTrack(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFF2A2A).withOpacity(0.14)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFFFF2A2A).withOpacity(0.6)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                active && _isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.music_note_rounded,
                color: active ? const Color(0xFFFF2A2A) : Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: active ? const Color(0xFFFF2A2A) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.artist,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Text(
              _fmt(item.duration),
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidMiniPlayer() {
    return GestureDetector(
      onTap: _openNowPlaying,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentTrack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _currentTrack.artist,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: _prevTrack,
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isPlaying = !_isPlaying),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2A2A),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: _nextTrack,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openNowPlaying() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C0C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) {
          final maxSec = max(1, _currentTrack.duration.inSeconds).toDouble();
          final curSec = _position.inSeconds.toDouble().clamp(0.0, maxSec);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NOW PLAYING // PS OS',
                  style: TextStyle(letterSpacing: 2, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Text(
                  _currentTrack.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTrack.artist,
                  style: const TextStyle(color: Colors.white54),
                ),
                Slider(
                  value: curSec,
                  max: maxSec,
                  activeColor: const Color(0xFFFF2A2A),
                  onChanged: (v) {
                    setState(() => _position = Duration(seconds: v.toInt()));
                    setModal(() {});
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position), style: const TextStyle(fontSize: 11)),
                    Text(
                      _fmt(_currentTrack.duration),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: _isShuffle
                            ? const Color(0xFFFF2A2A)
                            : Colors.white54,
                      ),
                      onPressed: () {
                        setState(() => _isShuffle = !_isShuffle);
                        setModal(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 32),
                      onPressed: () {
                        _prevTrack();
                        setModal(() {});
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isPlaying = !_isPlaying);
                        setModal(() {});
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF2A2A),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 32,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 32),
                      onPressed: () {
                        _nextTrack();
                        setModal(() {});
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: _isRepeat
                            ? const Color(0xFFFF2A2A)
                            : Colors.white54,
                      ),
                      onPressed: () {
                        setState(() => _isRepeat = !_isRepeat);
                        setModal(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openEqualizer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C0C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'EQUALIZER // 5-BAND',
                  style: TextStyle(letterSpacing: 2, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (i) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 140,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _eqBands[i],
                              min: -6,
                              max: 6,
                              activeColor: const Color(0xFFFF2A2A),
                              onChanged: (v) {
                                setState(() => _eqBands[i] = v);
                                setModal(() {});
                              },
                            ),
                          ),
                        ),
                        Text(
                          _eqLabels[i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.04);
    for (double x = 0; x < size.width; x += 20) {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
