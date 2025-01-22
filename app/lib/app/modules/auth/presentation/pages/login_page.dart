import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // bool _isObscured = true;
  // bool _keedLoggedIn = false;
  // final emailController = TextEditingController();
  // final passwordController = TextEditingController();

  // void _toggleObscureText() {
  //   setState(() {
  //     _isObscured = !_isObscured;
  //   });
  // }

  // void login() {
  //   final String email = emailController.text;
  //   final String password = passwordController.text;

  //   final authCubit = context.read<AuthCubit>();

  //   if (email.isNotEmpty && password.isNotEmpty) {
  //     authCubit.login(email, password);
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Email e Senha necessários")));
  //   }
  // }

  @override
  // void dispose() {
  //   emailController.dispose();
  //   passwordController.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Text("login"),
      ),
    );
  }
}
