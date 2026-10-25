import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_nameError != null) {
        setState(() => _nameError = _validateName(_nameController.text));
      }
    });
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = _validateEmail(_emailController.text));
      }
    });
    _passwordController.addListener(() {
      if (_passwordError != null) {
        setState(() => _passwordError = _validatePassword(_passwordController.text));
      }
      if (_confirmPasswordError != null) {
        setState(() => _confirmPasswordError = _validateConfirmPassword(
          _confirmPasswordController.text,
          _passwordController.text,
        ));
      }
    });
    _confirmPasswordController.addListener(() {
      if (_confirmPasswordError != null) {
        setState(() => _confirmPasswordError = _validateConfirmPassword(
          _confirmPasswordController.text,
          _passwordController.text,
        ));
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Vui lòng nhập họ và tên của bạn';
    }
    if (v.length < 2) {
      return 'Họ và tên phải có ít nhất 2 ký tự';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Vui lòng nhập địa chỉ email (VD: ten@gmail.com)';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    if (!emailRegex.hasMatch(v)) {
      return 'Email không đúng định dạng. Ví dụ: user@gmail.com';
    }
    final parts = v.split('@');
    if (parts.length == 2) {
      final domain = parts[1];
      if (!domain.contains('.') || domain.endsWith('.') || domain.split('.').last.length < 2) {
        return 'Tên miền email chưa hoàn chỉnh (Ví dụ: .com, .vn, .edu.vn)';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải có tối thiểu 6 ký tự';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu để xác nhận';
    }
    if (value != password) {
      return 'Mật khẩu xác nhận không khớp với mật khẩu đã nhập';
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

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final nameErr = _validateName(name);
    final emailErr = _validateEmail(email);
    final passErr = _validatePassword(password);
    final confirmErr = _validateConfirmPassword(confirmPassword, password);

    setState(() {
      _nameError = nameErr;
      _emailError = emailErr;
      _passwordError = passErr;
      _confirmPasswordError = confirmErr;
    });

    if (nameErr != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Họ và tên không hợp lệ'),
          description: Text(nameErr),
        ),
      );
      return;
    }

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
          title: const Text('Mật khẩu không hợp lệ'),
          description: Text(passErr),
        ),
      );
      return;
    }

    if (confirmErr != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Xác nhận mật khẩu thất bại'),
          description: Text(confirmErr),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: name,
      );

      if (!mounted) return;

      if (userCredential != null) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Đăng ký thành công!'),
            description: Text('Chào mừng bạn đến với TaskHero. Đang chuyển đến trang chủ...'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Lỗi đăng ký: ${e.code}';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng email khác.';
          setState(() => _emailError = errorMessage);
          break;
        case 'weak-password':
          errorMessage = 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn (tối thiểu 6 ký tự).';
          setState(() => _passwordError = errorMessage);
          break;
        case 'invalid-email':
          errorMessage = 'Địa chỉ email không được máy chủ chấp nhận.';
          setState(() => _emailError = errorMessage);
          break;
        case 'network-request-failed':
          errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra lại đường truyền internet.';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều yêu cầu thử lại. Vui lòng đợi trong giây lát.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Đăng ký bằng email/password chưa được bật. Liên hệ quản trị viên.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Đăng ký thất bại'),
          description: Text(errorMessage),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Đăng ký thất bại'),
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
                  'Tạo tài khoản',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                
                const SizedBox(height: 12),
                
                Text(
                  'Đăng ký để bắt đầu sử dụng TaskHero',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                
                const SizedBox(height: 48),
                
                // Form đăng ký
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.card,
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Trường họ và tên
                        Text(
                          'Họ và tên',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: _nameError != null
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                )
                              : null,
                          child: ShadInput(
                            controller: _nameController,
                            placeholder: const Text('Nguyễn Văn A'),
                          ),
                        ),
                        _buildFieldError(_nameError),

                        const SizedBox(height: 16),

                        // Trường email
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

                        const SizedBox(height: 16),

                        // Trường mật khẩu
                        Text(
                          'Mật khẩu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: _passwordError != null
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                )
                              : null,
                          child: ShadInput(
                            controller: _passwordController,
                            placeholder: const Text('Tối thiểu 6 ký tự'),
                            obscureText: _obscurePassword,
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

                        const SizedBox(height: 16),

                        // Trường xác nhận mật khẩu
                        Text(
                          'Xác nhận mật khẩu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: _confirmPasswordError != null
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                )
                              : null,
                          child: ShadInput(
                            controller: _confirmPasswordController,
                            placeholder: const Text('Nhập lại mật khẩu'),
                            obscureText: _obscureConfirmPassword,
                            onSubmitted: (_) => _handleRegister(),
                            trailing: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                size: 16,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                            ),
                          ),
                        ),
                        _buildFieldError(_confirmPasswordError),

                        const SizedBox(height: 24),

                        // Nút đăng ký
                        SizedBox(
                          width: double.infinity,
                          child: ShadButton(
                            onPressed: _isLoading ? null : _handleRegister,
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
                                : const Text('Đăng ký'),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Đã có tài khoản?\nĐăng nhập',
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
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
