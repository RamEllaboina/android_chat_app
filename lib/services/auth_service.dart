import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';  // ← Make sure this import exists

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();  // ← Make sure this exists

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Google Sign In
  Future<String?> signInWithGoogle() async {
    try {
      // Trigger Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return 'Sign in cancelled';
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      // ✅ SAVE USER DATA TO FIRESTORE
      await _firestoreService.saveUserData(userCredential.user!);
      
      return null; // Success
      
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    // Update online status to false before signing out
    await _firestoreService.updateUserOnlineStatus(false);
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Error message mapper
  String _getErrorMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Network error. Check your connection';
      case 'user-not-found':
        return 'No account found';
      case 'email-already-in-use':
        return 'Account already exists';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}