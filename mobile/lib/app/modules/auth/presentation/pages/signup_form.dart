import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/auth/presentation/components/my_text_field.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_states.dart';
import 'package:lyria/app/service_locator.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeController = TextEditingController();

  bool isVerificationStep = false;
  String? verificationEmail;

  void register() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Senha deve ter pelo menos 6 caracteres")),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As senhas não coincidem")),
      );
      return;
    }

    getIt<AuthCubit>().register(name, email, password);
  }

  void verifyEmail() {
    final code = codeController.text.trim();
    if (code.isEmpty || verificationEmail == null) return;

    getIt<AuthCubit>().verifyEmail(verificationEmail!, code);
  }

  void resendCode() {
    if (verificationEmail != null) {
      getIt<AuthCubit>().resendVerification(verificationEmail!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Código reenviado!")),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      bloc: getIt<AuthCubit>(),
      listener: (context, state) {
        if (state is AuthNeedsVerification) {
          setState(() {
            isVerificationStep = true;
            verificationEmail = state.email;
          });
        } else if (state is AuthVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Email verificado! Faça login.")),
          );
          setState(() {
            isVerificationStep = false;
          });
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        bloc: getIt<AuthCubit>(),
        builder: (context, state) {
          if (isVerificationStep) {
            return _buildVerificationForm(state);
          }
          return _buildRegistrationForm(state);
        },
      ),
    );
  }

  Widget _buildRegistrationForm(AuthState state) {
    return Column(
      children: [
        MyTextField(
          title: "Nome",
          controller: nameController,
          hintText: "Seu nome",
          isObscured: false,
        ),
        const SizedBox(height: 20),
        MyTextField(
          title: "Email",
          controller: emailController,
          hintText: "seu@email.com",
          isObscured: false,
        ),
        const SizedBox(height: 20),
        MyTextField(
          title: "Senha",
          controller: passwordController,
          hintText: "Mínimo 6 caracteres",
          isObscured: true,
        ),
        const SizedBox(height: 20),
        MyTextField(
          title: "Confirmar Senha",
          controller: confirmPasswordController,
          hintText: "Repita a senha",
          isObscured: true,
        ),
        const SizedBox(height: 50),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: TextButton(
            onPressed: register,
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              state is AuthLoading ? "Registrando..." : "Criar Conta",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildVerificationForm(AuthState state) {
    return Column(
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 60,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          "Verificação de Email",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Enviamos um código para\n$verificationEmail",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 30),
        MyTextField(
          title: "Código de Verificação",
          controller: codeController,
          hintText: "000000",
          isObscured: false,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: TextButton(
            onPressed: verifyEmail,
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              state is AuthLoading ? "Verificando..." : "Verificar",
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
          onTap: resendCode,
          child: Text(
            "Reenviar código",
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}