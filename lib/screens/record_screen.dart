import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gym_bros_tasks/screens/record_notes_screen.dart';

class RecordScreen extends StatelessWidget {
  final String materiaCode;
  const RecordScreen({super.key, required this.materiaCode});

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
              "Historial de Estudiantes",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('materias')
                  .doc(materiaCode)
                  .collection('estudiantes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No hay estudiantes en esta materia"));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    // Convertimos el documento a Map para acceder a los datos de forma segura
                    final data = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    // Obtenemos el nombre del usuario con un valor por defecto si no existe
                    final studentName =
                        data['nombre_usuario'] ?? 'Usuario sin nombre';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecordNotesScreen(
                                studentId: snapshot.data!.docs[index].id,
                                materiaCode: materiaCode,
                                studentName: studentName,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          studentName,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
