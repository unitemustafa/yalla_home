import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/routing/app_routes.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(text: 'yalla@admin.com');
    _passwordController = TextEditingController(text: '01266666610');
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isLoading = false);
    _goToDashboard();
  }

  void _goToDashboard() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  String? _validateIdentifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'اكتب رقم الموبايل أو الإيميل';
    final looksLikeEmail = text.contains('@') && text.contains('.');
    final looksLikePhone = RegExp(r'^\+?\d{10,15}$').hasMatch(text);
    if (!looksLikeEmail && !looksLikePhone) {
      return 'اكتب إيميل صحيح أو رقم موبايل صحيح';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) return 'كلمة المرور لا تقل عن 6 أحرف';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF111214),
                    AppColors.darkBackground,
                    Color(0xFF171717),
                  ]
                : const [
                    Color(0xFFF3F6FF),
                    AppColors.lightBackground,
                    Color(0xFFFAFBFF),
                  ],
            stops: const [0, 0.42, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 500
                  ? 32.0
                  : 20.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  54,
                  horizontalPadding,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 78,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LoginHeader(isDark: isDark),
                            const SizedBox(height: 30),
                            _LoginTextField(
                              controller: _identifierController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateIdentifier,
                              textInputAction: TextInputAction.next,
                              labelText: 'رقم الموبايل أو الإيميل',
                              prefixIcon: AppIcons.direct_right,
                            ),
                            _LoginTextField(
                              controller: _passwordController,
                              validator: _validatePassword,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _signIn(),
                              labelText: 'كلمة المرور',
                              prefixIcon: AppIcons.password_check,
                              suffixIcon: _obscurePassword
                                  ? AppIcons.eye_slash
                                  : AppIcons.eye,
                              suffixTooltip: _obscurePassword
                                  ? 'إظهار كلمة المرور'
                                  : 'إخفاء كلمة المرور',
                              onSuffixIconPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            _buildRememberAndSupportRow(theme, isDark),
                            const SizedBox(height: 30),
                            AppActionButton(
                              label: 'تسجيل الدخول',
                              isLoading: _isLoading,
                              icon: AppIcons.tick_circle,
                              onPressed: _isLoading ? null : _signIn,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRememberAndSupportRow(ThemeData theme, bool isDark) {
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);
    final disabledTextColor = isDark
        ? Colors.white.withValues(alpha: 0.36)
        : Colors.black.withValues(alpha: 0.34);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: _LoginCheckbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'تذكرني',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: null,
          style: TextButton.styleFrom(
            disabledForegroundColor: disabledTextColor,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'تواصل مع الدعم',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _LoginCheckbox extends StatelessWidget {
  const _LoginCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      checkColor: Colors.white,
      side: BorderSide(
        color: value ? AppColors.primary : AppColors.warning,
        width: 1.8,
      ),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return AppColors.warning.withValues(alpha: 0.16);
      }),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.suffixIcon,
    this.suffixTooltip,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onSuffixIconPressed,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final String? suffixTooltip;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onSuffixIconPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF222326)
        : const Color(0xFFF5F6FA);
    final borderColor = isDark
        ? const Color(0xFF3A3B41)
        : const Color(0xFFE4E7F0);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.64)
        : Colors.black.withValues(alpha: 0.48);
    final textColor = isDark ? Colors.white : const Color(0xFF17181C);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        cursorColor: theme.colorScheme.primary,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          labelStyle: TextStyle(
            color: iconColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(prefixIcon, size: 21, color: iconColor),
          suffixIcon: suffixIcon == null
              ? null
              : IconButton(
                  tooltip: suffixTooltip,
                  onPressed: onSuffixIconPressed,
                  icon: Icon(suffixIcon, size: 21, color: iconColor),
                ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoSurfaceColor = isDark ? Colors.black : Colors.white;
    final logoBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.14);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.26)
        : AppColors.primary.withValues(alpha: 0.14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: logoSurfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: logoBorderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              AppAssets.themedLogo(isDarkMode: isDark),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'أهلاً يا كابتن',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 31,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'تابع طلباتك، افتح العنوان بسرعة، وثبّت التسليم بصورة أو ملاحظة.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? Colors.white.withValues(alpha: 0.58)
                : Colors.black.withValues(alpha: 0.56),
            fontSize: 14.5,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
