import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'dart:convert';
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


  @override
  void initState() {
    super.initState();
    _currentCity = context.tr('fetching_gps');
    _getWeatherFromGPS();
  }

  Future<void> _getWeatherFromGPS() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentCity = context.tr('gps_disabled'));
      return;
    }
    
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentCity = context.tr('gps_denied'));
        return;
      }
    }
    
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    String unknownLoc = context.tr('gps_unknown');
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks[0];
        String loc = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? unknownLoc;
        if (loc.isEmpty) loc = unknownLoc;
        if (mounted) setState(() => _currentCity = loc);
      }
    } catch (e) {
      if (mounted) setState(() => _currentCity = unknownLoc);
    }
    
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _outdoorTemp = '${data['current_weather']['temperature'].round()}';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _outdoorTemp = context.tr('error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF2C3E50), const Color(0xFF1A1A1A)] : [const Color(0xFF4A90E2), const Color(0xFF50E3C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF4A90E2)).withOpacity(0.3), 
            blurRadius: 24, 
            offset: const Offset(0, 12)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_currentCity, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
                onPressed: _getWeatherFromGPS, 
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.home_rounded, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(context.tr('temp_indoor'), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) { 
                        String tempStr = ref.watch(mqttIndoorTempProvider);
                        double? tempVal = double.tryParse(tempStr);
                        bool isDanger = tempVal != null && tempVal >= 50.0;
                        
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$tempStr°', style: TextStyle(color: isDanger ? Colors.redAccent : Colors.white, fontSize: 48, fontWeight: FontWeight.w200, height: 1.0)),
                            if (isDanger)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 70, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_rounded, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(context.tr('temp_outdoor'), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$_outdoorTemp°', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200, height: 1.0)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}