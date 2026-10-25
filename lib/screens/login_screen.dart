import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  late TabController _tabController;

  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = _validateEmail(_emailController.text));
      }
    });
    _passwordController.addListener(() {
      if (_passwordError != null) {
        setState(() => _passwordError = _validatePassword(_passwordController.text));
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    if (!emailRegex.hasMatch(v)) {
      return 'Email không đúng định dạng. Ví dụ: user@gmail.com';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    return null;
  }

  Widget _buildFieldError(String? errorText) {
    if (errorText == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleAlert, size: 14, color: Color(0xFFDC2626)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              errorText,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailErr = _validateEmail(email);
    final passErr = _validatePassword(password);

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });

    if (emailErr != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Email không hợp lệ'),
          description: Text(emailErr),
        ),
      );
      return;
    }

    if (passErr != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Thiếu mật khẩu'),
          description: Text(passErr),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (userCredential == null) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('Đăng nhập thất bại'),
            description: Text('Không thể hoàn tất đăng nhập.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Lỗi đăng nhập: ${e.code}';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Không tìm thấy tài khoản với email này.';
          setState(() => _emailError = errorMessage);
          break;
        case 'wrong-password':
          errorMessage = 'Mật khẩu không đúng. Vui lòng thử lại.';
          setState(() => _passwordError = errorMessage);
          break;
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ.';
          setState(() => _emailError = errorMessage);
          break;
        case 'user-disabled':
          errorMessage = 'Tài khoản này đã bị khóa hoặc vô hiệu hóa.';
          break;
        case 'invalid-credential':
          errorMessage = 'Email hoặc mật khẩu không chính xác.';
          setState(() {
            _emailError = 'Kiểm tra lại email';
            _passwordError = 'Kiểm tra lại mật khẩu';
          });
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều lần đăng nhập không thành công. Vui lòng thử lại sau.';
          break;
        case 'network-request-failed':
          errorMessage = 'Lỗi mạng. Vui lòng kiểm tra kết nối internet.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Đăng nhập thất bại'),
          description: Text(errorMessage),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Đăng nhập thất bại'),
          description: Text('Lỗi không mong đợi: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (!mounted) return;
      
      if (userCredential == null) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('Đăng nhập thất bại'),
            description: Text('Không thể hoàn tất đăng nhập. Vui lòng kiểm tra console trình duyệt.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'popup-closed-by-user') {
        // Người dùng chủ động đóng cửa sổ đăng nhập Google
        return;
      }
      
      String errorMessage = 'Lỗi xác thực: ${e.code}';
      
      switch (e.code) {
        case 'popup-blocked':
          errorMessage = 'Cửa sổ đăng nhập bị chặn bởi trình duyệt. Vui lòng cho phép popup.';
          break;
        case 'unauthorized-domain':
          errorMessage = 'Tên miền này chưa được ủy quyền trong Firebase. Liên hệ quản trị viên.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google Sign-In chưa được kích hoạt trong Firebase Console.';
          break;
        default:
          errorMessage = e.message ?? e.code;
      }
      
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Đăng nhập thất bại'),
          description: Text(errorMessage),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Đăng nhập thất bại'),
          description: Text('Lỗi không mong đợi: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 24 : 48),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo ứng dụng
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    LucideIcons.shield,
                    size: 40,
                    color: Colors.white,
                  ),
                ).animate().scale(duration: 500.ms).fadeIn(),
                
                const SizedBox(height: 32),
                
                Text(
                  'TaskHero',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                
                const SizedBox(height: 12),
                
                Text(
                  'Sàn giao dịch nhiệm vụ trong trường',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                
                const SizedBox(height: 48),
                
                // Giao diện đăng nhập với tab
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.card,
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Thanh tab
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.colorScheme.border),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppColors.orange600,
                          unselectedLabelColor: theme.colorScheme.mutedForeground,
                          indicatorColor: AppColors.orange500,
                          tabs: const [
                            Tab(text: 'Email'),
                            Tab(text: 'Google'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Nội dung tab
                      SizedBox(
                        height: 380,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab Email/Mật khẩu
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Trường email
                                  Container(
                                    decoration: _emailError != null
                                        ? BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                          )
                                        : null,
                                    child: ShadInput(
                                      controller: _emailController,
                                      placeholder: const Text('email@example.com'),
                                      keyboardType: TextInputType.emailAddress,
                                      onSubmitted: (_) => _handleEmailSignIn(),
                                    ),
                                  ),
                                  _buildFieldError(_emailError),

                                  const SizedBox(height: 16),

                                  // Trường mật khẩu
                                  Container(
                                    decoration: _passwordError != null
                                        ? BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                          )
                                        : null,
                                    child: ShadInput(
                                      controller: _passwordController,
                                      placeholder: const Text('Nhập mật khẩu'),
                                      obscureText: _obscurePassword,
                                      onSubmitted: (_) => _handleEmailSignIn(),
                                      trailing: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(() => _obscurePassword = !_obscurePassword);
                                        },
                                      ),
                                    ),
                                  ),
                                  _buildFieldError(_passwordError),

                                  const SizedBox(height: 8),

                                  // Link quên mật khẩu
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ShadButton.ghost(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Quên mật khẩu?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Nút đăng nhập
                                  SizedBox(
                                    width: double.infinity,
                                    child: ShadButton(
                                      onPressed: _isLoading ? null : _handleEmailSignIn,
                                      size: ShadButtonSize.lg,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text('Đăng nhập'),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Link đăng ký
                                  Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const RegisterScreen(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Chưa có tài khoản?\nĐăng ký',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Google Sign-In Tab
                            Column(
                              children: [
                                const SizedBox(height: 24),
                                
                                Text(
                                  'Đăng nhập bằng tài khoản Google',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                SizedBox(
                                  width: double.infinity,
                                  child: ShadButton(
                                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                                    size: ShadButtonSize.lg,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    'G',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF4285F4),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text('Đăng nhập'),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 32),
                
                Text(
                  'Bằng việc đăng nhập, bạn đồng ý với Điều khoản Dịch vụ\nvà Chính sách Bảo mật',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
