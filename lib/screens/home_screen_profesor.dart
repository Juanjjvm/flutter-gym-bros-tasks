import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gym_bros_tasks/screens/calendar_screen.dart';
import 'package:gym_bros_tasks/screens/record_screen.dart';
import 'package:gym_bros_tasks/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String subjectName;
  final String subjectCode;
  const HomeScreen(
      {super.key, required this.subjectName, required this.subjectCode});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  double _uploadProgress = 0;
  int _paginaActual = 0;

  // Lista de pantallas
  final List<Widget> _screens = [];

  // Mostrar el diálogo para añadir o editar tareas
  Future<void> _showTaskDialog(BuildContext context,
      {DocumentSnapshot? doc}) async {
    String nombreTarea = doc?['nombre'] ?? '';
    String? selectedFile = doc?['archivo'];
    _uploadedFileUrl = doc?['archivoUrl'];
    DateTime? selectedDate =
        doc != null ? (doc['fechaEntrega'] as Timestamp).toDate() : null;
    String porcentaje = doc?['porcentaje']?.toString() ?? '';

    Future<void> _pickFile() async {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();

        if (result != null) {
          setState(() {
            _isUploading = true;
            _uploadProgress = 0;
          });

          // Obtener el archivo y su nombre
          final file = File(result.files.single.path!);
          final fileName = result.files.single.name;

          // Crear una referencia única para el archivo en Storage
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final storageRef = FirebaseStorage.instanceFor(
                  bucket: 'gs://gym-bros-tasks.firebasestorage.app')
              .ref()
              .child(
                  'tareas/${user.uid}/${widget.subjectCode}/${DateTime.now().millisecondsSinceEpoch}_$fileName');

          // Iniciar la subida con seguimiento del progreso
          final uploadTask = storageRef.putFile(file);

          // Monitorear el progreso de la subida
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });

          // Esperar a que se complete la subida
          await uploadTask;

          // Obtener la URL del archivo
          final downloadUrl = await storageRef.getDownloadURL();

          setState(() {
            selectedFile = fileName;
            _uploadedFileUrl = downloadUrl;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo subido exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir el archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Future<void> _pickDate(BuildContext context) async {
      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (pickedDate != null) {
        selectedDate = pickedDate;
        (context as Element).markNeedsBuild();
      }
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(doc == null ? 'Añadir trabajo' : 'Editar trabajo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Tarea'),
                onChanged: (value) => nombreTarea = value,
                controller: TextEditingController(text: nombreTarea),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Porcentaje',
                  hintText: 'Ingrese el porcentaje (0-100)',
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => porcentaje = value,
                controller: TextEditingController(text: porcentaje),
              ),
              InkWell(
                onTap: () => _pickDate(context),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Fecha de entrega'),
                  child: Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Seleccione una fecha',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Material',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _isUploading
                            ? null
                            : () async {
                                await _pickFile();
                                setState(
                                    () {}); // Actualizar el StatefulBuilder
                              },
                      ),
                    ],
                  ),
                  if (_isUploading)
                    LinearProgressIndicator(value: _uploadProgress),
                  if (selectedFile != null)
                    Text(
                      selectedFile!,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                // Validar que el porcentaje sea un número válido entre 0 y 100
                double? porcentajeNum = double.tryParse(porcentaje);
                if (nombreTarea.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre de la tarea es requerido'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (porcentajeNum == null ||
                    porcentajeNum < 0 ||
                    porcentajeNum > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Por favor ingrese un porcentaje válido entre 0 y 100'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La fecha de entrega es requerida'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                _saveOrUpdateTarea(nombreTarea, selectedDate!, selectedFile,
                    porcentajeNum, doc?.id);
                Navigator.of(context).pop();
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // Guardar o actualizar tarea en Firestore
  Future<void> _saveOrUpdateTarea(String nombreTarea, DateTime fechaEntrega,
      String? archivo, double porcentaje, String? docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No hay usuario autenticado.");
      return;
    }
    String uid = user.uid;

    Map<String, dynamic> tarea = {
      'nombre': nombreTarea,
      'fechaEntrega': Timestamp.fromDate(fechaEntrega),
      'archivo': archivo ?? 'Sin archivo adjunto',
      'archivoUrl': _uploadedFileUrl, // Añadir la URL del archivo
      'porcentaje': porcentaje,
      'uid': uid,
      'materia': widget.subjectName,
    };

    try {
      if (docId == null) {
        await _firestore.collection('tareas').add(tarea);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarea creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _firestore.collection('tareas').doc(docId).update(tarea);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarea actualizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la tarea: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Eliminar tarea de Firestore
  Future<void> _deleteTarea(String docId) async {
    await _firestore.collection('tareas').doc(docId).delete();
  }

  @override
  void initState() {
    super.initState();
    // Inicializar _screens con los widgets necesarios
    _screens.addAll([
      _buildHomeScreenContent(), // Pantalla principal con SingleChildScrollView
      RecordScreen(materiaCode: widget.subjectCode),
      CalendarScreen(), // Pantalla del calendario
      SettingsScreen(), // Define tu pantalla de configuración aquí
    ]);
  }

  // Widget para la pantalla principal
  Widget _buildHomeScreenContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trabajos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () {
                  _showTaskDialog(context);
                },
                child: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('tareas')
                .where('materia', isEqualTo: widget.subjectName)
                .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay tareas'));
              }

              return ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: snapshot.data!.docs.map((doc) {
                  DateTime fechaEntrega =
                      (doc['fechaEntrega'] as Timestamp).toDate();
                  String formattedDate =
                      '${fechaEntrega.day}/${fechaEntrega.month}/${fechaEntrega.year}';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      title: Text(
                        doc['nombre'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fecha de entrega: $formattedDate'),
                          const SizedBox(height: 4),
                          Text('Porcentaje: ${doc['porcentaje']}%'),
                          const SizedBox(height: 4),
                          // Reemplaza el Row existente con este código actualizado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  doc['archivo'] ?? 'Ningún archivo adjunto',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'Editar') {
                                    _showTaskDialog(context, doc: doc);
                                  } else if (value == 'Eliminar') {
                                    _deleteTarea(doc.id);
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'Editar',
                                    child: Text('Editar'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'Eliminar',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
              icon: Icon(Icons.sticky_note_2), label: 'Historial'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Calendario'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes')
        ],
        backgroundColor: const Color.fromARGB(255, 255, 252, 252),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.black,
      ),
    );
  }
}
