import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update online status in Firestore
      await _updateUserPresence(userCredential.user!.uid, true);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during sign-in.');
    }
  }

  // Register with Email, Password, Display Name and Optional Profile Pic
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Update Firebase profile
        await user.updateDisplayName(displayName);
        if (photoUrl != null) {
          await user.updatePhotoURL(photoUrl);
        }
        await user.reload();

        // Create user document in Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          isOnline: true,
          lastSeen: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during registration.');
    }
  }

  // Sign in with Google (google_sign_in v7.0.0+ syntax)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Initialize GoogleSignIn singleton
      await GoogleSignIn.instance.initialize();

      // 2. Perform authentication sheet popup
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return null; // User cancelled

      // 3. Perform authorization to obtain the Access Token
      final List<String> scopes = ['email', 'profile'];
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(scopes);

      // 4. Retrieve credentials
      final String? idToken = googleUser.authentication.idToken;
      final String? accessToken = clientAuth.accessToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Check if user document exists in Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Create new user profile in Firestore
          UserModel newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? 'Google User',
            photoUrl: user.photoURL,
            isOnline: true,
            lastSeen: DateTime.now(),
          );
          await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        } else {
          // Update online presence for existing user
          await _updateUserPresence(user.uid, true);
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during Google Sign-In.');
    } catch (e) {
      throw Exception('An unexpected error occurred during Google Sign-In: $e');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Mark offline and update lastSeen before logging out
      await _updateUserPresence(uid, false);
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // Update user online/offline presence
  Future<void> _updateUserPresence(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
