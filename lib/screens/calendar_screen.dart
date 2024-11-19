// Importa el paquete Flutter para los widgets básicos de la interfaz de usuario
import 'package:flutter/material.dart';

// Importa `TableCalendar`, una biblioteca que facilita la creación de calendarios en Flutter
import 'package:table_calendar/table_calendar.dart';

// Importa `cloud_firestore` para interactuar con la base de datos Firebase Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

// Define el widget `CalendarScreen` como un `StatefulWidget` para gestionar el estado
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  // Define una clave global para acceder al estado del widget desde otros lugares
  static final GlobalKey<_CalendarScreenState> calendarKey = GlobalKey();

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

// Clase privada `_CalendarScreenState` que contiene el estado del `CalendarScreen`
class _CalendarScreenState extends State<CalendarScreen> {
  // Formato del calendario, inicializado a mostrar el mes
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Fecha actualmente enfocada en el calendario
  DateTime _focusedDay = DateTime.now();

  // Día seleccionado en el calendario (puede ser `null` si no hay selección)
  DateTime? _selectedDay;

  // Mapa que almacena tareas agrupadas por fecha
  Map<DateTime, List<Map<String, dynamic>>> _tasksByDate = {};

  // Bandera para controlar el estado de carga de las tareas
  bool isLoading = false;

  // Método que se ejecuta al inicializar el estado del widget
  @override
  void initState() {
    super.initState();
    _loadTasks(); // Carga las tareas desde Firebase al iniciar
  }

  // Método privado para cargar tareas desde Firebase
  Future<void> _loadTasks() async {
    if (isLoading) return; // Prevenir múltiples llamadas simultáneas
    setState(() {
      isLoading = true; // Activa la bandera de carga
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        isLoading = false;
      });
      return; // Si el usuario no está autenticado, detener el proceso
    }

    // Obtiene todas las tareas de la colección 'Tasks' en Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('tareas')
        .where('uid', isEqualTo: uid) // Filtrar por UID
        .get();

    final tasksByDate = <DateTime, List<Map<String, dynamic>>>{};

    // Itera sobre cada documento en la colección de tareas
    for (var doc in snapshot.docs) {
      final data = doc.data(); // Obtiene los datos de cada documento

      final date = data['fechaEntrega'] is Timestamp
          ? (data['fechaEntrega'] as Timestamp).toDate()
          : DateTime.parse(data['fechaEntrega'] as String);

      final task = {
        'nombre': data['nombre'], // Materia o asunto de la tarea
      };

      // Normaliza la fecha (solo año, mes y día) para evitar problemas de comparación
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Agrupa las tareas por fecha en el mapa `tasksByDate`
      if (tasksByDate[normalizedDate] == null) {
        tasksByDate[normalizedDate] = [task];
      } else {
        tasksByDate[normalizedDate]!.add(task);
      }
    }

    // Actualiza el estado del widget con las tareas agrupadas por fecha y desactiva la carga
    setState(() {
      _tasksByDate = tasksByDate;
      isLoading = false;
    });
  }

  // Método público para recargar las tareas, puede ser llamado desde `HomeScreen`
  void reloadTasks() => _loadTasks();

  // Función que devuelve las tareas correspondientes a una fecha específica
  List<Map<String, dynamic>> _getTasksForDay(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _tasksByDate[normalizedDate] ?? [];
  }

  // Método `build` que define la interfaz de usuario del widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Calendario",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          // Widget `TableCalendar` para mostrar el calendario
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getTasksForDay,
            // Añadir estilo
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Color.fromARGB(255, 131, 176, 255),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonDecoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
              formatButtonTextStyle: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(
              height: 10), // Espacio entre el calendario y la lista de tareas
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount:
                        _getTasksForDay(_selectedDay ?? _focusedDay).length,
                    itemBuilder: (context, index) {
                      final task =
                          _getTasksForDay(_selectedDay ?? _focusedDay)[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 8.0,
                        ),
                        child: ListTile(
                          title: Text(task['nombre'] ?? 'Sin nombre'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [],
                          ),
                          leading: Icon(
                            task['estado'] == 'enviado'
                                ? Icons.assignment_turned_in
                                : Icons.assignment,
                            color: task['estado'] == 'enviado'
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
