import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _emailSent = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = _validateEmail(_emailController.text));
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
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

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final err = _validateEmail(email);
    setState(() => _emailError = err);
    if (err != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Email không hợp lệ'),
          description: Text(err),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.resetPassword(_emailController.text.trim());

      if (!mounted) return;

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Lỗi: ${e.code}';

      switch (e.code) {
        case 'user-not-found':
          // For security, don't reveal if user exists
          setState(() {
            _emailSent = true;
            _isLoading = false;
          });
          return;
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      setState(() => _isLoading = false);

      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Không thể gửi email'),
          description: Text(errorMessage),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Không thể gửi email'),
          description: Text('Lỗi không mong đợi: $e'),
        ),
      );
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
                // Logo
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
                  _emailSent ? 'Email đã được gửi!' : 'Quên mật khẩu',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                
                const SizedBox(height: 12),
                
                Text(
                  _emailSent
                      ? 'Kiểm tra hộp thư của bạn'
                      : 'Nhập email để nhận liên kết đặt lại mật khẩu',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                
                const SizedBox(height: 48),
                
                // Form or success message
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.card,
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _emailSent
                      ? Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.orangeLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.check,
                                size: 32,
                                color: AppColors.orange600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Chúng tôi đã gửi email đặt lại mật khẩu đến:',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.mutedForeground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _emailController.text,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.foreground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ShadButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                size: ShadButtonSize.lg,
                                child: const Text('Quay lại đăng nhập'),
                              ),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email field
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                ),
                              ),
                              _buildFieldError(_emailError),

                              const SizedBox(height: 24),

                              // Send button
                              SizedBox(
                                width: double.infinity,
                                child: ShadButton(
                                  onPressed: _isLoading ? null : _handleResetPassword,
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
                                      : const Text('Gửi email đặt lại mật khẩu'),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Back to login link
                              Center(
                                child: ShadButton.ghost(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Quay lại đăng nhập',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
