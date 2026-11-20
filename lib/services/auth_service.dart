import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Lấy người dùng hiện tại
  User? get currentUser => _auth.currentUser;

  // Luồng theo dõi thay đổi trạng thái xác thực
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng nhập bằng Google (Hỗ trợ cả Web và Android)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        print('[Auth] Bắt đầu đăng nhập Google trên Web qua Popup...');
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        print('[Auth] Bắt đầu đăng nhập Google trên Android qua google_sign_in...');
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          print('[Auth] Người dùng đã đóng bảng chọn tài khoản Google.');
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      print('[Auth] Đăng nhập thành công: ${userCredential.user?.email}');
      print('[Auth] ID người dùng: ${userCredential.user?.uid}');
      
      // Tạo hoặc cập nhật hồ sơ người dùng trên Firestore
      if (userCredential.user != null) {
        try {
          await _firestoreService.createOrUpdateUserProfile(userCredential.user!);
        } catch (e) {
          print('[Auth] Cảnh báo: Không tạo/cập nhật được hồ sơ, nhưng đăng nhập đã thành công. Lỗi: $e');
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('[Auth] FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      print('[Auth] LỖI: $e');
      print('[Auth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ─── XÁC THỰC EMAIL/MẬT KHẢU ────────────────────────────────

  // Đăng ký bằng email và mật khẩu
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('[Auth] Bắt đầu đăng ký bằng email/mật khẩu...');
      print('[Auth] Email: $email');
      
      // Tạo người dùng bằng email và mật khẩu
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('[Auth] Tạo người dùng thành công: ${userCredential.user?.uid}');
      
      // Cập nhật tên hiển thị
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
        print('[Auth] Đã cập nhật tên hiển thị: $displayName');
        
        // Tạo hồ sơ người dùng trên Firestore
        try {
          await _firestoreService.createOrUpdateUserProfile(
            _auth.currentUser!,
          );
          print('[Auth] Đã tạo hồ sơ Firestore');
        } catch (e) {
          print('[Auth] Cảnh báo: Không tạo được hồ sơ Firestore: $e');
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('[Auth] Lỗi đăng ký: ${e.code} - ${e.message}');
      rethrow; // Để UI xử lý lỗi
    } catch (e, stackTrace) {
      print('[Auth] Lỗi đăng ký không mong đợi: $e');
      print('[Auth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Đăng nhập bằng email và mật khẩu
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('[Auth] Bắt đầu đăng nhập bằng email/mật khẩu...');
      print('[Auth] Email: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('[Auth] Đăng nhập thành công: ${userCredential.user?.email}');
      print('[Auth] ID người dùng: ${userCredential.user?.uid}');
      
      // Cập nhật hồ sơ người dùng trên Firestore (nếu có thay đổi)
      if (userCredential.user != null) {
        try {
          await _firestoreService.createOrUpdateUserProfile(userCredential.user!);
        } catch (e) {
          print('[Auth] Cảnh báo: Không cập nhật được hồ sơ: $e');
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('[Auth] Lỗi đăng nhập: ${e.code} - ${e.message}');
      rethrow; // Để UI xử lý lỗi
    } catch (e, stackTrace) {
      print('[Auth] Lỗi đăng nhập không mong đợi: $e');
      print('[Auth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Gửi email đặt lại mật khẩu
  Future<void> resetPassword(String email) async {
    try {
      print('[Auth] Đang gửi email đặt lại mật khẩu đến: $email');
      
      await _auth.sendPasswordResetEmail(email: email);
      
      print('[Auth] Đã gỬi email đặt lại mật khẩu thành công');
    } on FirebaseAuthException catch (e) {
      print('[Auth] Lỗi đặt lại mật khẩu: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      print('[Auth] Lỗi đặt lại mật khẩu không mong đợi: $e');
      print('[Auth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Cập nhật tên hiển thị của người dùng
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
        print('[Auth] Đã cập nhật tên hiển thị: $displayName');
      }
    } catch (e) {
      print('[Auth] Lỗi cập nhật tên hiển thị: $e');
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('[Auth] Người dùng đã đăng xuất');
    } catch (e) {
      print('[Auth] Lỗi đăng xuất: $e');
    }
  }
}

