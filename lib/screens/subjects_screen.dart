import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_bros_tasks/screens/home_screen_profesor.dart';

class MateriasScreen extends StatefulWidget {
  @override
  _MateriasScreenState createState() => _MateriasScreenState();
}

class _MateriasScreenState extends State<MateriasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gym Bros Tasks',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
                icon: Icon(Icons.add),
                onPressed: () {
                  _showAddSubjectDialog(context);
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('materias')
                    .where('uid',
                        isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No hay materias agregadas"));
                  }

                  // Fetch universities and careers to get their names
                  return FutureBuilder<Map<String, String>>(
                    future: _fetchUniversitiesAndCareers(snapshot.data!.docs),
                    builder: (context, universitiesSnapshot) {
                      if (!universitiesSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Agrupa las materias por universidad y carrera
                      Map<String, Map<String, List<DocumentSnapshot>>>
                          groupedData = {};
                      for (var doc in snapshot.data!.docs) {
                        String universityId = doc['universidadId'];
                        String careerId = doc['careerId'];
                        String universityName =
                            universitiesSnapshot.data![universityId] ??
                                'Universidad Desconocida';
                        String careerName =
                            universitiesSnapshot.data![careerId] ??
                                'Carrera Desconocida';

                        if (!groupedData.containsKey(universityName)) {
                          groupedData[universityName] = {};
                        }
                        if (!groupedData[universityName]!
                            .containsKey(careerName)) {
                          groupedData[universityName]![careerName] = [];
                        }
                        groupedData[universityName]![careerName]!.add(doc);
                      }

                      return ListView(
                        children: groupedData.keys.map((university) {
                          return ExpansionTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  university,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    // Find the university ID
                                    String universityId = universitiesSnapshot
                                        .data!.keys
                                        .firstWhere(
                                      (key) =>
                                          universitiesSnapshot.data![key] ==
                                          university,
                                      orElse: () => '',
                                    );
                                    _showAddCareerDialog(context, universityId);
                                  },
                                ),
                              ],
                            ),
                            children:
                                groupedData[university]!.keys.map((career) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: ExpansionTile(
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        career,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add),
                                        onPressed: () {
                                          // Find the career ID
                                          String careerId = universitiesSnapshot
                                              .data!.keys
                                              .firstWhere(
                                            (key) =>
                                                universitiesSnapshot
                                                    .data![key] ==
                                                career,
                                            orElse: () => '',
                                          );
                                          String universityId =
                                              universitiesSnapshot.data!.keys
                                                  .firstWhere(
                                            (key) =>
                                                universitiesSnapshot
                                                    .data![key] ==
                                                university,
                                            orElse: () => '',
                                          );
                                          _showAddSubjectToCareerDialog(
                                              context, universityId, careerId);
                                        },
                                      ),
                                    ],
                                  ),
                                  children: groupedData[university]![career]!
                                      .map((doc) {
                                    String subjectName = doc['nombre'];
                                    String subjectCode = doc['codigo'];

                                    return ListTile(
                                      title:
                                          Text('$subjectName ($subjectCode)'),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HomeScreen(
                                              subjectName: subjectName,
                                              subjectCode: subjectCode,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showAddSubjectToCareerDialog(
      BuildContext context, String universityId, String careerId) {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController subjectCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Añadir materia'),
          content: TextField(
            controller: subjectController,
            decoration: InputDecoration(labelText: 'Nombre de la materia'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo sin hacer nada
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                String subjectName = subjectController.text;
                String subjectCode = subjectCodeController.text;

                if (subjectName.isEmpty || subjectCode.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'El nombre de la materia no puede estar vacío')));
                } else {
                  String generatedCode = _generateRandomCode();
                  await _saveSubjectToFirestore(
                      subjectName, generatedCode, universityId, careerId);
                  Navigator.of(context).pop();
                  setState(() {}); // Fuerza la actualización de la vista
                }
              },
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCareerDialog(BuildContext context, String universityId) {
    final List<TextEditingController> subjectControllers = [
      TextEditingController()
    ];
    final TextEditingController careerController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Añadir carrera y materias'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: careerController,
                      decoration:
                          InputDecoration(labelText: 'Nombre de la carrera'),
                    ),
                    ...subjectControllers.map((subjectcontroller) {
                      int index = subjectControllers.indexOf(subjectcontroller);
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: subjectcontroller,
                              decoration: InputDecoration(
                                  labelText: 'Materia ${index + 1}'),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                subjectControllers.add(TextEditingController());
                              });
                            },
                          ),
                          if (index > 0)
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  subjectControllers.removeAt(index);
                                });
                              },
                            ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    String careerName = careerController.text;
                    List<String> subjectNames = subjectControllers
                        .map((controller) => controller.text)
                        .toList();

                    if (careerName.isEmpty ||
                        subjectNames.any((name) => name.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Todos los campos deben estar completos')));
                    } else {
                      DocumentReference careerRef =
                          await _firestore.collection('carreras').add({
                        'nombre': careerName,
                        'universidadId': universityId,
                        'createdAt': FieldValue.serverTimestamp(),
                        'uid': FirebaseAuth.instance.currentUser!.uid,
                      });
                      for (String subjectName in subjectNames) {
                        String generatedCode = _generateRandomCode();
                        await _saveSubjectToFirestore(subjectName,
                            generatedCode, universityId, careerRef.id);
                      }
                      Navigator.of(context).pop();
                      setState(() {});
                    }
                  },
                  child: Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    final List<TextEditingController> subjectControllers = [
      TextEditingController()
    ];
    final TextEditingController universityController = TextEditingController();
    final TextEditingController careerController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Añadir materia'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                          labelText: 'Nombre de la universidad'),
                    ),
                    TextField(
                      controller: careerController,
                      decoration:
                          InputDecoration(labelText: 'Nombre de la carrera'),
                    ),
                    ...subjectControllers.map((subjectcontroller) {
                      int index = subjectControllers.indexOf(subjectcontroller);
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: subjectcontroller,
                              decoration: InputDecoration(
                                  labelText: 'Materia ${index + 1}'),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                subjectControllers.add(TextEditingController());
                              });
                            },
                          ),
                          if (index >
                              0) // Mostrar el ícono de eliminación solo si hay más de un campo
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  subjectControllers.removeAt(index);
                                });
                              },
                            ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Cerrar el diálogo sin hacer nada
                  },
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    String universityName = universityController.text;
                    String careerName = careerController.text;
                    List<String> subjectNames = subjectControllers
                        .map((controller) => controller.text)
                        .toList();

                    if (subjectNames.any((name) => name.isEmpty) ||
                        universityName.isEmpty ||
                        careerName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Todos los campos deben estar completos')));
                    } else {
                      DocumentReference universityRef =
                          await _firestore.collection('universidades').add({
                        'nombre': universityName,
                        'createdAt': FieldValue.serverTimestamp(),
                        'uid': FirebaseAuth.instance.currentUser!.uid,
                      });

                      DocumentReference careerRef =
                          await _firestore.collection('carreras').add({
                        'nombre': careerName,
                        'universidadId': universityRef.id,
                        'createdAt': FieldValue.serverTimestamp(),
                        'uid': FirebaseAuth.instance.currentUser!.uid,
                      });
                      for (String subjectName in subjectNames) {
                        String generatedCode = _generateRandomCode();
                        await _saveSubjectToFirestore(subjectName,
                            generatedCode, universityRef.id, careerRef.id);
                      }
                      Navigator.of(context).pop();
                      setState(() {}); // Fuerza la actualización de la vista
                    }
                  },
                  child: Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _generateRandomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    Random rnd = Random();
    return List.generate(10, (index) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  Future<void> _saveUniversityToFirestore(String universityName) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('universidades').add({
        'nombre': universityName,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
      });
    } catch (e) {
      print('Error saving university: $e');
    }
  }

  Future<void> _saveCareerToFirestore(
      String careerName, String universityId) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('carreras').add({
        'nombre': careerName,
        'universidadId': universityId,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
      });
    } catch (e) {
      print('Error saving career: $e');
    }
  }

  Future<void> _saveSubjectToFirestore(String subjectName, String subjectCode,
      String universityId, String careerId) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('materias').add({
        'nombre': subjectName,
        'codigo': subjectCode,
        'universidadId': universityId,
        'careerId': careerId,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
      });
    } catch (e) {
      print('Error saving subject: $e');
    }
  }

  Future<Map<String, String>> _fetchUniversitiesAndCareers(
      List<DocumentSnapshot> materiasDocs) async {
    Set<String> universityIds = materiasDocs
        .map((doc) =>
            (doc.data() as Map<String, dynamic>)['universidadId'] as String)
        .toSet();

    Set<String> careerIds = materiasDocs
        .map(
            (doc) => (doc.data() as Map<String, dynamic>)['careerId'] as String)
        .toSet();
    Map<String, String> namesMap = {};

    // Fetch university names
    for (String universityId in universityIds) {
      DocumentSnapshot universityDoc =
          await _firestore.collection('universidades').doc(universityId).get();
      namesMap[universityId] = universityDoc['nombre'];
    }

    // Fetch career names
    for (String careerId in careerIds) {
      DocumentSnapshot careerDoc =
          await _firestore.collection('carreras').doc(careerId).get();
      namesMap[careerId] = careerDoc['nombre'];
    }

    return namesMap;
  }
}
