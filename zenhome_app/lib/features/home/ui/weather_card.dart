import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

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
        List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
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

    // Gradient thời tiết phong cách Horizon sang trọng
    final LinearGradient cardGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF131B2E)],
            stops: [0.0, 0.6, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF0284C7)],
            stops: [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: cardGradient,
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.12 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF1E1B4B) : const Color(0xFF2563EB)).withOpacity(0.35),
            blurRadius: 26,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Ánh sáng phản chiếu nền (Ambient Backlight Circle)
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? const Color(0xFF6366F1) : const Color(0xFF38BDF8)).withOpacity(0.25),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng trên: Location pill + GPS Refresh Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Location Pill
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _currentCity,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Nút cập nhật thời tiết với hiệu ứng quay
                      InkWell(
                        onTap: _getWeatherFromGPS,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 19,
                          )
                              .animate(target: _isLoading ? 1 : 0)
                              .rotate(duration: 800.ms),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Hàng dưới: Nhiệt độ trong nhà & ngoài trời
                  Row(
                    children: [
                      // Khối nhiệt độ Trong nhà
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.home_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('temp_indoor'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  String tempStr = ref.watch(mqttIndoorTempProvider);
                                  double? tempVal = double.tryParse(tempStr);
                                  bool isDanger = tempVal != null && tempVal >= 50.0;

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        tempStr,
                                        style: TextStyle(
                                          color: isDanger ? const Color(0xFFF87171) : Colors.white,
                                          fontSize: 38,
                                          fontWeight: FontWeight.w300,
                                          letterSpacing: -1,
                                          height: 1.0,
                                        ),
                                      ),
                                      const Text(
                                        '°C',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      if (isDanger) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFF87171),
                                          size: 22,
                                        )
                                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.2, 1.2), duration: 600.ms),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Khối nhiệt độ Ngoài trời
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cloud_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('temp_outdoor'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _outdoorTemp,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: -1,
                                      height: 1.0,
                                    ),
                                  ),
                                  const Text(
                                    '°C',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
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