import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/auth/presentation/components/my_text_field.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_states.dart';
import 'package:lyria/app/service_locator.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool keedLoggedIn = false;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void login() {
    final String email = emailController.text;
    final String password = passwordController.text;

    final authCubit = getIt<AuthCubit>();

    if (password.length < 5) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Senha muito curta")));
      return;
    }

    if (email.isNotEmpty && password.isNotEmpty) {
      authCubit.login(email, password, keedLoggedIn);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email e Senha necessários")));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return Column(
          children: [
            MyTextField(
              title: "Usuário",
              controller: emailController,
              hintText: "Email ou Username",
              isObscured: false,
            ),
            const SizedBox(height: 20),
            MyTextField(
              title: "Senha",
              controller: passwordController,
              hintText: "Senha",
              isObscured: true,
            ),
            Row(
              children: [
                Checkbox(
                  value: keedLoggedIn,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  activeColor: Theme.of(context).colorScheme.primary,
                  checkColor: Colors.white,
                  side: BorderSide(
                    width: 1,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onChanged: (bool? value) {
                    setState(
                      () {
                        keedLoggedIn = value!;
                      },
                    );
                  },
                ),
                const Text('Manter Login ativo',
                    style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: TextButton(
                onPressed: login,
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Text(
                  state is AuthLoading ? "Entrando..." : "Entrar",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () {},
              child: const Text(
                "Esqueceu sua senha?",
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
