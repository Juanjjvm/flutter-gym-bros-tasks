import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gym_bros_tasks/screens/home_screen_student.dart';

class SubjectsStudentesScreen extends StatefulWidget {
  const SubjectsStudentesScreen({Key? key}) : super(key: key);

  @override
  _SubjectsStudentesScreenState createState() =>
      _SubjectsStudentesScreenState();
}

class _SubjectsStudentesScreenState extends State<SubjectsStudentesScreen> {
  final List<String> _materias = []; // Lista para guardar las materias
  final TextEditingController codeController = TextEditingController();
  final String uid = FirebaseAuth.instance.currentUser!
      .uid; // Usar el UID del usuario (debería ser dinámico)

  @override
  void initState() {
    super.initState();
    _loadMaterias();
  }

  // Cargar las materias desde Firestore
  Future<void> _loadMaterias() async {
    final materiasSnapshot = await FirebaseFirestore.instance
        .collection(
            'usuarios') // Asumiendo que tienes una colección de usuarios
        .doc(uid) // Asegúrate de usar el UID del usuario actual
        .collection('materias')
        .get();

    setState(() {
      _materias.clear(); // Limpiar la lista antes de agregar los nuevos datos
      for (var doc in materiasSnapshot.docs) {
        _materias.add(doc['nombre']); // Agregar el nombre de cada materia
      }
    });
  }

  // Guardar la materia en Firestore
  Future<void> _saveMateria(String materiaNombre, String code) async {
    await FirebaseFirestore.instance
        .collection(
            'usuarios') // Asegúrate de que este sea el documento correcto para el usuario
        .doc(uid)
        .collection('materias')
        .add({
      'nombre': materiaNombre,
    });

    // Obtener el nombre de usuario del estudiante desde su documento en la colección de usuarios
    final userDoc =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final nombreUsuario =
        userDoc.data()?['nombre_usuario'] ?? 'Nombre no disponible';

    // También guardamos el UID del estudiante en la colección de la materia
    await FirebaseFirestore.instance
        .collection('materias')
        .doc(code)
        .collection('estudiantes')
        .doc(uid)
        .set({
      'uid': uid,
      'nombre_usuario': nombreUsuario, // Agregar el nombre de usuario
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gym Bros Tasks',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            ListTile(
              title: const Text(
                'Mis materias',
                style: TextStyle(fontSize: 20),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  _showCodeDialog(context);
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _materias.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreenStudent(
                              subjectName: _materias[
                                  index], // Pasar el nombre de la materia seleccionada
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 24.0),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          border: Border.all(color: Colors.black, width: 1.5),
                          borderRadius:
                              BorderRadius.circular(20), // Esquinas ovaladas
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: Offset(2, 2),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _materias[index],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  void _showCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ingresar código'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Código',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                String code = codeController.text;
                if (code.isNotEmpty) {
                  var materiaSnapshot = await FirebaseFirestore.instance
                      .collection('materias')
                      .where('codigo', isEqualTo: code)
                      .get();

                  if (materiaSnapshot.docs.isNotEmpty) {
                    String materiaNombre = materiaSnapshot.docs.first['nombre'];
                    print('Materia encontrada: $materiaNombre');

                    // Guardar la materia en Firestore y actualizar la lista
                    await _saveMateria(materiaNombre, code);
                    setState(() {
                      _materias.add(
                        materiaNombre,
                      );
                    });
                  }
                }
                Navigator.of(context).pop();
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }
}
