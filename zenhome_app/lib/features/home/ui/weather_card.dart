import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:zenhome_app/core/providers/mqtt_provider.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/animations/animated_counting_number.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
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
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentCity = context.tr('gps_denied');
            _isLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (!mounted) return;
      String unknownLoc = context.tr('gps_unknown');
      try {
        List<geocoding.Placemark> placemarks = await geocoding
            .placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          geocoding.Placemark place = placemarks[0];
          String loc =
              place.locality ??
              place.subAdministrativeArea ??
              place.administrativeArea ??
              unknownLoc;
          if (loc.isEmpty) loc = unknownLoc;
          if (mounted) setState(() => _currentCity = loc);
        } else if (mounted) {
          setState(() => _currentCity = unknownLoc);
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
      if (mounted) {
        setState(() {
          _outdoorTemp = '--';
          if (_currentCity == context.tr('fetching_gps')) {
            _currentCity = context.tr('gps_unknown');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ZenGlassCard.lightweight(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_currentCity, style: theme.textTheme.titleSmall),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(
                  context,
                ).refreshIndicatorSemanticLabel,
                onPressed: _isLoading ? null : _getWeatherFromGPS,
                icon: AnimatedRotation(
                  turns: _isLoading ? 0.5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: const Icon(Icons.refresh_rounded, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, bounds) {
              final indoor = Consumer(
                builder: (context, ref, _) => _TemperatureReading(
                  label: context.tr('temp_indoor'),
                  raw: ref.watch(mqttIndoorTempProvider),
                  icon: Icons.home_outlined,
                  warnWhenHot: true,
                ),
              );
              final outdoor = _TemperatureReading(
                label: context.tr('temp_outdoor'),
                raw: _outdoorTemp,
                icon: Icons.cloud_outlined,
              );
              final minReadingWidth =
                  108 + MediaQuery.textScalerOf(context).scale(24);
              if (bounds.maxWidth < 2 * minReadingWidth + 12) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [indoor, const Divider(height: 20), outdoor],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: indoor),
                  const SizedBox(width: 12),
                  Expanded(child: outdoor),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TemperatureReading extends StatelessWidget {
  const _TemperatureReading({
    required this.label,
    required this.raw,
    required this.icon,
    this.warnWhenHot = false,
  });

  final String label;
  final String raw;
  final IconData icon;
  final bool warnWhenHot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = double.tryParse(raw);
    final valid = value != null && value.isFinite;
    final warning = warnWhenHot && valid && value >= 50;
    final color = warning
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    final style = theme.textTheme.headlineMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (valid)
                AnimatedCountingNumber(
                  number: value,
                  fractionDigits: raw.contains('.') ? 1 : 0,
                  style: style,
                )
              else
                Text(raw, style: style),
              const SizedBox(width: 2),
              Text('°C', style: theme.textTheme.bodyMedium),
              if (warning) ...[
                const SizedBox(width: 5),
                Icon(Icons.warning_amber_rounded, size: 19, color: color),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
