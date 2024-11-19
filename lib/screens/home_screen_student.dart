import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gym_bros_tasks/screens/calendar_student_screen.dart';
import 'package:gym_bros_tasks/screens/progress_screen.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:gym_bros_tasks/screens/record_students_screen.dart';
import 'package:gym_bros_tasks/screens/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreenStudent extends StatefulWidget {
  final String subjectName;
  const HomeScreenStudent({super.key, required this.subjectName});

  @override
  _HomeScreenStudentState createState() => _HomeScreenStudentState();
}

class _HomeScreenStudentState extends State<HomeScreenStudent> {
  int _paginaActual = 0;
  final user = FirebaseAuth.instance.currentUser;
  // Lista de pantallas
  final List<Widget> _screens = [];

  Future<void> _downloadFile(BuildContext context, String fileUrl) async {
    try {
      final Uri url = Uri.parse(fileUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede abrir el archivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar el archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // En HomeScreenStudent, añade este método para asignar las tareas al estudiante
  Future<void> _asignarTareasAlEstudiante() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Obtener todas las tareas de la materia
      final tareasSnapshot = await FirebaseFirestore.instance
          .collection('tareas')
          .where('materia', isEqualTo: widget.subjectName)
          .get();

      // Para cada tarea, crear o verificar la asignación al estudiante
      for (var doc in tareasSnapshot.docs) {
        final tareaId = doc.id;
        final tareaData = doc.data();

        // Verificar si ya existe la asignación
        final asignacionRef = await FirebaseFirestore.instance
            .collection('tareas_estudiantes')
            .where('tareaId', isEqualTo: tareaId)
            .where('estudianteId', isEqualTo: user.uid)
            .get();

        // Si no existe, crear la asignación
        if (asignacionRef.docs.isEmpty) {
          await FirebaseFirestore.instance
              .collection('tareas_estudiantes')
              .add({
            'tareaId': tareaId,
            'estudianteId': user.uid,
            'materia': widget.subjectName,
            'estado': 'pendiente',
            'fechaAsignacion': DateTime.now(),
            'fechaEntrega': tareaData['fechaEntrega'],
            'nombreTarea': tareaData['nombre'],
          });
        }
      }
    } catch (e) {
      print('Error al asignar tareas: $e');
    }
  }

  Future<void> _seleccionarYEnviarArchivo(
      String tareaId, String tareaNombre) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg'],
      );

      if (result != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        final storageRef = FirebaseStorage.instanceFor(
                bucket: 'gs://gym-bros-tasks.firebasestorage.app')
            .ref()
            .child('soluciones')
            .child(widget.subjectName)
            .child(tareaId)
            .child('${user?.uid}_$fileName');

        try {
          await storageRef.putFile(file);
          print("Archivo subido con éxito");
        } on FirebaseException catch (e) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir el archivo: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await Future.delayed(const Duration(seconds: 2));
        String downloadURL = await storageRef.getDownloadURL();

        // Obtener el porcentaje de la tarea
        DocumentSnapshot tareaDoc = await FirebaseFirestore.instance
            .collection('tareas')
            .doc(tareaId)
            .get();

        double porcentaje = 0.0;
        if (tareaDoc.exists) {
          porcentaje =
              (tareaDoc.data() as Map<String, dynamic>)['porcentaje'] ?? 0.0;
        }

        // Guardar información en Firestore con el porcentaje
        await FirebaseFirestore.instance
            .collection('soluciones')
            .doc('${tareaId}_${user?.uid}')
            .set({
          'tareaId': tareaId,
          'userId': user?.uid,
          'fechaEnvio': DateTime.now(),
          'estado': 'enviado',
          'materia': widget.subjectName,
          'nombreArchivo': fileName,
          'urlArchivo': downloadURL,
          'tareaNombre': tareaNombre,
          'porcentaje': porcentaje, // Añadido el campo porcentaje
        });

        // Actualizar el estado en 'tareas_estudiantes'
        await FirebaseFirestore.instance
            .collection('tareas_estudiantes')
            .where('tareaId', isEqualTo: tareaId)
            .where('estudianteId', isEqualTo: user?.uid)
            .get()
            .then((querySnapshot) {
          for (var doc in querySnapshot.docs) {
            doc.reference.update({'estado': 'entregado'});
          }
        });

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo subido correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir el archivo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _asignarTareasAlEstudiante();
    // Inicializar _screens con los widgets necesarios
    _screens.addAll([
      _buildHomeScreenContent(), // Pantalla principal con SingleChildScrollView
      RecordStudentsScreen(),
      ProgressScreen(),
      CalendarStudentScreen(), // Pantalla del calendario
      SettingsScreen(), // Define tu pantalla de configuración aquí
    ]);
  }

  Widget _buildHomeScreenContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Trabajos',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tareas')
                .where('materia', isEqualTo: widget.subjectName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No hay trabajos para esta materia'));
              }

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView(
                  children: snapshot.data!.docs.map((doc) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            title: Text(
                              doc['nombre'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha de entrega: ${DateFormat('dd/MM/yyyy').format((doc['fechaEntrega'] as Timestamp).toDate())}',
                                ),
                                Text(
                                  'Porcentaje: ${((doc['porcentaje'] as double).toDouble())}',
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () =>
                                      _downloadFile(context, doc['archivoUrl']),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.attach_file,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          doc['archivo'] ??
                                              'Ningún archivo adjunto',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('soluciones')
                                .doc('${doc.id}_${user?.uid}')
                                .snapshots(),
                            builder: (context, solucionSnapshot) {
                              bool solucionEnviada = solucionSnapshot.hasData &&
                                  solucionSnapshot.data!.exists;

                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    if (solucionEnviada &&
                                        solucionSnapshot.data!.data() != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Text(
                                          'Archivo enviado: ${(solucionSnapshot.data!.data() as Map<String, dynamic>)['nombreArchivo']}',
                                          style: const TextStyle(
                                              color: Colors.blue),
                                        ),
                                      ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _seleccionarYEnviarArchivo(
                                        doc.id,
                                        doc['nombre'],
                                      ),
                                      icon: Icon(solucionEnviada
                                          ? Icons.update
                                          : Icons.upload_file),
                                      label: Text(solucionEnviada
                                          ? 'Actualizar Solución'
                                          : 'Enviar Solución'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 45),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subjectName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _paginaActual,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaActual,
        onTap: (index) {
          setState(() {
            _paginaActual = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.sticky_note_2), label: 'Notas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: 'Progreso'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Calendario'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes')
        ],
        backgroundColor: const Color.fromARGB(255, 255, 252, 252),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,
      ),
    );
  }
}
