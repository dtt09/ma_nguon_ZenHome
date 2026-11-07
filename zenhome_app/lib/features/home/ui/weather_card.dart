import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/animations/animated_counting_number.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class WeatherCard extends ConsumerStatefulWidget {
  const WeatherCard({super.key});

  @override
  ConsumerState<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends ConsumerState<WeatherCard> {
  String _currentCity = '';
  String _outdoorTemp = '--';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentCity = context.tr('fetching_gps');
        });
        _getWeatherFromGPS();
      }
    });
  }

  Future<void> _getWeatherFromGPS() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentCity = context.tr('gps_disabled');
            _isLoading = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _currentCity = context.tr('gps_denied');
              _isLoading = false;
            });
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      if (!mounted) return;
      String unknownLoc = context.tr('gps_unknown');
      try {
        List<geocoding.Placemark> placemarks =
            await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          geocoding.Placemark place = placemarks[0];
          String loc = place.locality ??
              place.subAdministrativeArea ??
              place.administrativeArea ??
              unknownLoc;
          if (loc.isEmpty) loc = unknownLoc;
          if (mounted) setState(() => _currentCity = loc);
        }
      } catch (e) {
        if (mounted) setState(() => _currentCity = unknownLoc);
      }

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _outdoorTemp = '${data['current_weather']['temperature'].round()}';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _outdoorTemp = '--');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    final LinearGradient cardGradient = isDark
        ? LinearGradient(
            colors: [
              zen.primaryDark.withOpacity(0.68),
              const Color(0xFF0F172A).withOpacity(0.72),
              const Color(0xFF0A1020).withOpacity(0.76),
            ],
            stops: const [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              zen.primary.withOpacity(0.86),
              Color.lerp(zen.primary, const Color(0xFF0284C7), 0.55)!
                  .withOpacity(0.84),
              zen.primaryLight.withOpacity(0.82),
            ],
            stops: const [0.0, 0.52, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return ZenLiquidGlass(
      borderRadius: 28,
      blurSigma: 22.0,
      rimWidth: 1.35,
      glowColor: isDark ? zen.primaryAccent : zen.primary,
      customGradient: cardGradient,
      customShadows: [
        BoxShadow(
          color: zen.primary.withOpacity(isDark ? 0.24 : 0.28),
          blurRadius: 26,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ],
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    zen.primaryAccent.withOpacity(0.32),
                    zen.primaryAccent.withOpacity(0.0),
                  ],
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1.14, 1.14),
                  duration: 3200.ms,
                  curve: Curves.easeInOut,
                ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        surfaceColor: Colors.white.withOpacity(0.16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _currentCity,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ZenLiquidGlass(
                      blurSigma: 0,
                      width: 34,
                      height: 34,
                      borderRadius: 17,
                      alignment: Alignment.center,
                      surfaceColor: Colors.white.withOpacity(0.16),
                      onTap: _getWeatherFromGPS,
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                          .animate(target: _isLoading ? 1 : 0)
                          .rotate(duration: 800.ms),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    // Nhiệt độ trong nhà
                    Expanded(
                      child: ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        surfaceColor: Colors.white.withOpacity(0.12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.home_rounded,
                                  color: Colors.white70,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    context.tr('temp_indoor'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                final String tempStr =
                                    ref.watch(mqttIndoorTempProvider);
                                final double? tempVal =
                                    double.tryParse(tempStr);
                                final bool isDanger =
                                    tempVal != null && tempVal >= 50.0;

                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      if (tempVal != null)
                                        AnimatedCountingNumber(
                                          number: tempVal,
                                          fractionDigits:
                                              tempStr.contains('.') ? 1 : 0,
                                          style: TextStyle(
                                            color: isDanger
                                                ? const Color(0xFFF87171)
                                                : Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: -1,
                                            height: 1.0,
                                          ),
                                        )
                                      else
                                        Text(
                                          tempStr,
                                          style: TextStyle(
                                            color: isDanger
                                                ? const Color(0xFFF87171)
                                                : Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: -1,
                                            height: 1.0,
                                          ),
                                        ),
                                      const Text(
                                        '°C',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      if (isDanger) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFF87171),
                                          size: 20,
                                        )
                                            .animate(
                                              onPlay: (controller) =>
                                                  controller.repeat(
                                                reverse: true,
                                              ),
                                            )
                                            .scale(
                                              begin: const Offset(0.9, 0.9),
                                              end: const Offset(1.2, 1.2),
                                              duration: 600.ms,
                                            ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nhiệt độ ngoài trời
                    Expanded(
                      child: ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        surfaceColor: Colors.white.withOpacity(0.12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.cloud_rounded,
                                  color: Colors.white70,
                                  size: 15,
                                )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(reverse: true),
                                    )
                                    .moveY(
                                      begin: -1.5,
                                      end: 1.5,
                                      duration: 2200.ms,
                                      curve: Curves.easeInOut,
                                    ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    context.tr('temp_outdoor'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final double? outVal =
                                          double.tryParse(_outdoorTemp);
                                      if (outVal != null) {
                                        return AnimatedCountingNumber(
                                          number: outVal,
                                          fractionDigits:
                                              _outdoorTemp.contains('.')
                                                  ? 1
                                                  : 0,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: -1,
                                            height: 1.0,
                                          ),
                                        );
                                      }
                                      return Text(
                                        _outdoorTemp,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w300,
                                          letterSpacing: -1,
                                          height: 1.0,
                                        ),
                                      );
                                    },
                                  ),
                                  const Text(
                                    '°C',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
