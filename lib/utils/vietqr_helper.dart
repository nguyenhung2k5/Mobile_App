import 'package:vietqr_gen/vietqr_generator.dart';

class VietQrHelper {
  /// Sinh chuỗi dữ liệu chuẩn EMVCo NAPAS 24/7 (VietQR) dùng cho QrImageView
  static String generateVietQrPayload({
    Bank bank = Bank.mbBank,
    required String accountNumber,
    required double amount,
    required String memo,
  }) {
    return VietQR.generate(
      bank: bank,
      accountNumber: accountNumber,
      amount: amount > 0 ? amount : null,
      message: memo.isNotEmpty ? memo : null,
    );
  }

  /// URL ảnh VietQR chuẩn từ các CDN uy tín có fallback
  /// MB Bank BIN: 970422
  static String getVietQrImageUrl({
    String bankShortName = 'MB',
    required String accountNumber,
    required int amount,
    required String memo,
    required String accountName,
  }) {
    // CDN SePay VietQR (Cực kỳ ổn định và hiển thị đẹp mắt)
    return 'https://qr.sepay.vn/img?bank=$bankShortName&acc=$accountNumber&template=compact&amount=$amount&des=${Uri.encodeComponent(memo)}';
  }
}
