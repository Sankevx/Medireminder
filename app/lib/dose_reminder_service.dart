import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'api.dart';

class DoseReminderService {
  DoseReminderService._();

  static final instance = DoseReminderService._();

  static const _channel = AndroidNotificationChannel(
    'dose_reminders',
    'Recordatorios de medicamentos',
    description: 'Avisos de las dosis programadas en MediReminder.',
    importance: Importance.max,
  );
  static const _maximumScheduledNotifications = 450;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationsGranted = false;
  bool _hasExactAlarmPermission = false;

  Future<void> initialize() async {
    if (_initialized) return;

    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    _initialized = true;
  }

  Future<bool> requestPermissions(BuildContext context) async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      _notificationsGranted = true;
      return true;
    }

    final notificationsGranted =
        await android.requestNotificationsPermission() ?? true;
    if (!notificationsGranted) {
      _notificationsGranted = false;
      throw Exception(
        'Permite las notificaciones de MediReminder para recibir avisos de tus dosis.',
      );
    }
    _notificationsGranted = true;

    _hasExactAlarmPermission =
        await android.canScheduleExactNotifications() ?? false;
    if (!_hasExactAlarmPermission) {
      if (!context.mounted) return false;
      final allowExactTiming = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Avisos a la hora indicada'),
          content: const Text(
            'Android puede limitar las alarmas exactas para ahorrar batería. '
            'Si permites el acceso especial de alarmas, los recordatorios '
            'podrán sonar más cerca de la hora programada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (allowExactTiming == true && context.mounted) {
        await android.requestExactAlarmsPermission();
        _hasExactAlarmPermission =
            await android.canScheduleExactNotifications() ?? false;
      }
    }
    return _hasExactAlarmPermission;
  }

  Future<int> synchronizePendingDoses() async {
    await initialize();
    if (!_notificationsGranted) {
      throw Exception(
        'Activa las notificaciones para programar los avisos de tus dosis.',
      );
    }
    final doses = await Api.get('/doses/upcoming?days=30') as List;
    final pending = doses.take(_maximumScheduledNotifications).toList();

    await _plugin.cancelAll();
    for (final dose in pending) {
      final scheduledAt = DateTime.parse(
        dose['fecha_hora_programada'].toString().replaceFirst(' ', 'T'),
      );
      final localSchedule =
          timezone.TZDateTime.from(scheduledAt, timezone.local);
      if (!localSchedule.isAfter(timezone.TZDateTime.now(timezone.local))) {
        continue;
      }

      await _plugin.zonedSchedule(
        int.parse(dose['id_dosis'].toString()),
        'Hora de tu medicamento',
        '${dose['nombre']} · ${dose['dosis']}',
        localSchedule,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Recordatorios de medicamentos',
            channelDescription:
                'Avisos de las dosis programadas en MediReminder.',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: _hasExactAlarmPermission
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: dose['id_dosis'].toString(),
      );
    }

    return pending.length;
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
