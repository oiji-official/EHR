import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/doctor.dart';
import '../providers/record_provider.dart';
import '../secrets.dart' as secrets;

class DoctorAuthProvider extends ChangeNotifier {
  FirebaseAuth _auth = FirebaseAuth.instance;

  EhrDoctor _ehrDoctor;
  bool _authenticated;

  bool _shownboarding = true;

  EhrDoctor get ehrDoctor {
    return _ehrDoctor;
  }

  bool get shownboarding {
    return _shownboarding;
  }

  bool get authenticated {
    if (_authenticated == null) {
      _authenticated = false;
    }
    return _authenticated;
  }

  String get userid {
    return _auth.currentUser.uid;
  }

  bool get isLoggedIn {
    if (_auth.currentUser == null) {
      return false;
    }
    return true;
  }

  Future<void> showOnboarding(bool shownboarding) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('shownboarding', shownboarding);
    _shownboarding = shownboarding;
    notifyListeners();
  }

  Future<void> getonboarding(bool shownboarding) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _shownboarding = prefs.getBool('shownboarding');
    notifyListeners();
  }

  Future<void> isAuthenticated() async {
    final userauthenticated = await FirebaseFirestore.instance
        .collection('Doctors')
        .doc(userid)
        .get()
        .then((f) {
      return f['authenticated'];
    });
    _authenticated = userauthenticated;
  }

  Future checkStatus(String email, String name) async {
    // final url = '${secrets.apiurl}:2/check_status';
    final url = '${secrets.url}:2/check_status';
    try {
      final response = await http.post(
        url,
        body: json.encode({
          "username": name,
          "useremail": email,
        }),
        headers: {
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException(
            'The connection has timed out, Please try again');
      });

      throw [json.decode(response.body)['message'], response.statusCode];
    } on TimeoutException catch (e) {
      final TimeoutException error = e;
      throw [error.message, 400];
    } catch (e) {
      throw e;
      // TODO
    }
  }

  Future<void> getUserDetails(String userid) async {
    var name, email;
    await FirebaseFirestore.instance
        .collection('Doctors')
        .doc(userid)
        .get()
        .then((f) {
      name = f['name'];
      email = f['email'];
    });
    return [name, email];
  }

  Future<void> finishSignup(int port, BuildContext context) async {
    final provider = Provider.of<RecordsProvider>(context, listen: false);
    await provider.createKeys(port);
    await FirebaseFirestore.instance.collection('Doctors').doc(userid).update({
      'authenticated': true,
      'privatekey': provider.privatekey,
      'publickey': provider.publickey,
      'peer_node': port
    });
    _authenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> login({String email, String password}) async {
    dynamic errorMessage;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (error) {
      errorMessage = " ";
      // switch (error.code) {
      //   case "invalid-email":
      //     errorMessage = "You entered an invalid email.";
      //     break;
      //   case "wrong-password":
      //     errorMessage = "You entered a wrong password.";
      //     break;
      //   case "user-not-found":
      //     errorMessage = "User doesn't exist.";
      //     break;
      //   case "user-disabled":
      //     errorMessage = "User accountdisabled.";
      //     break;
      //   case "operation-not-allowed":
      //     errorMessage = "Too many requests please try again later.";
      //     break;
      //   case "too-many-requests":
      //     errorMessage = "Too many requests please try again later.";
      //     break;
      //   default:
      //     errorMessage = "An undefined Error happened.";
      // }
      throw errorMessage;
    }
    notifyListeners();
  }

  Future<void> signup({
    String name,
    String email,
    String doctorid,
    String password,
    String publickey,
    String privatekey,
    String gender,
  }) async {
    dynamic errorMessage;
    try {
      UserCredential doctorCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await FirebaseFirestore.instance
          .collection('Doctors')
          .doc(doctorCredential.user.uid)
          .set({
        'name': name,
        'email': email,
        'joindate': DateTime.now().toIso8601String(),
        'doctorid': doctorid,
        'gender': gender,
        'authenticated': false
      });
      //errror occurred here// add button to send request for being added to chain

      Map<String, dynamic> userdata = {"username": name, "useremail": email};
      // final url = '${secrets.apiurl}:2/assign';
      final url = '${secrets.url}:2/assign';
      await http.post(
        url,
        body: json.encode(userdata),
        headers: {
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException(
            'The server is offline, proceed to login as we assign you a port');
      });
    } on TimeoutException catch (error) {
      throw error.message;
    } catch (error) {
      errorMessage = " ";
      // switch (error.code) {
      //   case "invalid-email":
      //     errorMessage = "You entered an invalid email.";
      //     break;
      //   case "account-exists-with-different-credential":
      //   case "email-already-in-use":
      //     errorMessage = "Email is already in use.";
      //     break;
      //   case "user-disabled":
      //     errorMessage = "User accountdisabled.";
      //     break;
      //   case "operation-not-allowed":
      //     errorMessage = "Too many requests please try again later.";
      //     break;
      //   default:
      //     errorMessage = error;
      // }
      throw errorMessage;
    }
    notifyListeners();
  }

  Future<void> editdetails({
    String name,
    String email,
    String doctorid,
  }) async {
    await FirebaseFirestore.instance
        .collection('Doctors')
        .doc(_auth.currentUser.uid)
        .update({
      'name': name,
      'email': email,
      'doctorid': doctorid,
    }).catchError((error) => throw error);
    _ehrDoctor = EhrDoctor(
      name: name,
      doctorid: doctorid,
      email: email,
    );
    notifyListeners();
  }

  // Future<void> getTransactiondetails(
  //     String doctorkey, String patientkey) async {
  //   final userdocument = await FirebaseFirestore.instance
  //       .collection('Users')
  //       .where('publickey', isEqualTo: patientkey)
  //       .get();

  //   final doctordocument = await FirebaseFirestore.instance
  //       .collection('Doctors')
  //       .where('publickey', isEqualTo: doctorkey)
  //       .get();

  //   _doctorname = doctordocument.docs[0].data()['name'];
  //   _patientname = userdocument.docs[0].data()['name'];
  //   _hospital = doctordocument.docs[0].data()['hospital'];

  //   notifyListeners();
  // }
}
