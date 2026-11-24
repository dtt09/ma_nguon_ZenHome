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
              Colors.white.withOpacity(0.88),
              Colors.white.withOpacity(0.74),
              Color.lerp(Colors.white, zen.primaryLight, 0.15)!.withOpacity(0.78),
            ],
            stops: const [0.0, 0.52, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return RepaintBoundary(
      child: ZenLiquidGlass(
        borderRadius: 28,
        blurSigma: 0.0,
        rimWidth: 1.2,
        glowColor: isDark ? zen.primaryAccent : zen.primary,
        customGradient: cardGradient,
        customShadows: [
          BoxShadow(
            color: isDark
                ? zen.primary.withOpacity(0.24)
                : Colors.black.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color: zen.primary.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
        ],
        child: Stack(
          children: [
            if (isDark)
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
                        zen.primaryAccent.withOpacity(0.28),
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
              )
            else
              Positioned(
                right: -25,
                top: -25,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        zen.primaryLight.withOpacity(0.18),
                        zen.primaryLight.withOpacity(0.0),
                      ],
                    ),
                  ),
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
                          surfaceColor: isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white.withOpacity(0.85),
                          customBorder: isDark
                              ? null
                              : Border.all(
                                  color: const Color(0xFFCBD5E1).withOpacity(0.6),
                                  width: 0.9,
                                ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: isDark ? zen.primaryAccent : zen.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _currentCity,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
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
                        surfaceColor: isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.white.withOpacity(0.85),
                        customBorder: isDark
                            ? null
                            : Border.all(
                                color: const Color(0xFFCBD5E1).withOpacity(0.6),
                                width: 0.9,
                              ),
                        onTap: _getWeatherFromGPS,
                        child: Icon(
                          Icons.refresh_rounded,
                          color: isDark ? Colors.white : const Color(0xFF334155),
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
                          surfaceColor: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.white.withOpacity(0.72),
                          customBorder: isDark
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE2E8F0).withOpacity(0.85),
                                  width: 0.9,
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.home_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('temp_indoor'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF475569),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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
                                  final Color dangerColor = isDark
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFDC2626);
                                  final Color normalNumberColor = isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A);
                                  final Color tempColor =
                                      isDanger ? dangerColor : normalNumberColor;

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
                                              color: tempColor,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -1,
                                              height: 1.0,
                                            ),
                                          )
                                        else
                                          Text(
                                            tempStr,
                                            style: TextStyle(
                                              color: tempColor,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -1,
                                              height: 1.0,
                                            ),
                                          ),
                                        Text(
                                          '°C',
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (isDanger) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: dangerColor,
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
                          surfaceColor: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.white.withOpacity(0.72),
                          customBorder: isDark
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE2E8F0).withOpacity(0.85),
                                  width: 0.9,
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.cloud_rounded,
                                    color: Color(0xFF0EA5E9),
                                    size: 16,
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
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('temp_outdoor'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF475569),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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
                                        final Color outdoorNumberColor = isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A);

                                        if (outVal != null) {
                                          return AnimatedCountingNumber(
                                            number: outVal,
                                            fractionDigits:
                                                _outdoorTemp.contains('.')
                                                    ? 1
                                                    : 0,
                                            style: TextStyle(
                                              color: outdoorNumberColor,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -1,
                                              height: 1.0,
                                            ),
                                          );
                                        }
                                        return Text(
                                          _outdoorTemp,
                                          style: TextStyle(
                                            color: outdoorNumberColor,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -1,
                                            height: 1.0,
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      '°C',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
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
      ),
    );
  }
}
