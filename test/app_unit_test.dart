import 'package:flutter_test/flutter_test.dart';
import 'package:campus_taskhero/models/task_model.dart';
import 'package:campus_taskhero/models/user_profile.dart';
import 'package:campus_taskhero/models/notification_model.dart';
import 'package:campus_taskhero/utils/currency_format.dart';
import 'package:campus_taskhero/utils/vietqr_helper.dart';

void main() {
  group('1. Currency Format Tests', () {
    test('formatVND correctly formats various amounts with Vietnamese dong symbol', () {
      expect(formatVND(0), '0đ');
      expect(formatVND(5000), '5.000đ');
      expect(formatVND(15000), '15.000đ');
      expect(formatVND(100000), '100.000đ');
      expect(formatVND(1250000), '1.250.000đ');
      expect(formatVND(20000000), '20.000.000đ');
    });

    test('formatVND handles floating point and rounding', () {
      expect(formatVND(15000.75), '15.000đ');
      expect(formatVND(9500.2), '9.500đ');
    });
  });

  group('2. VietQR Helper Tests', () {
    test('generateVietQrPayload produces valid EMVCo VietQR string', () {
      final payload = VietQrHelper.generateVietQrPayload(
        accountNumber: '0962359650',
        amount: 25000,
        memo: 'TASK123',
      );

      expect(payload, isNotEmpty);
      expect(payload.startsWith('000201'), isTrue); // EMVCo spec preamble
      expect(payload.contains('0962359650'), isTrue);
    });

    test('getVietQrImageUrl builds valid SePay CDN URL with parameters', () {
      final url = VietQrHelper.getVietQrImageUrl(
        bankShortName: 'MB',
        accountNumber: '0962359650',
        amount: 50000,
        memo: 'HERO TASK 456',
        accountName: 'NGUYEN TRONG HUNG',
      );

      expect(url.startsWith('https://qr.sepay.vn/img?'), isTrue);
      expect(url.contains('bank=MB'), isTrue);
      expect(url.contains('acc=0962359650'), isTrue);
      expect(url.contains('amount=50000'), isTrue);
      expect(url.contains('des=HERO%20TASK%20456'), isTrue);
    });
  });

  group('3. HeroTask Model Tests', () {
    test('HeroTask model properties, calculations and copyWith', () {
      final now = DateTime.now();
      final task = HeroTask(
        id: 'task_001',
        title: 'Mua trà sữa Highlands',
        description: 'Trà sen vàng size L ít đá 30% đường',
        category: TaskCategory.food,
        compensation: 25000,
        status: TaskStatus.open,
        urgency: TaskUrgency.urgent,
        estimatedMinutes: 20,
        pickup: const TaskLocation(building: 'Căng tin', level: 'Tầng 1', landmark: 'Quầy nước'),
        delivery: const TaskLocation(building: 'PKA Block A', level: 'Phòng 402', landmark: 'Bàn giáo viên'),
        posterId: 'user_poster_1',
        posterName: 'Nguyen Van A',
        posterRating: 4.8,
        posterAvatarUrl: 'https://avatar.com/a.png',
        createdAt: now,
      );

      expect(task.title, 'Mua trà sữa Highlands');
      expect(task.category, TaskCategory.food);
      expect(task.compensation, 25000.0);
      expect(task.platformFee, 1250.0); // 5% fee
      expect(task.heroEarnings, 23750.0); // 95% earnings
      expect(task.status, TaskStatus.open);
      expect(task.urgency, TaskUrgency.urgent);
      expect(task.pickup.building, 'Căng tin');
      expect(task.delivery.building, 'PKA Block A');

      final acceptedTask = task.copyWith(
        status: TaskStatus.inProgress,
        heroId: 'hero_999',
        heroName: 'Hero Tran',
        pickedUp: true,
      );

      expect(acceptedTask.status, TaskStatus.inProgress);
      expect(acceptedTask.heroId, 'hero_999');
      expect(acceptedTask.heroName, 'Hero Tran');
      expect(acceptedTask.pickedUp, isTrue);
      expect(acceptedTask.delivered, isFalse);
    });

    test('HeroTask status and category display labels', () {
      expect(TaskCategory.food.label, 'Đồ ăn & Vật phẩm');
      expect(TaskCategory.academic.label, 'Hỗ trợ học tập');
      expect(TaskCategory.errands.label, 'Việc vặt trong khuôn viên');

      expect(TaskStatus.open.label, 'Đang mở');
      expect(TaskStatus.inProgress.label, 'Đang thực hiện');
      expect(TaskStatus.completed.label, 'Đã hoàn thành');
      expect(TaskStatus.cancelled.label, 'Đã hủy');
    });
  });

  group('4. UserProfile Model Tests', () {
    test('UserProfile model handles default fields and role checks', () {
      final now = DateTime.now();
      final profile = UserProfile(
        uid: 'user_123',
        email: 'student@example.com',
        displayName: 'Tran Van Hero',
        pillar: 'ICT-VJ',
        year: 3,
        rating: 4.9,
        totalEarned: 450000,
        totalSpent: 120000,
        createdAt: now,
        lastActive: now,
        isAdmin: false,
        isBlocked: false,
        isVerified: true,
      );

      expect(profile.pillarYear, 'Pillar: ICT-VJ | Year 3');
      expect(profile.isAdmin, isFalse);
      expect(profile.isBlocked, isFalse);
      expect(profile.isVerified, isTrue);
      expect(profile.displayName, 'Tran Van Hero');
      expect(profile.totalEarned, 450000.0);
      expect(profile.totalSpent, 120000.0);
    });
  });

  group('5. Notification Model Tests', () {
    test('AppNotification creates proper notifications and timeAgo calculates appropriately', () {
      final now = DateTime.now();
      final task = HeroTask(
        id: 'task_abc',
        title: 'Chuyển tài liệu sang Block B',
        description: 'Mang tập tài liệu đồ án',
        category: TaskCategory.errands,
        compensation: 30000,
        status: TaskStatus.inProgress,
        urgency: TaskUrgency.normal,
        estimatedMinutes: 15,
        pickup: const TaskLocation(building: 'Thư viện', level: 'Tầng 1'),
        delivery: const TaskLocation(building: 'Block B', level: 'Tầng 3'),
        posterName: 'Le Thi B',
        posterRating: 5.0,
        posterAvatarUrl: '',
        createdAt: now,
        heroName: 'Nguyen Van Hero',
      );

      final notif = AppNotification(
        id: 'notif_1',
        title: 'Hero đã nhận việc!',
        body: 'Nguyen Van Hero đã nhận nhiệm vụ của bạn',
        type: NotificationType.accepted,
        createdAt: now.subtract(const Duration(seconds: 20)),
        task: task,
      );

      expect(notif.type, NotificationType.accepted);
      expect(notif.timeAgo, 'vừa xong');

      final fiveMinutesAgo = AppNotification(
        id: 'notif_2',
        title: 'T',
        body: 'B',
        type: NotificationType.chat,
        createdAt: now.subtract(const Duration(minutes: 5)),
        task: task,
      );
      expect(fiveMinutesAgo.timeAgo, '5p trước');

      final twoHoursAgo = AppNotification(
        id: 'notif_3',
        title: 'T',
        body: 'B',
        type: NotificationType.payment,
        createdAt: now.subtract(const Duration(hours: 2)),
        task: task,
      );
      expect(twoHoursAgo.timeAgo, '2h trước');
    });
  });

  group('6. Form Input Validation Rules Tests', () {
    String? validateName(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return 'Vui lòng nhập họ và tên của bạn';
      if (v.length < 2) return 'Họ và tên phải có ít nhất 2 ký tự';
      return null;
    }

    String? validateEmail(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return 'Vui lòng nhập địa chỉ email';
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
      );
      if (!emailRegex.hasMatch(v)) {
        return 'Email không đúng định dạng';
      }
      final parts = v.split('@');
      if (parts.length == 2) {
        final domain = parts[1];
        if (!domain.contains('.') || domain.endsWith('.') || domain.split('.').last.length < 2) {
          return 'Tên miền email chưa hoàn chỉnh';
        }
      }
      return null;
    }

    String? validatePassword(String? value) {
      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
      if (value.length < 6) return 'Mật khẩu phải có tối thiểu 6 ký tự';
      return null;
    }

    String? validateConfirmPassword(String? value, String password) {
      if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
      if (value != password) return 'Mật khẩu xác nhận không khớp';
      return null;
    }

    String? validateCompensation(String? text) {
      final raw = text?.trim().replaceAll('.', '').replaceAll(',', '') ?? '';
      final parsed = double.tryParse(raw);
      if (parsed == null) return 'Giá tiền không hợp lệ. Vui lòng chỉ nhập số';
      if (parsed < 5000) return 'Mức thù lao tối thiểu là 5.000 ₫';
      if (parsed > 20000000) return 'Mức thù lao tối đa là 20.000.000 ₫';
      return null;
    }

    test('Name validation handles empty, short, and valid names', () {
      expect(validateName(null), isNotNull);
      expect(validateName(''), isNotNull);
      expect(validateName(' '), isNotNull);
      expect(validateName('A'), isNotNull);
      expect(validateName('Hung'), isNull);
      expect(validateName('Nguyen Trong Hung'), isNull);
    });

    test('Email validation rejects malformed domains, missing @, spaces', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('notanemail'), isNotNull);
      expect(validateEmail('abc@'), isNotNull);
      expect(validateEmail('abc@gmail'), isNotNull);
      expect(validateEmail('abc@gmail.'), isNotNull);
      expect(validateEmail('user@gmail.c'), isNotNull); // TLD < 2 chars
      expect(validateEmail('valid.user+test@domain.com'), isNull);
      expect(validateEmail('student@phenikaa-uni.edu.vn'), isNull);
    });

    test('Password and Confirm Password validation enforce security & match', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('12345'), isNotNull);
      expect(validatePassword('123456'), isNull);
      expect(validatePassword('strongPass@2026'), isNull);

      expect(validateConfirmPassword('', '123456'), isNotNull);
      expect(validateConfirmPassword('12345', '123456'), isNotNull);
      expect(validateConfirmPassword('1234567', '123456'), isNotNull);
      expect(validateConfirmPassword('123456', '123456'), isNull);
    });

    test('Compensation validation strictly validates numeric range', () {
      expect(validateCompensation('abc'), isNotNull);
      expect(validateCompensation('12a45'), isNotNull);
      expect(validateCompensation('0'), isNotNull);
      expect(validateCompensation('4999'), isNotNull);
      expect(validateCompensation('5000'), isNull);
      expect(validateCompensation('15.000'), isNull);
      expect(validateCompensation('500,000'), isNull);
      expect(validateCompensation('20000000'), isNull);
      expect(validateCompensation('20000001'), isNotNull);
    });
  });
}
