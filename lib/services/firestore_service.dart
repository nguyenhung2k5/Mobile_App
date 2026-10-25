import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_profile.dart';
import '../models/task_model.dart';
import '../models/notification_model.dart';
import '../utils/currency_format.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy ID người dùng hiện tại
  String? get currentUserId => _auth.currentUser?.uid;

  // ===== PHƯƠNG THỨC HỒ SƠ NGƯỜI DÙNG =====

  /// Tạo hoặc cập nhật hồ sơ người dùng khi họ đăng nhập lần đầu
  Future<void> createOrUpdateUserProfile(User firebaseUser) async {
    print('[Firestore] createOrUpdateUserProfile được gọi cho uid: ${firebaseUser.uid}');
    
    try {
      final userDoc = _firestore.collection('users').doc(firebaseUser.uid);
      
      print('[Firestore] Đang kiểm tra tài liệu người dùng...');
      final docSnapshot = await userDoc.get();
      print('[Firestore] Tài liệu tồn tại: ${docSnapshot.exists}');

      if (!docSnapshot.exists) {
        // Người dùng mới - tạo hồ sơ
        print('[Firestore] Đang tạo hồ sơ người dùng mới...');
        final newProfile = UserProfile(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Người dùng mới',
          photoURL: firebaseUser.photoURL ?? '',
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
        );
        
        final profileData = newProfile.toFirestore();
        print('[Firestore] Dữ liệu hồ sơ cần ghi: $profileData');
        
        await userDoc.set(profileData);
        print('[Firestore] ✅ Đã tạo hồ sơ người dùng mới cho ${firebaseUser.email}');
      } else {
        // Người dùng cũ - cập nhật lần hoạt động cuối
        print('[Firestore] Đang cập nhật lần hoạt động cuối...');

        // Kiểm tra xem có cần reset thisMonthEarned (tháng mới) không
        final existingData = docSnapshot.data();
        final lastActive = existingData?['lastActive'];
        final now = DateTime.now();
        Map<String, dynamic> updates = {'lastActive': Timestamp.now()};

        if (lastActive != null && lastActive is Timestamp) {
          final lastDate = lastActive.toDate();
          if (lastDate.month != now.month || lastDate.year != now.year) {
            // Tháng mới — reset thu nhập tháng này
            updates['thisMonthEarned'] = 0.0;
            print('[Firestore] Phát hiện tháng mới — đặt lại thisMonthEarned');
          }
        }

        await userDoc.update(updates);
        print('[Firestore] ✅ Đã cập nhật lần hoạt động cuối cho ${firebaseUser.email}');
      }
    } catch (e, stackTrace) {
      print('[Firestore] ❌ Lỗi trong createOrUpdateUserProfile: $e');
      print('[Firestore] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Lấy hồ sơ người dùng theo ID
  Future<UserProfile?> getUserProfile([String? uid]) async {
    final userId = uid ?? currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      print('[Firestore] Lỗi khi lấy hồ sơ người dùng: $e');
      return null;
    }
  }

  /// Luồng hồ sơ người dùng hiện tại (cập nhật thời gian thực)
  Stream<UserProfile?> getUserProfileStream() {
    if (currentUserId == null) return Stream.value(null);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null)
        .handleError((e) {
          print('[Firestore] Lỗi trong luồng hồ sơ người dùng: $e');
          return null; // Trả về null khi lỗi để UI xử lý
        });
  }

  /// Cập nhật hồ sơ người dùng
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (currentUserId == null) return;
    try {
      await _firestore.collection('users').doc(currentUserId).update(updates);
    } catch (e) {
      print('[Firestore] Lỗi khi cập nhật hồ sơ: $e');
    }
  }

  // ===== PHƯƠNG THỨC NHIỆM VỤ =====

  /// Tạo nhiệm vụ mới
  Future<String> createTask(HeroTask task) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    try {
      // Đọc trạng thái tài khoản từ hồ sơ
      double posterRating = 5.0;
      bool isBlocked = false;
      try {
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          posterRating = (data['rating'] as num?)?.toDouble() ?? 5.0;
          isBlocked = data['isBlocked'] == true;
        }
      } catch (_) {}

      if (isBlocked) {
        throw Exception('Tài khoản của bạn đã bị khóa bởi Quản trị viên.');
      }

      final taskData = {
        'title': task.title,
        'description': task.description,
        'category': task.category.name,
        'compensation': task.compensation,
        'status': task.status.name,
        'urgency': task.urgency.name,
        'estimatedMinutes': task.estimatedMinutes,
        'pickup': {
          'building': task.pickup.building,
          'level': task.pickup.level,
          'landmark': task.pickup.landmark,
        },
        'delivery': {
          'building': task.delivery.building,
          'level': task.delivery.level,
          'landmark': task.delivery.landmark,
        },
        'posterId': currentUserId,
        'posterName': _auth.currentUser?.displayName ?? 'Không rõ',
        'posterRating': posterRating,
        'posterAvatarUrl': _auth.currentUser?.photoURL ?? '',
        'heroId': null,
        'heroName': null,
        'pickedUp': false,
        'delivered': false,
        'createdAt': Timestamp.now(),
        'acceptedAt': null,
        'completedAt': null,
        'isPaid': false,
      };

      final docRef = await _firestore.collection('tasks').add(taskData);
      
      // Tăng số lượng nhiệm vụ đã đăng của người dùng (best-effort)
      try {
        await _firestore.collection('users').doc(currentUserId).update({
          'tasksPosted': FieldValue.increment(1),
        });
      } catch (_) {
        // Không quan trọng — bỏ qua
      }

      print('[Firestore] Đã tạo nhiệm vụ mới: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      final msg = e.toString();
      // Lỗi SDK Firestore Web 11.9.1: INTERNAL ASSERTION FAILED xảy ra SAU
      // khi ghi đã thành công. Xem như không nghiêm trọng để người dùng thấy thành công.
      if (msg.contains('INTERNAL ASSERTION FAILED') || msg.contains('Unexpected state')) {
        print('[Firestore] Bỏ qua lỗi assertion SDK đã biết (ghi đã được commit): $e');
        return 'unknown';
      }
      print('[Firestore] Lỗi khi tạo nhiệm vụ: $e');
      rethrow;
    }
  }

  /// Lấy tất cả nhiệm vụ đang mở (để duyệt)
  Stream<List<HeroTask>> getOpenTasks() {
    return _firestore
        .collection('tasks')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _taskFromFirestore(doc))
            .toList())
        .handleError((e) {
          print('[Firestore] Lỗi trong luồng nhiệm vụ đang mở: $e');
          return <HeroTask>[]; // Trả về danh sách rỗng khi lỗi
        });
  }

  /// Luồng một nhiệm vụ theo ID (cập nhật thời gian thực)
  Stream<HeroTask?> getTaskStream(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((doc) => doc.exists ? _taskFromFirestore(doc) : null)
        .handleError((e) {
          print('[Firestore] Lỗi trong luồng nhiệm vụ: $e');
          return null;
        });
  }

  /// Lấy TẤT CẢ nhiệm vụ (để duyệt với bộ lọc)
  Stream<List<HeroTask>> getAllTasks() {
    return _firestore
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _taskFromFirestore(doc))
            .toList())
        .handleError((e) {
          print('[Firestore] Lỗi trong luồng tất cả nhiệm vụ: $e');
          return <HeroTask>[];
        });
  }

  /// Lấy nhiệm vụ đã đăng bởi người dùng hiện tại
  Stream<List<HeroTask>> getMyPostedTasks() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('tasks')
        .where('posterId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _taskFromFirestore(doc))
            .toList())
        .handleError((e) {
          print('[Firestore] Lỗi trong luồng nhiệm vụ đã đăng: $e');
          return <HeroTask>[];
        });
  }

  /// Lấy nhiệm vụ đã nhận bởi người dùng hiện tại
  Stream<List<HeroTask>> getMyAcceptedTasks() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('tasks')
        .where('heroId', isEqualTo: currentUserId)
        .orderBy('acceptedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _taskFromFirestore(doc))
            .toList())
        .handleError((e) {
          print('[Firestore] Lỗi trong luồng nhiệm vụ đã nhận: $e');
          return <HeroTask>[];
        });
  }

  /// Lấy nhiệm vụ hoàn thành trong 7 ngày gần nhất cho biểu đồ hoạt động
  Future<List<Map<String, dynamic>>> getWeeklyCompletedTasks() async {
    if (currentUserId == null) return [];

    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      print('[Firestore] Đang lấy nhiệm vụ hoàn thành cho biểu đồ hoạt động...');
      
      // Đơn giản hóa query: Lấy TẤT CẢ nhiệm vụ hoàn thành của người dùng, lọc cục bộ.
      // Tránh lỗi "Int64 accessor" với Timestamp queries trên web.
      // Query đơn giản để tránh lỗi "Unexpected state" của SDK trên Web
      // Chúng ta sẽ lấy hết nhiệm vụ của heroId hiện tại có trạng thái 'completed',
      // sau đó lọc mốc thời gian 7 ngày ở phía Client.
      final tasksQuery = await _firestore
          .collection('tasks')
          .where('heroId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'completed')
          .get(kIsWeb ? const GetOptions(source: Source.server) : const GetOptions());

      print('[Firestore] Tìm thấy ${tasksQuery.docs.length} nhiệm vụ hoàn thành. Đang lọc...');
      
      final tasks = tasksQuery.docs
          .map((doc) {
            try {
              return _taskFromFirestore(doc);
            } catch (e) {
              print('[Firestore] Lỗi xử lý nhiệm vụ ${doc.id}: $e');
              return null;
            }
          })
          .whereType<HeroTask>() // Lọc bỏ null
          .where((t) => t.completedAt != null && t.completedAt!.isAfter(sevenDaysAgo))
          .toList();
      
      print('[Firestore] Đã lọc còn ${tasks.length} nhiệm vụ trong 7 ngày gần nhất.');

      // Khởi tạo với 0 cho 7 ngày gần nhất theo thứ tự
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      List<Map<String, dynamic>> result = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayName = days[date.weekday - 1];
        result.add({'day': dayName, 'count': 0, 'date': date});
      }

      // Điền số lượng
      for (var task in tasks) {
        if (task.completedAt != null) {
          // Tìm ngày khớp trong danh sách để đếm đúng cho cửa sổ ngày cụ thể
          for (var dayData in result) {
             final dayDate = dayData['date'] as DateTime;
             if (dayDate.day == task.completedAt!.day && dayDate.month == task.completedAt!.month) {
               dayData['count'] = (dayData['count'] as int) + 1;
             }
          }
        }
      }
      
      return result;
    } catch (e, stack) {
      print('[Firestore] Lỗi khi lấy nhiệm vụ tuần: $e');
      print('[Firestore] Stack trace: $stack');
      return []; // Trả về danh sách rỗng khi lỗi
    }
  }

  /// Nhận nhiệm vụ (dùng transaction để tránh race condition)
  Future<void> acceptTask(String taskId) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    // 1. Kiểm tra trạng thái khóa tài khoản trước khi vào transaction
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (userDoc.exists && userDoc.data()?['isBlocked'] == true) {
      throw Exception('Tài khoản của bạn đã bị khóa bởi Quản trị viên.');
    }

    final taskRef = _firestore.collection('tasks').doc(taskId);

    await _firestore.runTransaction((transaction) async {
      final taskSnapshot = await transaction.get(taskRef);
      final taskData = taskSnapshot.data();
      if (taskData == null) throw Exception('Không tìm thấy nhiệm vụ');

      if (taskData['posterId'] == currentUserId) {
        throw Exception('Bạn không thể nhận nhiệm vụ của chính mình');
      }

      if (taskData['status'] != 'open') {
        throw Exception('Nhiệm vụ này không còn khả dụng');
      }

      transaction.update(taskRef, {
        'status': TaskStatus.accepted.name,
        'heroId': currentUserId,
        'heroName': _auth.currentUser?.displayName ?? 'Không rõ',
        'acceptedAt': Timestamp.now(),
        'pickedUp': false,
        'delivered': false,
      });
    });

    print('[Firestore] Nhiệm vụ $taskId đã được nhận bởi $currentUserId');
  }

  /// Cập nhật tiến độ nhiệm vụ (bước lấy hàng, giao hàng)
  Future<void> updateTaskProgress(String taskId, Map<String, dynamic> progress) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (userDoc.exists && userDoc.data()?['isBlocked'] == true) {
      throw Exception('Tài khoản của bạn đã bị khóa bởi Quản trị viên.');
    }

    await _firestore.collection('tasks').doc(taskId).update(progress);
    print('[Firestore] Tiến độ nhiệm vụ $taskId đã cập nhật: $progress');
  }

  /// Hủy nhiệm vụ (chỉ poster mới có thể hủy nhiệm vụ đang mở)
  Future<void> cancelTask(String taskId) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data();
    if (taskData == null) return;

    // Xác minh người dùng hiện tại là poster
    if (taskData['posterId'] != currentUserId) {
      throw Exception('Chỉ người đăng nhiệm vụ mới có thể hủy');
    }

    // Chỉ cho phép hủy nhiệm vụ đang mở
    if (taskData['status'] != 'open') {
      throw Exception('Chỉ có thể hủy nhiệm vụ đang mở');
    }

    await _firestore.collection('tasks').doc(taskId).update({
      'status': TaskStatus.cancelled.name,
    });

    // Giảm số lượng nhiệm vụ đã đăng của poster
    await _firestore.collection('users').doc(currentUserId).update({
      'tasksPosted': FieldValue.increment(-1),
    });

    print('[Firestore] Nhiệm vụ $taskId đã bị hủy bởi poster $currentUserId');
  }

  /// Hero hủy nhận việc (chỉ được hủy khi chưa bấm đã lấy hàng)
  Future<void> abandonTask({
    required String taskId,
    required String reason,
  }) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    final taskRef = _firestore.collection('tasks').doc(taskId);
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final heroName = userDoc.data()?['displayName'] ?? _auth.currentUser?.displayName ?? 'Hero';

    await _firestore.runTransaction((transaction) async {
      final taskSnapshot = await transaction.get(taskRef);
      final taskData = taskSnapshot.data();
      if (taskData == null) throw Exception('Không tìm thấy nhiệm vụ');

      if (taskData['heroId'] != currentUserId) {
        throw Exception('Bạn không phải là người nhận nhiệm vụ này');
      }

      if (taskData['status'] == TaskStatus.completed.name) {
        throw Exception('Nhiệm vụ đã hoàn thành, không thể hủy nhận');
      }

      if (taskData['pickedUp'] == true) {
        throw Exception('Bạn đã lấy hàng, không thể tự ý hủy nhận việc. Vui lòng liên hệ Người đăng hoặc Quản trị viên.');
      }

      // Tạo tin nhắn hệ thống ghi nhận lý do vào chat của đơn
      final systemMsg = {
        'senderId': 'system',
        'senderName': 'Hệ thống',
        'text': '$heroName đã hủy nhận việc. Lý do: "$reason". Đơn đã được tự động mở lại cho các Hero khác.',
        'sentAt': Timestamp.now(),
      };

      transaction.update(taskRef, {
        'status': TaskStatus.open.name,
        'heroId': null,
        'heroName': null,
        'acceptedAt': null,
        'pickedUp': false,
        'delivered': false,
        'messages': FieldValue.arrayUnion([systemMsg]),
      });
    });

    print('[Firestore] Hero $currentUserId đã hủy nhận việc nhiệm vụ $taskId. Lý do: $reason');
  }

  /// Hoàn thành nhiệm vụ
  Future<void> completeTask(String taskId) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data();
    if (taskData == null) throw Exception('Không tìm thấy nhiệm vụ');

    // Xác minh người dùng hiện tại có liên quan đến nhiệm vụ (hero hoặc poster)
    final heroId = taskData['heroId'];
    final posterId = taskData['posterId'];
    if (heroId == null) throw Exception('Chưa có Hero nào nhận nhiệm vụ này');

    if (currentUserId != heroId && currentUserId != posterId) {
      throw Exception('Bạn không có quyền hoàn thành nhiệm vụ này');
    }

    if (taskData['status'] == TaskStatus.completed.name) {
      throw Exception('Nhiệm vụ này đã hoàn thành rồi');
    }

    final compensation = (taskData['compensation'] as num?)?.toDouble() ?? 0.0;
    final heroEarnings = compensation * 0.95; // Phí nền tảng 5%

    // Tạo tin nhắn xác nhận thanh toán vào chat
    final systemMsg = {
      'senderId': 'system',
      'senderName': 'Hệ thống',
      'text': 'Thanh toán thành công! Người đăng đã giải phóng ${formatVND(compensation)}. Thù lao ${formatVND(heroEarnings)} đã được cộng vào Ví của Hero.',
      'sentAt': Timestamp.now(),
    };

    // Cập nhật trạng thái nhiệm vụ
    await _firestore.collection('tasks').doc(taskId).update({
      'status': TaskStatus.completed.name,
      'completedAt': Timestamp.now(),
      'isPaid': true,
      'messages': FieldValue.arrayUnion([systemMsg]),
    });
    print('[Firestore] Đã cập nhật trạng thái COMPLETED & isPaid=true cho task $taskId');

    // Cập nhật thu nhập và số nhiệm vụ hoàn thành của hero (dùng heroId, không phải currentUserId)
    try {
      await _firestore.collection('users').doc(heroId).update({
        'totalEarned': FieldValue.increment(heroEarnings),
        'thisMonthEarned': FieldValue.increment(heroEarnings),
        'tasksCompleted': FieldValue.increment(1),
      });
      print('[Firestore] Đã cập nhật tiền thù lao cho Hero $heroId: +${heroEarnings.toStringAsFixed(0)}đ');
      
      // Cập nhật chi tiêu của Poster (người đăng)
      print('[Firestore] Đang cập nhật chi tiêu cho Poster $posterId: +${compensation.toStringAsFixed(0)}đ');
      await _firestore.collection('users').doc(posterId).update({
        'totalSpent': FieldValue.increment(compensation),
      });
      print('[Firestore] Đã cập nhật chi tiêu cho Poster $posterId.');
    } catch (e) {
      print('[Firestore] LỖI khi cập nhật tiền cho Hero $heroId: $e');
      // Thử lại với heroId từ currentUserId nếu poster tự hoàn thành cho chính mình (để test)
      if (currentUserId == heroId) {
        print('[Firestore] Thử lại cập nhật cho chính mình...');
      }
    }

    print('[Firestore] Nhiệm vụ $taskId hoàn thành hoàn toàn.');
  }

  /// Tự động đồng bộ và tính lại ví tiền từ các nhiệm vụ đã hoàn thành thực tế
  Future<void> recalculateUserStats([String? targetUid]) async {
    final uid = targetUid ?? currentUserId;
    if (uid == null) return;

    try {
      final heroTasksSnap = await _firestore
          .collection('tasks')
          .where('heroId', isEqualTo: uid)
          .where('status', isEqualTo: TaskStatus.completed.name)
          .get();

      double earned = 0.0;
      for (final doc in heroTasksSnap.docs) {
        final comp = (doc.data()['compensation'] as num?)?.toDouble() ?? 0.0;
        earned += comp * 0.95;
      }

      final posterTasksSnap = await _firestore
          .collection('tasks')
          .where('posterId', isEqualTo: uid)
          .get();

      double spent = 0.0;
      for (final doc in posterTasksSnap.docs) {
        if (doc.data()['status'] == TaskStatus.completed.name) {
          final comp = (doc.data()['compensation'] as num?)?.toDouble() ?? 0.0;
          spent += comp;
        }
      }

      await _firestore.collection('users').doc(uid).update({
        'totalEarned': earned,
        'thisMonthEarned': earned,
        'totalSpent': spent,
        'tasksCompleted': heroTasksSnap.docs.length,
        'tasksPosted': posterTasksSnap.docs.length,
      });
      print('[Firestore] Đã tính toán và cập nhật lại ví cho $uid: Đã nhận=${earned.toStringAsFixed(0)}đ, Đã làm=${heroTasksSnap.docs.length}');
    } catch (e) {
      print('[Firestore] Lỗi đồng bộ ví tiền: $e');
    }
  }

  /// Rút tiền từ ví TaskHero về tài khoản ngân hàng (Escrow Payout)
  Future<void> withdrawBalance({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');
    if (amount <= 0) throw Exception('Số tiền rút phải lớn hơn 0');

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!userDoc.exists) throw Exception('Hồ sơ không tồn tại');

    final currentBalance = (userDoc.data()?['totalEarned'] as num?)?.toDouble() ?? 0.0;
    if (amount > currentBalance) {
      throw Exception('Số dư khả dụng không đủ để rút số tiền này');
    }

    // 1. Trừ số dư trên Firestore
    await _firestore.collection('users').doc(currentUserId).update({
      'totalEarned': FieldValue.increment(-amount),
    });

    // 2. Ghi nhận giao dịch rút tiền (Withdrawal Request)
    await _firestore.collection('withdrawals').add({
      'userId': currentUserId,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'status': 'completed', // Mô phỏng duyệt tự động
      'createdAt': Timestamp.now(),
    });
    print('[Firestore] Rút tiền thành công: $amountđ cho $currentUserId');
  }

  /// Lấy danh sách nhiệm vụ CHỜ THANH TOÁN (do mình đăng: Hero đã giao hàng hoặc đã xong nhưng chưa thanh toán)
  Stream<List<HeroTask>> getUnpaidTasks() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('tasks')
        .where('posterId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => _taskFromFirestore(doc))
              .where((task) {
                // Điều kiện 1: Đã đánh dấu completed nhưng isPaid == false (cần trả nợ tiền mặt/chuyển khoản)
                final isCompletedUnpaid = (task.status == TaskStatus.completed && task.isPaid == false);
                // Điều kiện 2: Hero đã giao hàng (delivered == true) và đang chờ Poster xác nhận thanh toán ký quỹ
                final isDeliveredWaitingPay = (task.delivered == true && task.status != TaskStatus.completed && task.status != TaskStatus.cancelled);
                
                return isCompletedUnpaid || isDeliveredWaitingPay;
              })
              .toList();

          return list;
        })
        .handleError((e) {
          print('[Firestore] Lỗi luồng nhiệm vụ nhắc nợ: $e');
          return <HeroTask>[];
        });
  }

  /// Đánh dấu là đã gặp mặt trả tiền hoặc chuyển khoản xong
  Future<void> markTaskAsPaid(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'isPaid': true,
    });
    print('[Firestore] Đã dập cờ thanh toán cho nhiệm vụ $taskId');
  }

  /// Gửi tin nhắn trong nhiệm vụ (Task Chat)
  Future<void> sendTaskMessage(String taskId, String text) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');
    final textTrim = text.trim();
    if (textTrim.isEmpty) return;

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (userDoc.exists && userDoc.data()?['isBlocked'] == true) {
      throw Exception('Tài khoản của bạn đã bị khóa bởi Quản trị viên.');
    }

    final senderName = _auth.currentUser?.displayName ?? userDoc.data()?['displayName'] ?? 'Người dùng';

    final messageMap = {
      'senderId': currentUserId,
      'senderName': senderName,
      'text': textTrim,
      'sentAt': Timestamp.now(),
    };

    await _firestore.collection('tasks').doc(taskId).update({
      'messages': FieldValue.arrayUnion([messageMap]),
    });
    print('[Firestore] Đã gửi tin nhắn cho task $taskId: $textTrim');
  }

  /// Gửi đánh giá cho Hero sau khi hoàn thành nhiệm vụ
  Future<void> submitHeroReview({
    required String heroId,
    required String taskId,
    required double rating,
    required String review,
  }) async {
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    // 1. Cập nhật sao và tổng số review của Hero
    final heroDoc = await _firestore.collection('users').doc(heroId).get();
    if (heroDoc.exists) {
      final data = heroDoc.data()!;
      final currentRating = (data['rating'] as num?)?.toDouble() ?? 5.0;
      final currentReviews = (data['totalReviews'] as num?)?.toInt() ?? 0;

      final newTotalReviews = currentReviews + 1;
      final newRating = ((currentRating * currentReviews) + rating) / newTotalReviews;

      await _firestore.collection('users').doc(heroId).update({
        'rating': double.parse(newRating.toStringAsFixed(1)),
        'totalReviews': newTotalReviews,
      });
      print('[Firestore] Đã cập nhật rating cho Hero $heroId: ${newRating.toStringAsFixed(1)}* ($newTotalReviews reviews)');
    }

    // 2. Đánh dấu cờ đã đánh giá trên Task
    await _firestore.collection('tasks').doc(taskId).update({
      'hasReviewed': true,
      'heroRatingGiven': rating,
      'heroReviewComment': review.trim(),
    });
    print('[Firestore] Đã lưu đánh giá cho task $taskId');
  }

  /// Lấy danh sách các đánh giá mà Hero đã nhận được
  Stream<List<Map<String, dynamic>>> getHeroReviewsStream(String heroId) {
    return _firestore
        .collection('tasks')
        .where('heroId', isEqualTo: heroId)
        .where('hasReviewed', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) {
            final data = doc.data();
            DateTime completedDate = DateTime.now();
            if (data['completedAt'] is Timestamp) {
              completedDate = (data['completedAt'] as Timestamp).toDate();
            }
            return {
              'taskId': doc.id,
              'taskTitle': data['title'] ?? 'Nhiệm vụ',
              'posterName': data['posterName'] ?? 'Người đăng',
              'rating': (data['heroRatingGiven'] as num?)?.toDouble() ?? 5.0,
              'comment': (data['heroReviewComment'] as String?) ?? '',
              'completedAt': completedDate,
            };
          }).toList();
          list.sort((a, b) => (b['completedAt'] as DateTime).compareTo(a['completedAt'] as DateTime));
          return list;
        })
        .handleError((e) {
          print('[Firestore] Lỗi lấy danh sách đánh giá: $e');
          return <Map<String, dynamic>>[];
        });
  }

  /// Luồng thông báo thời gian thực tổng hợp các sự kiện của người dùng
  Stream<List<AppNotification>> getNotificationsStream() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('tasks')
        .snapshots()
        .map((snap) {
          final myUid = currentUserId;
          if (myUid == null) return <AppNotification>[];

          final List<AppNotification> notifs = [];

          for (final doc in snap.docs) {
            try {
              final task = _taskFromFirestore(doc);
              final isPoster = task.posterId == myUid;
              final isHero = task.heroId == myUid;

              if (!isPoster && !isHero) continue;

              // 1. Thông báo tin nhắn mới
              if (task.messages.isNotEmpty) {
                final lastMsg = task.messages.last;
                if (lastMsg.senderId != myUid) {
                  final isSystem = lastMsg.senderId == 'system';
                  notifs.add(AppNotification(
                    id: 'chat_${task.id}_${lastMsg.sentAt.millisecondsSinceEpoch}',
                    title: isSystem ? 'Thông báo đơn hàng' : 'Tin nhắn từ ${lastMsg.senderName}',
                    body: isSystem ? lastMsg.text : '"${lastMsg.text}" trong "${task.title}"',
                    type: NotificationType.chat,
                    createdAt: lastMsg.sentAt,
                    task: task,
                  ));
                }
              }

              // 2. Thông báo nhận nhiệm vụ (cho Poster)
              if (isPoster && task.heroId != null && task.acceptedAt != null) {
                notifs.add(AppNotification(
                  id: 'accepted_${task.id}',
                  title: 'Hero đã nhận việc!',
                  body: '${task.heroName ?? "Một Hero"} đã nhận nhiệm vụ "${task.title}".',
                  type: NotificationType.accepted,
                  createdAt: task.acceptedAt!,
                  task: task,
                ));
              }

              // 3. Thông báo đã giao hàng (cho Poster)
              if (isPoster && task.delivered && task.status != TaskStatus.completed) {
                notifs.add(AppNotification(
                  id: 'delivered_${task.id}',
                  title: 'Đã giao hàng đến nơi!',
                  body: '${task.heroName ?? "Hero"} đã giao hàng cho "${task.title}". Vui lòng xác nhận giải phóng thanh toán.',
                  type: NotificationType.delivered,
                  createdAt: task.acceptedAt ?? task.createdAt,
                  task: task,
                ));
              }

              // 4. Thông báo đã thanh toán (cho Hero)
              if (isHero && (task.status == TaskStatus.completed || task.isPaid)) {
                notifs.add(AppNotification(
                  id: 'payment_${task.id}',
                  title: 'Thù lao đã về ví!',
                  body: 'Bạn nhận được ${formatVND(task.heroEarnings)} từ nhiệm vụ "${task.title}".',
                  type: NotificationType.payment,
                  createdAt: task.completedAt ?? task.createdAt,
                  task: task,
                ));
              }

              // 4b. Thông báo thanh toán thành công (cho Người đăng / Poster)
              if (isPoster && (task.status == TaskStatus.completed || task.isPaid)) {
                notifs.add(AppNotification(
                  id: 'poster_paid_${task.id}',
                  title: 'Thanh toán thành công!',
                  body: 'Bạn đã hoàn tất thanh toán ${formatVND(task.compensation)} cho Hero ${task.heroName ?? "thực hiện"}. Đơn "${task.title}" đã hoàn tất.',
                  type: NotificationType.payment,
                  createdAt: task.completedAt ?? task.createdAt,
                  task: task,
                ));
              }

              // 5. Thông báo nhận đánh giá (cho Hero)
              if (isHero && task.hasReviewed && task.completedAt != null) {
                final ratingStr = task.heroRatingGiven?.toStringAsFixed(1) ?? '5.0';
                final commentStr = (task.heroReviewComment != null && task.heroReviewComment!.isNotEmpty)
                    ? ' - "${task.heroReviewComment}"'
                    : '';
                notifs.add(AppNotification(
                  id: 'review_${task.id}',
                  title: 'Bạn nhận được đánh giá mới!',
                  body: 'Người đăng ${task.posterName} đã đánh giá bạn $ratingStr★$commentStr',
                  type: NotificationType.review,
                  createdAt: task.completedAt!,
                  task: task,
                ));
              }
            } catch (_) {}
          }

          notifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifs;
        })
        .handleError((e) {
          print('[Firestore] Lỗi luồng thông báo: $e');
          return <AppNotification>[];
        });
  }

  /// Hàm chuyển đổi Firestore doc thành HeroTask
  HeroTask _taskFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return HeroTask(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: TaskCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => TaskCategory.errands,
      ),
      compensation: (data['compensation'] ?? 0).toDouble(),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TaskStatus.open,
      ),
      urgency: TaskUrgency.values.firstWhere(
        (u) => u.name == data['urgency'],
        orElse: () => TaskUrgency.normal,
      ),
      estimatedMinutes: data['estimatedMinutes'] ?? 0,
      pickup: TaskLocation(
        building: (data['pickup'] is Map) ? (data['pickup']['building'] ?? '') : '',
        level: (data['pickup'] is Map) ? (data['pickup']['level'] ?? '') : '',
        landmark: (data['pickup'] is Map) ? (data['pickup']['landmark'] ?? '') : '',
      ),
      delivery: TaskLocation(
        building: (data['delivery'] is Map) ? (data['delivery']['building'] ?? '') : '',
        level: (data['delivery'] is Map) ? (data['delivery']['level'] ?? '') : '',
        landmark: (data['delivery'] is Map) ? (data['delivery']['landmark'] ?? '') : '',
      ),
      posterId: data['posterId'],
      posterName: data['posterName'] ?? 'Không rõ',
      posterRating: (data['posterRating'] as num?)?.toDouble() ?? 5.0,
      posterAvatarUrl: data['posterAvatarUrl'] ?? '',
      heroId: data['heroId'],
      heroName: data['heroName'],
      pickedUp: data['pickedUp'] ?? false,
      delivered: data['delivered'] ?? false,

      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(), // Dự phòng để tránh crash
      acceptedAt: data['acceptedAt'] != null && data['acceptedAt'] is Timestamp
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null && data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      isPaid: data['isPaid'] ?? false,
      messages: (data['messages'] is List)
          ? (data['messages'] as List)
              .map((m) => TaskMessage.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList()
          : [],
      hasReviewed: data['hasReviewed'] == true,
      heroRatingGiven: (data['heroRatingGiven'] as num?)?.toDouble(),
      heroReviewComment: data['heroReviewComment'],
    );
  }

  // ===== PHƯƠNG THỨC ADMIN =====

  /// Stream danh sách TẤT CẢ người dùng (chỉ dành cho admin)
  Stream<List<UserProfile>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snap) {
          final users = snap.docs.map((doc) {
            try {
              return UserProfile.fromFirestore(doc);
            } catch (e) {
              print('[Firestore] Lỗi khi map user ${doc.id}: $e');
              return null;
            }
          }).whereType<UserProfile>().toList();

          users.sort((a, b) => b.lastActive.compareTo(a.lastActive));
          return users;
        });
  }

  /// Thống kê tổng quan cho admin dashboard
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      print('[Firestore] Bắt đầu getAdminStats (Source: Server)...');
      // Lấy tất cả tasks (Ép buộc server trên Web)
      final tasksSnap = await _firestore.collection('tasks').get(
        kIsWeb ? const GetOptions(source: Source.server) : const GetOptions()
      );
      
      final tasks = tasksSnap.docs.map((doc) {
        try { 
          return _taskFromFirestore(doc); 
        } catch (e) { 
          print('[Firestore] Lỗi parse task ${doc.id}: $e');
          return null; 
        }
      }).whereType<HeroTask>().toList();

      // Lấy tất cả users (Ép buộc server trên Web)
      final usersSnap = await _firestore.collection('users').get(
        kIsWeb ? const GetOptions(source: Source.server) : const GetOptions()
      );

      print('[Firestore] getAdminStats: Lấy xong ${tasks.length} tasks và ${usersSnap.docs.length} users');

      final totalTasks = tasks.length;
      final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();
      final openTasks = tasks.where((t) => t.status == TaskStatus.open).length;

      final totalVolume = completedTasks.fold<double>(0, (sum, t) => sum + t.compensation);
      final platformRevenue = totalVolume * 0.05;

      return {
        'totalUsers': usersSnap.docs.length,
        'totalTasks': totalTasks,
        'completedTasks': completedTasks.length,
        'openTasks': openTasks,
        'totalVolume': totalVolume,
        'platformRevenue': platformRevenue,
        'recentCompleted': completedTasks
            .where((t) => t.completedAt != null)
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!)),
      };
    } catch (e) {
      print('[Firestore] Lỗi NGHIÊM TRỌNG getAdminStats: $e');
      return {};
    }
  }

  /// Admin cập nhật thông tin người dùng bất kỳ
  Future<void> adminUpdateUser(String uid, Map<String, dynamic> updates) async {
    // Lưu ý: Quy tắc Firestore sẽ chặn nếu người gọi không phải ADMIN thực sự
    try {
      await _firestore.collection('users').doc(uid).update(updates);
      print('[Firestore] Admin đã cập nhật user $uid: $updates');
    } catch (e) {
      print('[Firestore] Lỗi Admin cập nhật user $uid: $e');
      rethrow;
    }
  }

  /// Admin xóa người dùng (chỉ xóa doc trong Firestore)
  Future<void> adminDeleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      print('[Firestore] Admin đã xóa user $uid');
    } catch (e) {
      print('[Firestore] Lỗi Admin xóa user $uid: $e');
      rethrow;
    }
  }

  /// Lấy lịch sử nhiệm vụ của một người dùng (đã đăng hoặc được giao)
  Future<List<HeroTask>> getUserTaskHistory(String uid) async {
    try {
      // Lấy nhiệm vụ đã đăng
      final posted = await _firestore
          .collection('tasks')
          .where('posterId', isEqualTo: uid)
          .get();

      // Lấy nhiệm vụ được giao
      final assigned = await _firestore
          .collection('tasks')
          .where('heroId', isEqualTo: uid)
          .get();

      final allTasks = [...posted.docs, ...assigned.docs]
          .map((doc) => _taskFromFirestore(doc))
          .toList();

      // Loại bỏ trùng lặp (nếu có) và sắp xếp
      final uniqueTasks = {for (var t in allTasks) t.id: t}.values.toList();
      uniqueTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return uniqueTasks.cast<HeroTask>();
    } catch (e) {
      print('[Firestore] Lỗi getUserTaskHistory: $e');
      return [];
    }
  }

  /// Lấy danh sách bảng xếp hạng (Top kiếm tiền và Top chi tiêu)
  Future<Map<String, List<UserProfile>>> getLeaderboardData() async {
    final Map<String, List<UserProfile>> result = {
      'topEarners': [],
      'topSpenders': [],
    };

    try {
      // Top 5 Earners
      final earnersSnap = await _firestore
          .collection('users')
          .orderBy('totalEarned', descending: true)
          .limit(5)
          .get();
      result['topEarners'] = earnersSnap.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();

      // Top 5 Spenders
      final spendersSnap = await _firestore
          .collection('users')
          .orderBy('totalSpent', descending: true)
          .limit(5)
          .get();
      result['topSpenders'] = spendersSnap.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[Firestore] Lỗi lấy dữ liệu Leaderboard: $e');
    }

    return result;
  }
}
