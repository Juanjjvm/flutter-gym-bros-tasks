import 'package:cloud_firestore/cloud_firestore.dart';

FirebaseFirestore db = FirebaseFirestore.instance;

Future<void> _signUp(String email, String name, String pasword) async {
  // Guardar la información del usuario en Firestore
  await db
      .collection('users')
      .add({"correo": email, "nombre": name, "contraseña": pasword});
}
