import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class RecordNotesScreen extends StatelessWidget {
  final String studentId;
  final String materiaCode;
  final String studentName;

  const RecordNotesScreen({
    Key? key,
    required this.studentId,
    required this.materiaCode,
    required this.studentName,
  }) : super(key: key);

  // Función para descargar el archivo
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

  // Función para mostrar el diálogo de calificación
  Future<void> _showGradeDialog(
      BuildContext context, String solutionId, double? currentGrade) async {
    final TextEditingController gradeController = TextEditingController(
      text: currentGrade?.toString() ?? '',
    );
    final TextEditingController commentController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Calificar Tarea'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gradeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calificación (0-5)',
                    hintText: 'Ingrese la calificación',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comentarios (opcional)',
                    hintText: 'Ingrese comentarios sobre la tarea',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                // Validar que la calificación sea un número válido entre 0 y 100
                final grade = double.tryParse(gradeController.text);
                if (grade == null || grade < 0 || grade > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Por favor ingrese una calificación válida entre 0 y 100'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Actualizar la calificación en Firestore
                try {
                  await FirebaseFirestore.instance
                      .collection('soluciones')
                      .doc(solutionId)
                      .update({
                    'calificacion': grade,
                    'comentarios': commentController.text.trim(),
                    'fechaCalificacion': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calificación guardada exitosamente'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar la calificación: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tareas de $studentName'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('soluciones')
            .where('userId', isEqualTo: studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay tareas entregadas'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final solutionData = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solutionData['tareaNombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fecha de envío: ${DateFormat('dd/MM/yyyy HH:mm').format((solutionData['fechaEnvio'] as Timestamp).toDate())}',
                      ),
                      if (solutionData['calificacion'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Calificación: ${solutionData['calificacion'].toString()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                      if (solutionData['comentarios'] != null &&
                          solutionData['comentarios']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Comentarios: ${solutionData['comentarios']}',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Archivo enviado: ${solutionData['nombreArchivo']}',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                                Text(
                                  'Estado: ${solutionData['estado']}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              if (solutionData['urlArchivo'] != null) {
                                _downloadFile(
                                    context, solutionData['urlArchivo']);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('URL del archivo no disponible'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.grade),
                            color: Colors.blue,
                            onPressed: () => _showGradeDialog(
                              context,
                              doc.id,
                              solutionData['calificacion']?.toDouble(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
