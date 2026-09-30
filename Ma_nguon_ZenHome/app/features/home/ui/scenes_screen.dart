import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/home/ui/scene_section.dart';
import 'package:zenhome_app/features/home/ui/timer_section.dart';
import 'package:zenhome_app/features/home/ui/schedule_section.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart';

class ScenesScreen extends ConsumerWidget {
  const ScenesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttState = ref.watch(mqttConnectionStateProvider);
    final isOnline = ref.watch(espOnlineStateProvider);
    final isConnected = mqttState == 2 && isOnline;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: const Color(0xFF2A3A7C),
        onRefresh: () async {
          final activeConfig = ref.read(homeConfigProvider).activeConfig;
          ref.read(mqttRepositoryProvider).disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          ref.read(mqttRepositoryProvider).connect(
            userId: activeConfig.userId,
            mqttServer: activeConfig.mqttServer,
            mqttPrefix: activeConfig.mqttPrefix,
            dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
            mqttUser: activeConfig.mqttUser,
            mqttPass: activeConfig.mqttPass,
          );
          await Future.delayed(const Duration(seconds: 1));
        },
        child: AnimatedOpacity(
          opacity: isConnected ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 25.0, top: 10.0),
              child: Text(
                context.tr('scenes_subtitle'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ).animate().slideY(begin: -0.2, end: 0),
            
            AbsorbPointer(
              absorbing: !isConnected,
              child: const SceneSection(),
            ).animate(delay: 50.ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuart),
            const SizedBox(height: 30),
            
            AbsorbPointer(
              absorbing: !isConnected,
              child: const TimerSection(),
            ).animate(delay: 150.ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuart),
            const SizedBox(height: 30),
            
            AbsorbPointer(
              absorbing: !isConnected,
              child: const ScheduleSection(),
            ).animate(delay: 250.ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuart),
          ],
        ),
        ),
      ),
    );
  }
}