import 'package:flutter/material.dart';
import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _badgeCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  static const _bg       = Color(0xFF0d1117);
  static const _surface  = Color(0xFF161b22);
  static const _border   = Color(0xFF30363d);
  static const _teal     = Color(0xFF00d4b4);
  static const _textPri  = Color(0xFFf0f6fc);
  static const _textMut  = Color(0xFF8b949e);

  void _login() async {
    if (_badgeCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter badge number and secure key')),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          officerBadge: _badgeCtrl.text,
          officerName: 'Officer ${_badgeCtrl.text.split('-').last}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _badgeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // ── Shield logo ──────────────────────────────────────────────
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242c29),
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.shield, color: _teal, size: 40),
                  ),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 3),
                    ),
                    child: const Icon(Icons.verified_user, color: Color(0xFF00382e), size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────────────
              const Text(
                'RAKSHAK',
                style: TextStyle(
                  color: _textPri,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 32, height: 1, color: _border),
                  const SizedBox(width: 8),
                  const Text(
                    'TAMIL NADU POLICE',
                    style: TextStyle(
                      color: _teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 32, height: 1, color: _border),
                ],
              ),
              const SizedBox(height: 32),

              // ── Login card ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Officer Authentication',
                      style: TextStyle(
                        color: _textPri,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Secure access for authorized personnel only.',
                      style: TextStyle(color: _textMut, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Username field
                    const Text(
                      'USERNAME',
                      style: TextStyle(
                        color: _textMut,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInput(
                      controller: _badgeCtrl,
                      hint: 'TN-XXXX-XXXX',
                      icon: Icons.person_outline,
                      obscure: false,
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SECURE KEY',
                          style: TextStyle(
                            color: _textMut,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'RECOVER',
                          style: TextStyle(
                            color: _teal.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInput(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      icon: Icons.vpn_key_outlined,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: _textMut,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // GO ON DUTY button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: const Color(0xFF00382e),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00382e),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'GO ON DUTY',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Biometric
                    Center(
                      child: TextButton.icon(
                        onPressed: _login,
                        icon: const Icon(Icons.fingerprint, color: _textMut, size: 20),
                        label: const Text(
                          'BIOMETRIC LOGIN',
                          style: TextStyle(
                            color: _textMut,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, color: _textMut, size: 14),
                  const SizedBox(width: 4),
                  const Text('CHENNAI HQ', style: TextStyle(color: _textMut, fontSize: 11)),
                  const SizedBox(width: 20),
                  const Icon(Icons.security, color: _textMut, size: 14),
                  const SizedBox(width: 4),
                  const Text('AES-256', style: TextStyle(color: _textMut, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: _textPri, fontSize: 14, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _textMut.withValues(alpha: 0.5), fontFamily: 'monospace'),
          prefixIcon: Icon(icon, color: _textMut, size: 18),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _teal, width: 1.5),
          ),
        ),
      ),
    );
  }
}
