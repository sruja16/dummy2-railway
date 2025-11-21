// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _loading = false;

  bool _obscure = true;
  bool _rememberMe = false;

  late AnimationController _controller;
  late Animation<double> _trainSlide;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _trainSlide = Tween<double>(begin: -0.6, end: 1.4)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString("saved_email");
    final pass = prefs.getString("saved_pass");

    if (email != null && pass != null) {
      setState(() {
        _emailCtrl.text = email;
        _passCtrl.text = pass;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveRememberMe() async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      prefs.setString("saved_email", _emailCtrl.text.trim());
      prefs.setString("saved_pass", _passCtrl.text.trim());
    } else {
      prefs.remove("saved_email");
      prefs.remove("saved_pass");
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email to reset password")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reset email sent")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email & password")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("current_user", cred.user!.email!);

      await _saveRememberMe();

      Navigator.pushReplacementNamed(context, "/");
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD4EAFF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _LoginBg())),

            Positioned(
              bottom: 300,
              left: 0,
              right: 0,
              height: 120,
              child: AnimatedBuilder(
                animation: _trainSlide,
                builder: (_, child) => FractionalTranslation(
                  translation: Offset(_trainSlide.value, 0),
                  child: child,
                ),
                child: const Hero(
                  tag: "trainHero",
                  child: Icon(Icons.train, size: 90, color: Colors.blue),
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(22),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Welcome Back!",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _emailCtrl,
                      decoration: _input("Email"),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: _input("Password").copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() => _obscure = !_obscure);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                            ),
                            const Text("Remember Me"),
                          ],
                        ),
                        TextButton(
                          onPressed: _forgotPassword,
                          child: const Text("Forgot Password?"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.all(14),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Login", style: TextStyle(color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, "/register"),
                      child: const Text(
                        "Don’t have an account? Register",
                        style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}

class _LoginBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();

    p.color = const Color(0xffC8E4FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), p);

    p.color = const Color(0xff7ED957);
    final hill = Path()
      ..moveTo(0, s.height * .55)
      ..quadraticBezierTo(s.width * .4, s.height * .45, s.width, s.height * .55)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height);

    canvas.drawPath(hill, p);

    p.color = Colors.white.withOpacity(.9);
    canvas.drawCircle(const Offset(100, 130), 28, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
