import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../auth_gate.dart'; // update path if needed

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({Key? key}) : super(key: key);

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  late final AnimationController _dotsCtrl;
  bool _lottieLoaded = false;
  bool _assetAvailable = false;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _progressCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    });

    // Check whether the local PNG asset exists by trying to precache it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/rail_aid_logo.png'), context)
          .then((_) {
        if (mounted) setState(() => _assetAvailable = true);
      }).catchError((_) {
        if (mounted) setState(() => _assetAvailable = false);
      });
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  Widget _buildAnimatedDots() {
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: _dotsCtrl,
        builder: (_, __) {
          final t = _dotsCtrl.value;
          int active = (t * 3).floor() % 3;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final on = i == active;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 10 : 7,
                height: on ? 10 : 7,
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF1976D2) : Colors.black26,
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FBFF), Color(0xFFE8F0FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 36),

              // Modern header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.train, color: Color(0xFF0D47A1)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('RailAid',
                            style: TextStyle(
                                color: Color(0xFF0D47A1),
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Your railway helpdesk',
                            style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Center glass card with Lottie
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 26.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _assetAvailable
                                  ? Image.asset(
                                      'assets/images/rail_aid_logo.png',
                                      fit: BoxFit.contain,
                                      width: 160,
                                      height: 160,
                                    )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Lottie.network(
                                          'https://assets10.lottiefiles.com/packages/lf20_u4yrau.json',
                                          fit: BoxFit.contain,
                                          repeat: true,
                                          onLoaded: (composition) {
                                            if (mounted) setState(() => _lottieLoaded = true);
                                          },
                                        ),
                                        if (!_lottieLoaded)
                                          const Icon(Icons.train,
                                              size: 72,
                                              color: Color(0xFF1976D2)),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text('RailAid',
                            style: theme.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF0D47A1),
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('Report issues. Track responses.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54)),

                        const SizedBox(height: 18),

                        // Animated dots
                        _buildAnimatedDots(),

                        const SizedBox(height: 16),

                        // Progress bar with subtle rounded background
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedBuilder(
                              animation: _progressCtrl,
                              builder: (_, __) => LinearProgressIndicator(
                                value: _progressCtrl.value,
                                minHeight: 6,
                                color: const Color(0xFF1976D2),
                                backgroundColor: Colors.black12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer small text
              Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: Text('© ${DateTime.now().year} Railway Authority',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: Colors.black45)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
