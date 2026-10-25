import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'models/task_model.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'screens/browse_screen.dart';
import 'screens/post_task_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/admin_user_detail_screen.dart';
import 'services/firestore_service.dart';
import 'models/user_profile.dart';
import 'models/notification_model.dart';
import 'widgets/user_avatar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    try {
      // Use long polling instead of WebSockets to fix "Unable to establish connection on channel" error
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalForceLongPolling: true,
      );
      print('[Firebase] Firestore settings applied with long polling enabled');
    } catch (e) {
      print('[Firebase] Settings already applied or error: $e');
    }
  }

  Animate.restartOnHotReload = true;
  runApp(const TaskHeroApp());
}

class TaskHeroApp extends StatelessWidget {
  const TaskHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'TaskHero',
      themeMode: ThemeMode.light,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadOrangeColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadOrangeColorScheme.dark(),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // Show login screen if not authenticated
          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginScreen();
          }
          
          // Show app if authenticated
          return const AppShell();
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final FirestoreService _firestoreService = FirestoreService();
  int _page = 0;
  HeroTask? _selectedTask;
  UserProfile? _selectedAdminUser;
  UserProfile? _currentUser;

  StreamSubscription<List<AppNotification>>? _notifSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;
  final Set<String> _seenNotificationIds = {};
  bool _isFirstNotifLoad = true;
  AppNotification? _activeInAppNotification;
  Timer? _inAppDismissTimer;

  @override
  void initState() {
    super.initState();
    _profileSubscription = _firestoreService.getUserProfileStream().listen((profile) {
      if (mounted) setState(() => _currentUser = profile);
    });

    _listenToLiveNotifications();
  }

  void _listenToLiveNotifications() {
    _notifSubscription = _firestoreService.getNotificationsStream().listen((notifs) {
      if (!mounted) return;

      if (_isFirstNotifLoad) {
        for (final n in notifs) {
          _seenNotificationIds.add(n.id);
        }
        _isFirstNotifLoad = false;
        return;
      }

      for (final n in notifs) {
        if (!_seenNotificationIds.contains(n.id)) {
          _seenNotificationIds.add(n.id);
          _showInAppNotification(n);
          break;
        }
      }
    });
  }

  void _showInAppNotification(AppNotification notif) {
    _inAppDismissTimer?.cancel();
    setState(() {
      _activeInAppNotification = notif;
    });

    _inAppDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _activeInAppNotification?.id == notif.id) {
        setState(() {
          _activeInAppNotification = null;
        });
      }
    });
  }

  void _dismissInAppNotification() {
    _inAppDismissTimer?.cancel();
    if (mounted) {
      setState(() {
        _activeInAppNotification = null;
      });
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _notifSubscription?.cancel();
    _inAppDismissTimer?.cancel();
    super.dispose();
  }

  bool get _isAdmin => _currentUser?.isAdmin == true;

  List<({IconData icon, String label})> get _navItems {
    final base = [
      (icon: LucideIcons.house, label: 'Bảng điều khiển'),
      (icon: LucideIcons.listTodo, label: 'Nhiệm vụ'),
      (icon: LucideIcons.circlePlus, label: 'Đăng nhiệm vụ'),
      (icon: LucideIcons.user, label: 'Hồ sơ'),
    ];
    if (_isAdmin) {
      return [...base, (icon: LucideIcons.shieldCheck, label: 'Admin')];
    }
    return base;
  }

  void _nav(int i) => setState(() {
        _page = i;
        _selectedTask = null;
        _selectedAdminUser = null;
      });
  void _openTask(HeroTask t) => setState(() => _selectedTask = t);
  void _closeTask() => setState(() => _selectedTask = null);
  void _openAdminUser(UserProfile u) => setState(() => _selectedAdminUser = u);
  void _closeAdminUser() => setState(() => _selectedAdminUser = null);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: isMobile && _selectedTask == null && _selectedAdminUser == null
          ? AppBar(
              backgroundColor: theme.colorScheme.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(LucideIcons.shield, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('TaskHero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.foreground)),
                ],
              ),
              actions: [
                _buildNotificationBell(theme),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: Column(
        children: [
          if (_currentUser?.isBlocked == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFDC2626),
              child: const SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Icon(LucideIcons.ban, color: Colors.white, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tài khoản của bạn đã bị khóa bởi Quản trị viên. Bạn chỉ có quyền xem, không thể đăng bài, nhận việc hoặc nhắn tin.',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                isMobile
                    ? (_selectedTask != null
                        ? TaskDetailScreen(task: _selectedTask!, onBack: _closeTask)
                        : (_selectedAdminUser != null
                            ? AdminUserDetailScreen(user: _selectedAdminUser!, onBack: _closeAdminUser)
                            : _buildPage()))
                    : Row(
                        children: [
                          _buildSidebar(theme),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_selectedTask?.id ?? _selectedAdminUser?.uid ?? _page),
                                child: _selectedTask != null
                                    ? TaskDetailScreen(task: _selectedTask!, onBack: _closeTask)
                                    : (_selectedAdminUser != null
                                        ? AdminUserDetailScreen(user: _selectedAdminUser!, onBack: _closeAdminUser)
                                        : _buildPage()),
                              ),
                            ),
                          ),
                        ],
                      ),
                if (_activeInAppNotification != null)
                  Positioned(
                    top: isMobile ? 12 : 20,
                    left: isMobile ? 16 : null,
                    right: isMobile ? 16 : 24,
                    child: _buildInAppNotificationBanner(theme, _activeInAppNotification!, isMobile: isMobile),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNav(theme) : null,
    );
  }

  // ─── SIDEBAR (desktop) ─────────────────────────────────────
  Widget _buildSidebar(ShadThemeData theme) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        border:
            Border(right: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 24),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(LucideIcons.shield,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('TaskHero', style: theme.textTheme.h4),
                const Spacer(),
                _buildNotificationBell(theme),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Trang chủ',
                style: theme.textTheme.muted.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final active = _page == i && _selectedTask == null;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Material(
                color: active
                    ? AppColors.orangeLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _nav(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(item.icon,
                            size: 16,
                            color: active
                                ? AppColors.orange600
                                : theme.colorScheme.mutedForeground),
                        const SizedBox(width: 10),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: active
                                ? AppColors.orange600
                                : theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Tích hợp',
                style: theme.textTheme.muted.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          _sidebarLabel(theme, LucideIcons.sparkles, 'OpenAI GPT-4o'),
          _sidebarLabel(theme, LucideIcons.mic, 'Deepgram STT'),
          _sidebarLabel(theme, LucideIcons.database, 'Firebase Storage'),
          _sidebarLabel(theme, LucideIcons.creditCard, 'Google Pay'),
          const Spacer(),
          // Bottom user - from Firestore
          StreamBuilder<UserProfile?>(
            stream: _firestoreService.getUserProfileStream(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final displayName = user?.displayName ?? 'Loading...';
              final pillarYear = user != null ? '${user.pillar} Year ${user.year}' : '';
              final photoUrl = user?.photoURL ?? '';
              
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: theme.colorScheme.border)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    UserAvatar(
                      name: displayName,
                      photoUrl: photoUrl,
                      radius: 16,
                      fontSize: 12,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.foreground)),
                          Text(pillarYear,
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      theme.colorScheme.mutedForeground)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sidebarLabel(
      ShadThemeData theme, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon,
                size: 14, color: theme.colorScheme.mutedForeground),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.mutedForeground)),
            const Spacer(),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF16A34A)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM NAV (mobile) ───────────────────────────────────
  Widget _buildBottomNav(ShadThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(
            top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final active = _page == i && _selectedTask == null;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _nav(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon,
                          size: 20,
                          color: active
                              ? AppColors.orange500
                              : theme.colorScheme.mutedForeground),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: active
                              ? AppColors.orange500
                              : theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case 0:
        return HomeScreen(onNavigate: _nav, onTaskTap: _openTask);
      case 1:
        return BrowseScreen(onTaskTap: _openTask);
      case 2:
        return const PostTaskScreen();
      case 3:
        return ProfileScreen(onTaskTap: _openTask);
      case 4:
        return _isAdmin 
          ? AdminScreen(onUserSelected: _openAdminUser) 
          : HomeScreen(onNavigate: _nav, onTaskTap: _openTask);
      default:
        return HomeScreen(onNavigate: _nav, onTaskTap: _openTask);
    }
  }

  Widget _buildInAppNotificationBanner(ShadThemeData theme, AppNotification notif, {required bool isMobile}) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (notif.type) {
      case NotificationType.chat:
        final isSystem = notif.title.contains('Thông báo');
        icon = isSystem ? LucideIcons.bellRing : LucideIcons.messageSquare;
        iconBg = isSystem ? const Color(0xFFFEF3C7) : Colors.blue.shade50;
        iconColor = isSystem ? const Color(0xFFB45309) : Colors.blue.shade600;
        break;
      case NotificationType.accepted:
        icon = LucideIcons.userCheck;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        break;
      case NotificationType.delivered:
        icon = LucideIcons.packageCheck;
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        break;
      case NotificationType.payment:
        icon = LucideIcons.banknote;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        break;
      case NotificationType.review:
        icon = LucideIcons.star;
        iconBg = const Color(0xFFFEF3C7);
        iconColor = Colors.amber.shade700;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          _dismissInAppNotification();
          _openTask(notif.task);
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange400.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.orange500.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            notif.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          'vừa xong',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chạm để xem chi tiết →',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _dismissInAppNotification,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.x, size: 14, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: -0.6, end: 0, curve: Curves.easeOutBack, duration: 400.ms).fadeIn(duration: 300.ms);
  }

  Widget _buildNotificationBell(ShadThemeData theme) {
    return StreamBuilder<List<AppNotification>>(
      stream: _firestoreService.getNotificationsStream(),
      builder: (context, snapshot) {
        final notifs = snapshot.data ?? [];
        final count = notifs.length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                count > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                size: 20,
                color: count > 0 ? AppColors.orange600 : theme.colorScheme.foreground,
              ),
              onPressed: () => _showNotificationsSheet(context, notifs),
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context, List<AppNotification> notifs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.bell, size: 20, color: AppColors.orange500),
                        const SizedBox(width: 8),
                        Text(
                          'Thông báo (${notifs.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.bell, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'Không có thông báo mới',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Các cập nhật về nhận việc, tin nhắn, thanh toán sẽ xuất hiện ở đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, index) {
                          final notif = notifs[index];
                          IconData typeIcon;
                          Color iconBg;
                          Color iconColor;

                          switch (notif.type) {
                            case NotificationType.chat:
                              typeIcon = LucideIcons.messageSquare;
                              iconBg = Colors.blue.shade50;
                              iconColor = Colors.blue.shade600;
                              break;
                            case NotificationType.accepted:
                              typeIcon = LucideIcons.user;
                              iconBg = Colors.green.shade50;
                              iconColor = Colors.green.shade600;
                              break;
                            case NotificationType.delivered:
                              typeIcon = LucideIcons.box;
                              iconBg = Colors.amber.shade50;
                              iconColor = Colors.amber.shade700;
                              break;
                            case NotificationType.payment:
                              typeIcon = LucideIcons.banknote;
                              iconBg = Colors.green.shade50;
                              iconColor = Colors.green.shade700;
                              break;
                            case NotificationType.review:
                              typeIcon = LucideIcons.star;
                              iconBg = Colors.amber.shade50;
                              iconColor = Colors.amber.shade600;
                              break;
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _openTask(notif.task);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(typeIcon, size: 18, color: iconColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif.title,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              notif.timeAgo,
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          notif.body,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
