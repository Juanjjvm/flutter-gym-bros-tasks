import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Estado para los switches
  bool _generalNotifications = true;
  bool _newTaskNotifications = true;
  bool _deadlineNotifications = true;
  bool _gradeNotifications = true;
  bool _emailNotifications = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // General
          _buildSectionHeader('General'),
          SwitchListTile(
            value: _generalNotifications,
            onChanged: (bool value) {
              setState(() {
                _generalNotifications = value;
                if (!value) {
                  // Si se desactivan las notificaciones generales, desactivar todas
                  _newTaskNotifications = false;
                  _deadlineNotifications = false;
                  _gradeNotifications = false;
                  _emailNotifications = false;
                }
              });
            },
            title: const Text('Activar notificaciones'),
            subtitle: const Text('Recibe todas las notificaciones importantes'),
            secondary: const Icon(Icons.notifications_active),
          ),
          const Divider(),

          // Tipos de notificaciones
          _buildSectionHeader('Tipos de notificaciones'),
          SwitchListTile(
            value: _newTaskNotifications && _generalNotifications,
            onChanged: _generalNotifications
                ? (bool value) {
                    setState(() => _newTaskNotifications = value);
                  }
                : null,
            title: const Text('Nuevas tareas'),
            subtitle: const Text('Notificar cuando se asignen nuevas tareas'),
            secondary: const Icon(Icons.assignment),
          ),
          SwitchListTile(
            value: _deadlineNotifications && _generalNotifications,
            onChanged: _generalNotifications
                ? (bool value) {
                    setState(() => _deadlineNotifications = value);
                  }
                : null,
            title: const Text('Fechas límite'),
            subtitle: const Text('Recordatorios de fechas de entrega'),
            secondary: const Icon(Icons.alarm),
          ),
          SwitchListTile(
            value: _gradeNotifications && _generalNotifications,
            onChanged: _generalNotifications
                ? (bool value) {
                    setState(() => _gradeNotifications = value);
                  }
                : null,
            title: const Text('Calificaciones'),
            subtitle: const Text('Notificar cuando se califique una tarea'),
            secondary: const Icon(Icons.grade),
          ),
          const Divider(),

          // Métodos de notificación
          _buildSectionHeader('Métodos de notificación'),
          SwitchListTile(
            value: _emailNotifications && _generalNotifications,
            onChanged: _generalNotifications
                ? (bool value) {
                    setState(() => _emailNotifications = value);
                  }
                : null,
            title: const Text('Notificaciones por correo'),
            subtitle:
                const Text('Recibir notificaciones por correo electrónico'),
            secondary: const Icon(Icons.email),
          ),
          const Divider(),

          // Preferencias
          _buildSectionHeader('Preferencias'),
          SwitchListTile(
            value: _soundEnabled && _generalNotifications,
            onChanged: _generalNotifications
                ? (bool value) {
                    setState(() => _soundEnabled = value);
                  }
                : null,
            title: const Text('Sonido'),
            subtitle: const Text('Activar sonidos de notificación'),
            secondary: const Icon(Icons.volume_up),
          ),
          SwitchListTile(
            value: _vibrationEnabled && _generalNotifications,
            onChanged: _generalNotifications
                ? (bool value) {
                    setState(() => _vibrationEnabled = value);
                  }
                : null,
            title: const Text('Vibración'),
            subtitle: const Text('Activar vibración'),
            secondary: const Icon(Icons.vibration),
          ),
          const Divider(),

          // Horarios
          _buildSectionHeader('Horarios de notificación'),
          ListTile(
            title: const Text('Horario de silencio'),
            subtitle: const Text('No molestar: 22:00 - 07:00'),
            leading: const Icon(Icons.bedtime),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Aquí iría la navegación a la configuración de horario
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
