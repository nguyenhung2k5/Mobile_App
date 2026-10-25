import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/task_model.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_colors.dart';
import '../services/firestore_service.dart';
import '../utils/currency_format.dart';
import '../utils/vietqr_helper.dart';

class TaskDetailScreen extends StatefulWidget {
  final HeroTask task;
  final VoidCallback onBack;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onBack,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isAccepting = false;

  bool get _isMobile => MediaQuery.of(context).size.width < 768;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final taskId = widget.task.id;

    // Nếu không có ID nhiệm vụ, dùng dữ liệu tĩnh (không nên xảy ra với nhiệm vụ thực)
    if (taskId == null) {
      return _buildContent(theme, widget.task);
    }

    // Luồng cập nhật trực tiếp từ Firestore
    return StreamBuilder<HeroTask?>(
      stream: _firestoreService.getTaskStream(taskId),
      initialData: widget.task,
      builder: (context, snapshot) {
        final task = snapshot.data ?? widget.task;
        return _buildContent(theme, task);
      },
    );
  }

  Widget _buildContent(ShadThemeData theme, HeroTask task) {
    final isAccepted = task.status == TaskStatus.accepted || task.status == TaskStatus.inProgress;
    final isCompleted = task.status == TaskStatus.completed;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isPoster = task.posterId != null && task.posterId == currentUid;
    final isHero = task.heroId != null && task.heroId == currentUid;
    final isOpenAndPoster = isPoster && task.status == TaskStatus.open;
    final showAccept = task.status == TaskStatus.open && !isPoster;
    // Poster xác nhận = nhiệm vụ đã hoàn thành (poster đã thanh toán)
    final posterConfirmed = isCompleted;
    // Hiển thị thanh toán cho POSTER khi hero đã giao nhưng poster chưa thanh toán
    final showPaymentForPoster = isPoster && task.delivered && !isCompleted;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nút quay lại
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.arrowLeft,
                    size: 16, color: AppColors.orange500),
                const SizedBox(width: 6),
                Text('Quay lại',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.orange600)),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 20),
          _buildHeader(theme, task)
              .animate()
              .fadeIn(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 20),
          if (isAccepted || isCompleted) ...[
            _buildProgressTracker(theme, task, isHero: isHero, isCompleted: isCompleted, posterConfirmed: posterConfirmed, isPoster: isPoster, currentUid: currentUid)
                .animate()
                .fadeIn(duration: 400.ms, delay: 150.ms)
                .slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 400.ms,
                    delay: 150.ms),
            const SizedBox(height: 20),
          ],
          if (_isMobile) ...[
            _buildDetails(theme, task)
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms),
            const SizedBox(height: 16),
            _buildLocationCards(theme, task)
                .animate()
                .fadeIn(duration: 400.ms, delay: 250.ms),
            const SizedBox(height: 16),
            _buildPaymentBreakdown(theme, task)
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms),
            const SizedBox(height: 16),
            _buildPosterInfo(theme, task, currentUid: currentUid)
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms),
            if (showAccept) ...[
              const SizedBox(height: 16),
              _buildAcceptSection(theme, task)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms),
            ],
            if (isOpenAndPoster) ...[
              const SizedBox(height: 16),
              _buildCancelSection(theme, task)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms),
            ],
            if (isHero && !task.pickedUp && !isCompleted) ...[
              const SizedBox(height: 16),
              _buildHeroAbandonSection(theme, task)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms),
            ],
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildDetails(theme, task)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 200.ms),
                      const SizedBox(height: 16),
                      _buildLocationCards(theme, task)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 250.ms),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPaymentBreakdown(theme, task)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 300.ms),
                      const SizedBox(height: 16),
                      _buildPosterInfo(theme, task, currentUid: currentUid)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 350.ms),
                      if (showAccept) ...[
                        const SizedBox(height: 16),
                        _buildAcceptSection(theme, task)
                            .animate()
                            .fadeIn(
                                duration: 400.ms, delay: 400.ms),
                      ],
                      if (isOpenAndPoster) ...[
                        const SizedBox(height: 16),
                        _buildCancelSection(theme, task)
                            .animate()
                            .fadeIn(
                                duration: 400.ms, delay: 400.ms),
                      ],
                      if (isHero && !task.pickedUp && !isCompleted) ...[
                        const SizedBox(height: 16),
                        _buildHeroAbandonSection(theme, task)
                            .animate()
                            .fadeIn(
                                duration: 400.ms, delay: 400.ms),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (showPaymentForPoster) ...[
            const SizedBox(height: 20),
            _buildGooglePaySection(theme, task)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, duration: 400.ms),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader(ShadThemeData theme, HeroTask task) {
    if (_isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.foreground),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatVND(task.compensation),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange600),
              ),
              const SizedBox(width: 8),
              Text(
                  'Hero nhận ${formatVND(task.heroEarnings)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.mutedForeground)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _buildStatusPills(theme, task),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _buildStatusPills(theme, task),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatVND(task.compensation),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange600),
            ),
            Text(
                'Hero nhận ${formatVND(task.heroEarnings)}',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.mutedForeground)),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildStatusPills(ShadThemeData theme, HeroTask task) {
    return [
      _pill(task.category.label, AppColors.orangeLight,
          AppColors.orange600),
      if (task.urgency == TaskUrgency.urgent)
        _pill('GẤP', const Color(0xFFFEF3C7),
            const Color(0xFFD97706)),
      if (task.urgency == TaskUrgency.emergency)
        _pill('KHẨN CẤP', const Color(0xFFFEE2E2),
            const Color(0xFFDC2626)),
      if (task.status == TaskStatus.accepted)
        _pill('Đã nhận', const Color(0xFFDCFCE7),
            const Color(0xFF16A34A)),
      if (task.status == TaskStatus.inProgress)
        _pill('Đang thực hiện', const Color(0xFFF3E8FF),
            const Color(0xFF7C3AED)),
      if (task.status == TaskStatus.completed)
        _pill('Hoàn thành', const Color(0xFFDCFCE7),
            const Color(0xFF16A34A)),
      if (task.status == TaskStatus.cancelled)
        _pill('Đã hủy', const Color(0xFFFEE2E2),
            const Color(0xFFDC2626)),
      if (task.status == TaskStatus.open)
        _pill('Đang mở', AppColors.orangeLight, AppColors.orange600),
    ];
  }

  Widget _pill(String label, Color bg, Color fg) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg)),
    );
  }

  Widget _buildProgressTracker(ShadThemeData theme, HeroTask task, {required bool isHero, required bool isCompleted, required bool posterConfirmed, required bool isPoster, required String? currentUid}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tiến độ nhiệm vụ',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.foreground)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                    posterConfirmed
                        ? '4/4'
                        : task.delivered
                            ? '3/4'
                            : task.pickedUp
                                ? '2/4'
                                : '1/4',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.orange600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _step(theme, 'Đã nhận nhiệm vụ',
              'Bạn đã nhận nhiệm vụ này', true, null),
          _step(theme, 'Đã lấy hàng', task.pickup.full, task.pickedUp,
              isHero && !task.pickedUp && !isCompleted
                  ? () async {
                      if (task.id != null) {
                        await _firestoreService.updateTaskProgress(task.id!, {
                          'pickedUp': true,
                          'status': TaskStatus.inProgress.name,
                        });
                      }
                    }
                  : null,
              actionLabel: 'Đánh dấu đã lấy'),
          _step(
              theme,
              'Đã giao',
              task.delivery.full,
              task.delivered,
              isHero && task.pickedUp && !task.delivered && !isCompleted
                  ? () async {
                      if (task.id != null) {
                        await _firestoreService.updateTaskProgress(task.id!, {
                          'delivered': true,
                        });
                      }
                      if (mounted) {
                        ShadToaster.of(context).show(
                          const ShadToast(
                            title: Text('Đã đánh dấu giao hàng'),
                            description: Text('Chờ người đăng xác nhận và thanh toán.'),
                          ),
                        );
                      }
                    }
                  : null,
              actionLabel: 'Đánh dấu đã giao'),
          _step(
              theme,
              'Người đăng đã xác nhận',
              posterConfirmed
                  ? 'Đã thanh toán!'
                  : 'Chờ xác nhận',
              posterConfirmed,
              null,
              isLast: true),
          if (posterConfirmed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.partyPopper,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHero
                          ? 'Hoàn thành! Bạn kiếm được ${formatVND(task.heroEarnings)}'
                          : 'Hoàn thành! Đã thanh toán ${formatVND(task.compensation)}.',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF16A34A)),
                    ),
                  ),
                ],
              ),
            ),
            if (isPoster) ...[
              const SizedBox(height: 8),
              if (task.hasReviewed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.star, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Đã đánh giá Hero: ${task.heroRatingGiven?.toStringAsFixed(1) ?? '5.0'}★${task.heroReviewComment != null && task.heroReviewComment!.isNotEmpty ? ' — "${task.heroReviewComment}"' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.outline(
                    onPressed: () => _showRatingDialog(context, task),
                    size: ShadButtonSize.sm,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.star, size: 14, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text('Đánh giá Hero ngay (1 - 5 sao)'),
                      ],
                    ),
                  ),
                ),
            ],
          ],
          // Hero thấy thông báo "đang chờ poster" sau khi giao nhưng trước khi hoàn thành
          if (task.delivered && !posterConfirmed && isHero) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.orange400.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock,
                      size: 16, color: AppColors.orange500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chờ ${task.posterName} xác nhận giao hàng và thanh toán...',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.orange600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ShadButton.secondary(
              onPressed: () => _openChatBottomSheet(context, task, currentUid: currentUid),
              size: ShadButtonSize.sm,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.messageSquare, size: 14, color: AppColors.orange600),
                  const SizedBox(width: 6),
                  Text(
                    task.messages.isEmpty
                        ? 'Mở trò chuyện trao đổi trực tiếp'
                        : 'Mở tin nhắn trao đổi (${task.messages.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.orange600),
                  ),
                ],
              ),
            ),
          ),
          if (isHero && !task.pickedUp && !isCompleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ShadButton.destructive(
                size: ShadButtonSize.sm,
                onPressed: () => _showAbandonTaskDialog(context, task),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.undo2, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Hủy nhận việc (Trả lại đơn về sàn)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (isHero && task.pickedUp && !isCompleted) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.shieldAlert, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Bạn đã lấy hàng — không thể tự hủy đơn',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _step(ShadThemeData theme, String label, String subtitle,
      bool done, VoidCallback? action,
      {String actionLabel = '', bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                done
                    ? LucideIcons.circleCheck
                    : LucideIcons.circle,
                size: 18,
                color: done
                    ? AppColors.orange500
                    : theme.colorScheme.mutedForeground,
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 24,
                  color: done
                      ? AppColors.orange500
                          .withValues(alpha: 0.3)
                      : theme.colorScheme.border,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        done ? FontWeight.w600 : FontWeight.w400,
                    color: done
                        ? theme.colorScheme.foreground
                        : theme.colorScheme.mutedForeground,
                  ),
                ),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.mutedForeground)),
                if (action != null) ...[
                  const SizedBox(height: 6),
                  ShadButton(
                    size: ShadButtonSize.sm,
                    child: Text(actionLabel),
                    onPressed: action,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(ShadThemeData theme, HeroTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chi tiết nhiệm vụ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 12),
          Text(task.description,
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _detailChip(
                  theme, LucideIcons.clock, '${task.estimatedMinutes} phút'),
              _detailChip(
                  theme, LucideIcons.mapPin, task.delivery.building),
              _detailChip(
                  theme, LucideIcons.tag, task.category.label),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailChip(
      ShadThemeData theme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.orange500),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.mutedForeground)),
      ],
    );
  }

  Widget _buildLocationCards(ShadThemeData theme, HeroTask task) {
    if (_isMobile) {
      return Column(
        children: [
          _locationCard(
              theme, 'Lấy hàng', LucideIcons.mapPin, task.pickup),
          const SizedBox(height: 8),
          _locationCard(theme, 'Giao hàng',
              LucideIcons.navigation, task.delivery),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
            child: _locationCard(
                theme, 'Lấy hàng', LucideIcons.mapPin, task.pickup)),
        const SizedBox(width: 12),
        Expanded(
            child: _locationCard(theme, 'Giao hàng',
                LucideIcons.navigation, task.delivery)),
      ],
    );
  }

  Widget _locationCard(ShadThemeData theme, String label,
      IconData icon, TaskLocation loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.orange500),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.mutedForeground)),
            ],
          ),
          const SizedBox(height: 8),
          Text(loc.building,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.foreground)),
          Text(loc.level,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.mutedForeground)),
          if (loc.landmark.isNotEmpty)
            Text(loc.landmark,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(
      ShadThemeData theme, HeroTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thanh toán',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 12),
          _payRow(theme, 'Tiền thưởng', formatVND(task.compensation)),
          const SizedBox(height: 6),
          _payRow(theme, 'Phí dịch vụ (5%)',
              '-${formatVND(task.platformFee)}',
              muted: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: theme.colorScheme.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hero nhận',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange600)),
              Text(
                  formatVND(task.heroEarnings),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange600)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.orangeLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.creditCard,
                    size: 14, color: AppColors.orange500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Chuyển khoản / Ví điện tử',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.foreground)),
                ),
                Icon(LucideIcons.circleCheck,
                    size: 14,
                    color: const Color(0xFF16A34A)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _payRow(ShadThemeData theme, String label, String value,
      {bool muted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: muted
                    ? theme.colorScheme.mutedForeground
                    : theme.colorScheme.foreground)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                color: muted
                    ? theme.colorScheme.mutedForeground
                    : theme.colorScheme.foreground)),
      ],
    );
  }

  Widget _buildPosterInfo(ShadThemeData theme, HeroTask task, {required String? currentUid}) {
    final isViewerPoster = currentUid != null && currentUid == task.posterId;
    final otherParty = isViewerPoster ? (task.heroName ?? 'Hero') : task.posterName;
    final cardTitle = isViewerPoster
        ? (task.heroName != null ? 'Hero nhận việc' : 'Người đăng (Bạn)')
        : 'Người đăng';
    final displayName = isViewerPoster
        ? (task.heroName ?? task.posterName)
        : task.posterName;
    final avatarUrl = isViewerPoster
        ? (FirebaseAuth.instance.currentUser?.photoURL ?? '')
        : task.posterAvatarUrl;
    final rating = isViewerPoster ? 5.0 : task.posterRating;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cardTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 12),
          Row(
            children: [
              UserAvatar(
                name: displayName,
                photoUrl: avatarUrl,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.foreground)),
                    Row(
                      children: [
                        const Icon(LucideIcons.star,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text('$rating đánh giá',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme
                                    .colorScheme.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  size: ShadButtonSize.sm,
                  leading: const Icon(
                      LucideIcons.messageCircle,
                      size: 14),
                  child: Text(task.messages.isEmpty ? 'Trò chuyện' : 'Trò chuyện (${task.messages.length})'),
                  onPressed: () {
                    if (task.status == TaskStatus.open) {
                      ShadToaster.of(context).show(
                        const ShadToast(
                          title: Text('Chưa thể trò chuyện'),
                          description: Text('Nhiệm vụ cần được Hero nhận trước khi bắt đầu trò chuyện.'),
                        ),
                      );
                    } else {
                      _openChatBottomSheet(context, task, currentUid: currentUid);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  size: ShadButtonSize.sm,
                  leading:
                      const Icon(LucideIcons.phone, size: 14),
                  child: const Text('Gọi'),
                  onPressed: () {
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: Text('Liên hệ $otherParty'),
                        description: const Text('Vui lòng kết nối Zalo hoặc gọi thoại qua thông tin sinh viên đã đăng ký.'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptSection(
      ShadThemeData theme, HeroTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(
            color: AppColors.orange400.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sẵn sàng giúp đỡ?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 4),
          Text(
              'Kiếm ${formatVND(task.heroEarnings)} cho nhiệm vụ này.',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              size: ShadButtonSize.lg,
              leading: _isAccepting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.zap, size: 16),
              child: Text(_isAccepting ? 'Đang nhận...' : 'Nhận nhiệm vụ'),
              onPressed: _isAccepting ? null : () async {
                if (task.id == null) return;
                setState(() => _isAccepting = true);
                try {
                  await _firestoreService.acceptTask(task.id!);
                  if (mounted) {
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text('Đã nhận nhiệm vụ!'),
                        description: Text(
                            'Đi đến ${task.pickup.full} để lấy hàng'),
                      ),
                    );
                    // Quay lại vì trạng thái nhiệm vụ đã thay đổi
                    widget.onBack();
                  }
                } catch (e) {
                  if (mounted) {
                    String msg = e.toString();
                    if (msg.contains('Tài khoản của bạn đã bị khóa')) {
                      msg = 'Tài khoản của bạn đã bị khóa bởi Quản trị viên.';
                    } else if (msg.startsWith('Exception: ')) {
                      msg = msg.substring(11);
                    }
                    ShadToaster.of(context).show(
                      ShadToast.destructive(
                        title: const Text('Không thể nhận nhiệm vụ'),
                        description: Text(msg),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isAccepting = false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSection(ShadThemeData theme, HeroTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nhiệm vụ của bạn',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 4),
          Text(
              'Nhiệm vụ này đang chờ Hero nhận.',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ShadButton.destructive(
              size: ShadButtonSize.lg,
              leading: const Icon(LucideIcons.x, size: 16, color: Colors.white),
              child: const Text('Hủy nhiệm vụ', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (task.id == null) return;
                try {
                  await _firestoreService.cancelTask(task.id!);
                  if (mounted) {
                    ShadToaster.of(context).show(
                      const ShadToast(
                        title: Text('Đã hủy nhiệm vụ'),
                        description: Text('Nhiệm vụ của bạn đã bị xóa.'),
                      ),
                    );
                    widget.onBack();
                  }
                } catch (e) {
                  if (mounted) {
                    ShadToaster.of(context).show(
                      ShadToast.destructive(
                        title: const Text('Lỗi'),
                        description: Text(e.toString()),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAbandonSection(ShadThemeData theme, HeroTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sự cố nhận việc?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 4),
          Text(
              'Bạn chưa lấy hàng. Bạn có thể trả lại đơn nếu có việc đột xuất.',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ShadButton.destructive(
              size: ShadButtonSize.lg,
              leading: const Icon(LucideIcons.undo2, size: 16, color: Colors.white),
              child: const Text('Hủy nhận việc (Trả lại đơn)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: () => _showAbandonTaskDialog(context, task),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGooglePaySection(
      ShadThemeData theme, HeroTask task) {
    return _buildPaymentEscrowSection(theme, task);
  }

  Widget _buildPaymentEscrowSection(
      ShadThemeData theme, HeroTask task) {
    final qrAmount = task.compensation.toInt();
    final taskCode = (task.id != null && task.id!.length >= 6)
        ? task.id!.substring(0, 6).toUpperCase()
        : 'TASK';
    final transferMemo = 'TASKHERO $taskCode';
    final vietQrUrl =
        'https://img.vietqr.io/image/MB-0962359650-compact2.png?amount=$qrAmount&addInfo=${Uri.encodeComponent(transferMemo)}&accountName=NGUYEN%20TRONG%20HUNG';

    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: AppColors.orange400.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange500.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.qrCode,
                    size: 20, color: AppColors.orange600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thanh toán Ký quỹ (Escrow)',
                        style: TextStyle(
                            fontSize: _isMobile ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.foreground)),
                    Text('Mô hình 1: Quét mã VietQR chuyển khoản',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.mutedForeground)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('An toàn 100%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.orangeLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orangeMid),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Số tiền thanh toán',
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.mutedForeground)),
                    Text(formatVND(task.compensation),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tài khoản thụ hưởng',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MB Bank - 0962359650\n(NGUYEN TRONG HUNG)',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Phí nền tảng (5%)',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground)),
                    Text('-${formatVND(task.platformFee)} (bảo trì hệ thống)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.mutedForeground)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hero thực nhận vào ví',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green600)),
                    Text(formatVND(task.heroEarnings),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nút bấm 1: Quét mã VietQR
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              size: ShadButtonSize.lg,
              leading: const Icon(LucideIcons.qrCode, size: 18),
              child: const Text('Quét mã VietQR để thanh toán',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showVietQrModal(context, task, vietQrUrl, transferMemo),
            ),
          ),
          const SizedBox(height: 8),

          // Nút bấm 2: Thanh toán nhanh giả lập / Thẻ Google Pay
          SizedBox(
            width: double.infinity,
            child: ShadButton.outline(
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.creditCard, size: 14),
              child: const Text(
                'Hoặc giải phóng nhanh bằng Thẻ / Google Pay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
              onPressed: () => _executePaymentRelease(context, task),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Tiền sẽ được cộng tự động vào Ví của Hero sau khi giải phóng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }

  void _showVietQrModal(BuildContext context, HeroTask task, String qrUrl, String memo) {
    const bankName = 'MB Bank (Quân Đội)';
    const accountNo = '0962359650';
    const accountHolder = 'NGUYEN TRONG HUNG';
    final amountFormatted = formatVND(task.compensation);
    final rawAmount = task.compensation.toInt().toString();

    final emvPayload = VietQrHelper.generateVietQrPayload(
      accountNumber: accountNo,
      amount: task.compensation.toDouble(),
      memo: memo,
    );
    final sepayQrUrl = VietQrHelper.getVietQrImageUrl(
      bankShortName: 'MBBank',
      accountNumber: accountNo,
      amount: task.compensation.toInt(),
      memo: memo,
      accountName: accountHolder,
    );

    int qrDisplayMode = 0; // 0: Thẻ VietQR chuẩn NAPAS, 1: QR Vector siêu nét

    void copyToClipboard(String text, String label) {
      Clipboard.setData(ClipboardData(text: text));
      ShadToaster.of(context).show(
        ShadToast(
          title: Text('Đã sao chép $label'),
          description: Text(text),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header thanh toán chuyên nghiệp
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.shieldCheck, color: Color(0xFF4ADE80), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cổng Thanh Toán Ký Quỹ',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              Text(
                                'TaskHero Escrow · Bảo vệ 100%',
                                style: TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 18, color: Colors.white70),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Bộ chọn chế độ hiển thị QR (Thẻ NAPAS hoặc Vector trực tiếp)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => qrDisplayMode = 0),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: qrDisplayMode == 0 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: qrDisplayMode == 0
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Thẻ VietQR NAPAS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: qrDisplayMode == 0 ? FontWeight.w700 : FontWeight.w500,
                                          color: qrDisplayMode == 0 ? const Color(0xFF0F172A) : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => qrDisplayMode = 1),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: qrDisplayMode == 1 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: qrDisplayMode == 1
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'QR Vector quét nhanh',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: qrDisplayMode == 1 ? FontWeight.w700 : FontWeight.w500,
                                          color: qrDisplayMode == 1 ? const Color(0xFF0F172A) : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Khung hiển thị mã QR
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              // Dải banner ngân hàng
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A8A),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'MB',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('MB BANK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E3A8A))),
                                          Text('Ngân hàng Quân Đội', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'NAPAS 247',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Nội dung mã QR tùy chế độ
                              if (qrDisplayMode == 0) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    sepayQrUrl,
                                    width: 230,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 230,
                                        width: 230,
                                        alignment: Alignment.center,
                                        child: const CircularProgressIndicator(strokeWidth: 2),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      // Tự động chuyển fallback sang QR Vector nếu CDN có sự cố
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: QrImageView(
                                          data: emvPayload,
                                          version: QrVersions.auto,
                                          size: 190,
                                          backgroundColor: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: emvPayload,
                                    version: QrVersions.auto,
                                    size: 200,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Số tiền thanh toán to, rõ ràng
                              Text(
                                amountFormatted,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                              const Text(
                                'Quét bằng MBBank, VCB, Techcombank, Momo hoặc App bất kỳ',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Thông tin chuyển khoản dạng copy 1 chạm
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildCopyableRow(
                                label: 'Ngân hàng',
                                value: bankName,
                                onCopy: () => copyToClipboard('MB Bank', 'Tên ngân hàng'),
                              ),
                              const Divider(height: 14),
                              _buildCopyableRow(
                                label: 'Chủ tài khoản',
                                value: accountHolder,
                                onCopy: () => copyToClipboard(accountHolder, 'Chủ tài khoản'),
                              ),
                              const Divider(height: 14),
                              _buildCopyableRow(
                                label: 'Số tài khoản',
                                value: accountNo,
                                onCopy: () => copyToClipboard(accountNo, 'Số tài khoản'),
                              ),
                              const Divider(height: 14),
                              _buildCopyableRow(
                                label: 'Số tiền',
                                value: amountFormatted,
                                onCopy: () => copyToClipboard(rawAmount, 'Số tiền'),
                              ),
                              const Divider(height: 14),
                              _buildCopyableRow(
                                label: 'Nội dung CK',
                                value: memo,
                                highlight: true,
                                onCopy: () => copyToClipboard(memo, 'Nội dung chuyển khoản'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Gợi ý hỗ trợ chuyển khoản cùng máy
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.lightbulb, size: 16, color: Color(0xFFB45309)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nếu bạn chuyển tiền trên cùng thiết bị này, hãy chạm nút sao chép STK và Nội dung CK bên trên để dán vào App ngân hàng.',
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nút xác nhận thanh toán
                        SizedBox(
                          width: double.infinity,
                          child: ShadButton(
                            size: ShadButtonSize.lg,
                            backgroundColor: const Color(0xFF16A34A),
                            leading: const Icon(LucideIcons.checkCheck, size: 18, color: Colors.white),
                            child: const Text('Tôi đã chuyển tiền thành công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            onPressed: () async {
                              Navigator.pop(dialogCtx);
                              await _executePaymentRelease(context, task);
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sau khi chuyển khoản, bấm nút trên để hệ thống chốt tiền cho Hero.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableRow({
    required String label,
    required String value,
    bool highlight = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
              ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(LucideIcons.copy, size: 12, color: Color(0xFF475569)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _executePaymentRelease(BuildContext context, HeroTask task) async {
    try {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('Đang xử lý ký quỹ...'),
          description: Text('Hệ thống đang xác nhận và giải phóng thù lao cho Hero.'),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (task.id != null) {
        await _firestoreService.completeTask(task.id!);
      }

      if (context.mounted) {
        _showPaymentSuccessDialog(context, task);
      }
    } catch (e) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Thanh toán thất bại'),
            description: Text(e.toString()),
          ),
        );
      }
    }
  }

  void _showPaymentSuccessDialog(BuildContext context, HeroTask task) {
    final heroName = task.heroName ?? 'Hero';
    final amountPaid = formatVND(task.compensation);
    final heroEarned = formatVND(task.heroEarnings);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCheck, size: 40, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thanh toán thành công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã giải phóng $amountPaid tiền ký quỹ.\nHero $heroName đã nhận được $heroEarned vào ví.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.bellRing, size: 16, color: AppColors.orange500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thông báo giao dịch đã được gửi đến cả bạn và $heroName.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                size: ShadButtonSize.lg,
                backgroundColor: const Color(0xFF16A34A),
                child: const Text('Đánh giá Hero ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  if (mounted) {
                    _showRatingDialog(context, task);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ShadButton.ghost(
                size: ShadButtonSize.sm,
                child: const Text('Để sau'),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendMessage(String taskId) async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    try {
      await _firestoreService.sendTaskMessage(taskId, text);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('Tài khoản của bạn đã bị khóa')) {
          msg = 'Tài khoản của bạn đã bị khóa bởi Quản trị viên.';
        } else if (msg.startsWith('Exception: ')) {
          msg = msg.substring(11);
        }
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Không thể gửi tin nhắn'),
            description: Text(msg),
          ),
        );
      }
    }
  }

  void _openChatBottomSheet(BuildContext context, HeroTask task, {required String? currentUid}) {
    final otherParty = (currentUid == task.posterId) ? (task.heroName ?? 'Hero') : task.posterName;
    final taskId = task.id;
    if (taskId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StreamBuilder<HeroTask?>(
          stream: _firestoreService.getTaskStream(taskId),
          initialData: task,
          builder: (context, snapshot) {
            final liveTask = snapshot.data ?? task;
            final liveMessages = liveTask.messages;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.orangeLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.messageCircle, size: 20, color: AppColors.orange600),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trò chuyện: $otherParty',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  liveTask.title,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: liveMessages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.messagesSquare, size: 40, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text(
                                  'Chưa có tin nhắn nào.\nHãy gửi lời chào tới $otherParty nhé!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _chatScrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: liveMessages.length,
                            itemBuilder: (context, index) {
                              final msg = liveMessages[index];

                              // Tin nhắn hệ thống (ví dụ: thông báo Hero hủy nhận việc)
                              if (msg.senderId == 'system') {
                                return Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.bellRing, size: 14, color: Color(0xFFB45309)),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            msg.text,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber.shade900,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final isMe = msg.senderId == currentUid;
                              final timeStr = '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}';

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? AppColors.orange500 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(14),
                                      topRight: const Radius.circular(14),
                                      bottomLeft: Radius.circular(isMe ? 14 : 2),
                                      bottomRight: Radius.circular(isMe ? 2 : 14),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Text(
                                            msg.senderName,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange600),
                                          ),
                                        ),
                                      Text(
                                        msg.text,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isMe ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: Colors.white,
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Nhập tin nhắn cho $otherParty...',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppColors.orange500),
                                ),
                              ),
                              onSubmitted: (_) => _handleSendMessage(taskId),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: AppColors.orange500,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(LucideIcons.send, size: 16, color: Colors.white),
                              onPressed: () => _handleSendMessage(taskId),
                            ),
                          ),
                        ],
                      ),
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

  void _showAbandonTaskDialog(BuildContext context, HeroTask task) {
    String selectedReason = 'Xe gặp sự cố / Hỏng xe';
    final customReasonController = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      'Xe gặp sự cố / Hỏng xe',
      'Có lịch học / Thi đột xuất',
      'Không liên lạc được người lấy hàng',
      'Thời tiết xấu (mưa to / bão)',
      'Lý do khác',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'Hủy nhận nhiệm vụ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.info, size: 16, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nhiệm vụ sẽ lập tức được mở lại trên sàn để các Hero khác nhận giúp. Người đăng sẽ nhận được lý do bạn hủy.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chọn lý do hủy nhận việc:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...reasons.map((r) => RadioListTile<String>(
                  value: r,
                  groupValue: selectedReason,
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.orange500,
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                )),
                if (selectedReason == 'Lý do khác') ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: customReasonController,
                    decoration: InputDecoration(
                      hintText: 'Nhập cụ thể lý do của bạn...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Giữ lại đơn', style: TextStyle(color: Colors.grey)),
            ),
            ShadButton.destructive(
              size: ShadButtonSize.sm,
              leading: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.undo2, size: 14, color: Colors.white),
              child: Text(isSubmitting ? 'Đang hủy...' : 'Xác nhận hủy việc', style: const TextStyle(color: Colors.white)),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (task.id == null) return;
                      if (selectedReason == 'Lý do khác' && customReasonController.text.trim().isEmpty) {
                        ShadToaster.of(context).show(
                          const ShadToast.destructive(
                            title: Text('Vui lòng nhập lý do'),
                            description: Text('Bạn đã chọn "Lý do khác". Vui lòng mô tả lý do của bạn để tiếp tục.'),
                          ),
                        );
                        return;
                      }
                      final finalReason = selectedReason == 'Lý do khác'
                          ? customReasonController.text.trim()
                          : selectedReason;

                      setDialogState(() => isSubmitting = true);
                      try {
                        await _firestoreService.abandonTask(
                          taskId: task.id!,
                          reason: finalReason,
                        );
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ShadToaster.of(context).show(
                            const ShadToast(
                              title: Text('Đã hủy nhận việc'),
                              description: Text('Nhiệm vụ đã được tự động mở lại cho các Hero khác.'),
                            ),
                          );
                          widget.onBack();
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ShadToaster.of(context).show(
                            ShadToast.destructive(
                              title: const Text('Không thể hủy nhận việc'),
                              description: Text(e.toString()),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, HeroTask task) {
    if (task.heroId == null || task.id == null) return;
    int selectedStars = 5;
    final reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(LucideIcons.star, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Text('Đánh giá Hero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Bạn cảm thấy chất lượng phục vụ của ${task.heroName ?? "Hero"} như thế nào?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isFilled = starValue <= selectedStars;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedStars = starValue;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              LucideIcons.star,
                              size: 32,
                              color: isFilled ? Colors.amber : Colors.grey.shade300,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedStars == 5 ? 'Tuyệt vời (5 sao)'
                          : selectedStars == 4 ? 'Hài lòng (4 sao)'
                          : selectedStars == 3 ? 'Bình thường (3 sao)'
                          : selectedStars == 2 ? 'Chưa tốt (2 sao)'
                          : 'Rất tệ (1 sao)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Nhận xét ngắn về Hero (tùy chọn)...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Bỏ qua'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (task.heroId == null || task.id == null) {
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            await _firestoreService.submitHeroReview(
                              heroId: task.heroId!,
                              taskId: task.id!,
                              rating: selectedStars.toDouble(),
                              review: reviewController.text,
                            );
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (mounted) {
                              ShadToaster.of(context).show(
                                const ShadToast(
                                  title: Text('Đã gửi đánh giá thành công!'),
                                  description: Text('Cảm ơn bạn đã nhận xét dịch vụ.'),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ShadToaster.of(context).show(
                                ShadToast.destructive(
                                  title: const Text('Lỗi'),
                                  description: Text(e.toString()),
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Gửi đánh giá'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
