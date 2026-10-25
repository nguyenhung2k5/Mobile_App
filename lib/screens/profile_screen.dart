import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../models/task_model.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_colors.dart';
import '../utils/currency_format.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(HeroTask)? onTaskTap;

  const ProfileScreen({super.key, this.onTaskTap});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isCreatingProfile = false;
  String? _creationError;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _firestoreService.recalculateUserStats();
  }

  Future<void> _createProfile() async {
    if (_authService.currentUser == null) return;
    
    setState(() {
      _isCreatingProfile = true;
      _creationError = null;
    });

    try {
      print('[Profile] Đang tạo hồ sơ cho ${_authService.currentUser?.uid}');
      await _firestoreService.createOrUpdateUserProfile(_authService.currentUser!);
      print('[Profile] Tạo hồ sơ thành công');
    } catch (e) {
      print('[Profile] Tạo hồ sơ thất bại: $e');
      if (mounted) {
        setState(() {
          _creationError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingProfile = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: StreamBuilder<UserProfile?>(
        stream: _firestoreService.getUserProfileStream(),
        builder: (context, snapshot) {
          // Hiển thị trạng thái đang tải
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải hồ sơ...'),
                ],
              ),
            );
          }

          // Hiển thị trạng thái lỗi
          if (snapshot.hasError) {
            print('[Profile] Lỗi tải hồ sơ: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.x, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Lỗi tải hồ sơ'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ShadButton(
                    onPressed: () {
                      setState(() {}); // Kích hoạt rebuild để thử lại
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final userProfile = snapshot.data;
          
          if (userProfile == null) {
            // Kiểm tra nếu cần tự động tạo hồ sơ (chỉ 1 lần/phiên dể tránh vòng lặp)
            if (_authService.currentUser != null && !_isCreatingProfile) {
               // Xác minh nếu chưa thử gần đây
               _isCreatingProfile = true;
               WidgetsBinding.instance.addPostFrameCallback((_) {
                 _createProfile();
               });
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Đang thiết lập hồ sơ...'),
                  const SizedBox(height: 8),
                  Text(
                    'User ID: ${_authService.currentUser?.uid.substring(0, 5) ?? "unknown"}...',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_creationError != null)
                     Text('Lỗi: $_creationError', style: const TextStyle(color: Colors.red)),
                  
                  const SizedBox(height: 16),
                  ShadButton(
                    onPressed: _isCreatingProfile ? null : _createProfile,
                    child: Text(_isCreatingProfile ? 'Đang tạo...' : 'Sửa nhanh'),
                  ),
                  const SizedBox(height: 8),
                  ShadButton.outline(
                    onPressed: () => _authService.signOut(), // Thoát khẩn cấp
                    child: const Text('Đăng xuất & Thử lại'),
                  ),
                ],
              ),
            );
          }

          print('[Profile] Đã tải hồ sơ: ${userProfile.displayName}');

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề trang
                Text(
                  'Hồ sơ',
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quản lý tài khoản và xem thống kê của bạn.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),

                // Thẻ thông tin người dùng
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.card,
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng trên: Avatar + Thông tin + Nút đăng xuất
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          UserAvatar(
                            name: userProfile.displayName,
                            photoUrl: userProfile.photoURL,
                            radius: isMobile ? 30 : 36,
                            fontSize: 22,
                          ),
                          const SizedBox(width: 16),

                          // Tên + Pillar
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.displayName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.foreground,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _showEditPillarYearDialog(context, userProfile),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userProfile.pillarYear,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: theme.colorScheme.mutedForeground,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        LucideIcons.pencil,
                                        size: 13,
                                        color: AppColors.orange500,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Nút đăng xuất
                          const SizedBox(width: 8),
                          ShadButton.destructive(
                            onPressed: () async {
                              await _authService.signOut();
                            },
                            size: ShadButtonSize.sm,
                            padding: isMobile ? const EdgeInsets.all(8) : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.logOut, size: 14, color: Colors.white),
                                if (!isMobile) ...[
                                  const SizedBox(width: 6),
                                  const Text('Đăng xuất',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Hàng dưới: Rating + Tỉ lệ hoàn thành
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _tabController.animateTo(2),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.star, size: 15, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${userProfile.rating.toStringAsFixed(1)} (${userProfile.totalReviews} đánh giá)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(LucideIcons.check, size: 15, color: AppColors.green500),
                          const SizedBox(width: 4),
                          Text(
                            (userProfile.tasksCompleted + userProfile.tasksPosted) > 0
                                ? '${((userProfile.tasksCompleted / (userProfile.tasksCompleted + userProfile.tasksPosted)) * 100).toInt()}% hoàn thành'
                                : '0% hoàn thành',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // Lưới thống kê
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isMobile ? 2 : 4,
                  childAspectRatio: isMobile ? 1.0 : 1.5, // Thẻ cao hơn để chứa chữ
                  mainAxisSpacing: 12, // Giảm khoảng cách
                  crossAxisSpacing: 12, // Giảm khoảng cách
                  children: [
                    _buildStatCard(
                      theme,
                      'Tổng thu nhập',
                      formatVND(userProfile.totalEarned),
                      userProfile.totalEarned > 0 ? 'tổng thu nhập' : 'chưa có thu nhập',
                      LucideIcons.banknote,
                      AppColors.green500,
                      isMobile: isMobile,
                      changeColor: userProfile.totalEarned > 0 ? AppColors.green600 : Colors.grey,
                    ),
                    _buildStatCard(
                      theme,
                      'Tháng này',
                      formatVND(userProfile.thisMonthEarned),
                      userProfile.thisMonthEarned > 0 ? 'tháng này' : 'chưa có thu nhập',
                      LucideIcons.trendingUp,
                      AppColors.orange500,
                      isMobile: isMobile,
                      changeColor: userProfile.thisMonthEarned > 0 ? AppColors.green600 : Colors.grey,
                    ),
                    _buildStatCard(
                      theme,
                      'Nhiệm vụ làm',
                      '${userProfile.tasksCompleted}',
                      userProfile.tasksCompleted > 0 ? 'nhiệm vụ hoàn thành' : 'chưa có nhiệm vụ',
                      LucideIcons.check,
                      AppColors.blue500,
                      isMobile: isMobile,
                      changeColor: userProfile.tasksCompleted > 0 ? AppColors.green600 : Colors.grey,
                    ),
                    _buildStatCard(
                      theme,
                      'Nhiệm vụ đăng',
                      '${userProfile.tasksPosted}',
                      userProfile.tasksPosted > 0 ? 'nhiệm vụ đã đăng' : 'chưa có nhiệm vụ',
                      LucideIcons.send,
                      AppColors.purple500,
                      isMobile: isMobile,
                      changeColor: userProfile.tasksPosted > 0 ? AppColors.green600 : Colors.grey,
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: 16),

                // Thẻ Ví Ký quỹ Escrow & Rút tiền về Ngân hàng (Mô hình 1)
                _buildEscrowWalletCard(theme, userProfile, isMobile: isMobile)
                    .animate().fadeIn(delay: 150.ms, duration: 400.ms),

                const SizedBox(height: 24),

                // Khu vực Nhắc nhở thanh toán (Pending Payments)
                _buildPendingPaymentsSection(theme),
                const SizedBox(height: 32),

                // Tab nhiệm vụ của tôi
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.card,
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          const Tab(text: 'Tôi đăng'),
                          const Tab(text: 'Tôi nhận'),
                          Tab(text: 'Đánh giá (${userProfile.totalReviews})'),
                        ],
                      ),
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTasksList(_firestoreService.getMyPostedTasks(), theme),
                            _buildTasksList(_firestoreService.getMyAcceptedTasks(), theme),
                            _buildReviewsList(userProfile.uid, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEscrowWalletCard(ShadThemeData theme, UserProfile userProfile, {required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange500.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.wallet, color: AppColors.orange400, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Ví TaskHero Escrow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(LucideIcons.shieldCheck, color: Color(0xFF4ADE80), size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Số dư thực nhận: ${formatVND(userProfile.totalEarned)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4ADE80),
                  ),
                ),
                Text(
                  'Đã trừ 5% phí sàn. Sẵn sàng rút về tài khoản ngân hàng.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton(
                size: ShadButtonSize.sm,
                backgroundColor: AppColors.orange500,
                leading: const Icon(LucideIcons.arrowUpRight, size: 14, color: Colors.white),
                child: const Text('Rút tiền', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => _showWithdrawDialog(context, userProfile),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showWalletHistoryModal(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.receiptText, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Lịch sử ví',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade300,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWalletHistoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.receiptText, color: AppColors.orange500, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Lịch sử Biến động Ví Escrow',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<HeroTask>>(
                stream: _firestoreService.getMyAcceptedTasks(),
                builder: (context, acceptedSnap) {
                  return StreamBuilder<List<HeroTask>>(
                    stream: _firestoreService.getMyPostedTasks(),
                    builder: (context, postedSnap) {
                      if (!acceptedSnap.hasData && !postedSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final accepted = acceptedSnap.data ?? [];
                      final posted = postedSnap.data ?? [];

                      // Tạo danh sách giao dịch ví
                      final List<_WalletTxItem> txs = [];

                      // 1. Thù lao đã nhận (khi là Hero và đơn hoàn tất)
                      for (final task in accepted) {
                        if (task.status == TaskStatus.completed) {
                          txs.add(_WalletTxItem(
                            title: task.title,
                            subtitle: 'Nhận thù lao từ ${task.posterName}',
                            amount: task.heroEarnings,
                            isIncome: true,
                            timestamp: task.completedAt ?? task.createdAt,
                          ));
                        }
                      }

                      // 2. Tiền đã giải phóng thanh toán (khi là Poster và đơn hoàn tất)
                      for (final task in posted) {
                        if (task.status == TaskStatus.completed) {
                          txs.add(_WalletTxItem(
                            title: task.title,
                            subtitle: 'Thanh toán cho Hero ${task.heroName ?? ""}',
                            amount: task.compensation,
                            isIncome: false,
                            timestamp: task.completedAt ?? task.createdAt,
                          ));
                        }
                      }

                      // Sắp xếp giao dịch mới nhất lên đầu
                      txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                      if (txs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.wallet, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Chưa có biến động số dư', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Các giao dịch nhận thù lao và thanh toán sẽ xuất hiện ở đây.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: txs.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          final isIncome = tx.isIncome;
                          return Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                                  color: isIncome ? const Color(0xFF16A34A) : AppColors.orange600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tx.subtitle,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tx.timestamp.hour.toString().padLeft(2, '0')}:${tx.timestamp.minute.toString().padLeft(2, '0')} · ${tx.timestamp.day}/${tx.timestamp.month}/${tx.timestamp.year}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? "+" : "-"}${formatVND(tx.amount)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isIncome ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, UserProfile userProfile) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.sparkles, color: AppColors.orange500, size: 20),
            SizedBox(width: 8),
            Text('Rút tiền về Ngân hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.clock, size: 40, color: AppColors.orange500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'TÍNH NĂNG SẮP RA MẮT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Số dư khả dụng: ${formatVND(userProfile.totalEarned)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Cổng liên kết thanh toán tự động 24/7 đang được hoàn thiện. Trong thời gian này, vui lòng liên hệ Admin TaskHero hoặc quét mã QR đối soát để nhận tiền mặt/chuyển khoản trực tiếp.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              size: ShadButtonSize.sm,
              backgroundColor: AppColors.orange500,
              child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ),
        ],
      ),
    );
  }

  // Hộp thoại chỉnh sửa pillar và năm học
  void _showEditPillarYearDialog(BuildContext context, UserProfile userProfile) {
    String selectedPillar = userProfile.pillar;
    int selectedYear = userProfile.year;
    // final pillars = ['ASD', 'CSD', 'DAI', 'ESD', 'EPD', 'ISTD', 'Freshmore'];
    final pillars = [
      'ICT-VJ',
      'EEE-AI', 'ICT1', 'ICT-AI', 'ICT-TN',
      'MEM1', 'MEM2', 'MSE1', 'MSE-AI',
      'VEE1', 'VEE2', 'FSP1', 'FBE1',
    ];
    final years = [1, 2, 3, 4, 5];
    ///  ý tôi là phần hiển thị ở đây và chỉnh pillar thành Mã Nghành rồi xuống dòng years thành năm học
    // Nếu giá trị cũ không có trong danh sách mới → dùng cái đầu tiên
    if (!pillars.contains(selectedPillar)) {
      selectedPillar = pillars.first;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chỉnh sửa hồ sơ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pillar', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedPillar,
                isExpanded: true,
                items: pillars.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedPillar = value!);
                },
              ),
              const SizedBox(height: 16),
              const Text('Năm', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                items: years.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text('Năm $y'),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedYear = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestoreService.updateUserProfile({
                    'pillar': selectedPillar,
                    'year': selectedYear,
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ShadToaster.of(context).show(
                      ShadToast.destructive(
                        title: const Text('Lỗi cập nhật hồ sơ'),
                        description: Text('$e'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange500,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ShadThemeData theme,
    String label,
    String value,
    String change,
    IconData icon,
    Color iconColor, {
    required bool isMobile,
    Color changeColor = AppColors.green600,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: isMobile ? 14 : 16, color: iconColor),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 18 : 24, // Giảm cỡ chữ trên mobile
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12, // Giảm cỡ chữ trên mobile
              color: changeColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList(Stream<List<HeroTask>> tasksStream, ShadThemeData theme) {
    return StreamBuilder<List<HeroTask>>(
      stream: tasksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.inbox,
                  size: 48,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có nhiệm vụ',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return GestureDetector(
              onTap: widget.onTaskTap != null ? () => widget.onTaskTap!(task) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                  border: Border.all(color: theme.colorScheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      task.category.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task.status.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(task.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatVND(task.compensation),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green600,
                      ),
                    ),
                    if (widget.onTaskTap != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(LucideIcons.chevronRight,
                            size: 16, color: theme.colorScheme.mutedForeground),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingPaymentsSection(ShadThemeData theme) {
    return StreamBuilder<List<HeroTask>>(
      stream: _firestoreService.getUnpaidTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Ẩn khi không có nợ
        }

        final unpaidTasks = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50.withOpacity(0.5),
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bellRing, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cần thanh toán (${unpaidTasks.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Các nhiệm vụ dưới đây đã được Hero hoàn thành. Bạn vui lòng trả tiền công, sau đó bấm Xác nhận để chốt sổ nhé!',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 16),
              ...unpaidTasks.map((task) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(task.category.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hero: ${task.heroName}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatVND(task.compensation),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ShadButton(
                          onPressed: (task.id == null)
                              ? null
                              : () async {
                                  try {
                                    await _firestoreService.markTaskAsPaid(task.id!);
                                    if (context.mounted) {
                                      ShadToaster.of(context).show(
                                        ShadToast(
                                          title: const Text('Thành công'),
                                          description: Text('Đã xác nhận thanh toán cho nhiệm vụ "${task.title}".'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ShadToaster.of(context).show(
                                        ShadToast.destructive(
                                          title: const Text('Lỗi'),
                                          description: Text('Không thể cập nhật: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                          size: ShadButtonSize.sm,
                          backgroundColor: AppColors.green500,
                          child: const Text('Đã thanh toán', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ).animate().slideY(begin: 0.1, duration: 400.ms).fadeIn();
      },
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return AppColors.blue500;
      case TaskStatus.accepted:
        return AppColors.orange500;
      case TaskStatus.inProgress:
        return AppColors.purple500;
      case TaskStatus.completed:
        return AppColors.green500;
      case TaskStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _buildReviewsList(String uid, ShadThemeData theme) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getHeroReviewsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.star, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'Chưa có đánh giá nào.',
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hoàn thành các nhiệm vụ để nhận đánh giá từ cộng đồng!',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final rev = reviews[index];
            final rating = (rev['rating'] as num?)?.toDouble() ?? 5.0;
            final comment = rev['comment']?.toString() ?? '';
            final posterName = rev['posterName']?.toString() ?? 'Người đăng';
            final taskTitle = rev['taskTitle']?.toString() ?? 'Nhiệm vụ';
            final date = rev['completedAt'] as DateTime? ?? DateTime.now();
            final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.orangeLight,
                            child: Text(
                              posterName.isNotEmpty ? posterName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.orange600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            posterName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(LucideIcons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.isNotEmpty ? '"$comment"' : 'Đã đánh giá $rating sao cho nhiệm vụ này.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: comment.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Đơn: $taskTitle',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WalletTxItem {
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final DateTime timestamp;

  _WalletTxItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.timestamp,
  });
}
