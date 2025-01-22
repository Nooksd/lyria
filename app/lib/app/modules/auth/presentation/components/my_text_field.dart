
import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isObscured;
  final bool isSecret;
  final VoidCallback toggleObscureText;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.isObscured,
    required this.isSecret,
    required this.toggleObscureText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      style: const TextStyle(fontWeight: FontWeight.normal),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          isSecret ? Icons.lock : CustomIcons.profile,
          color: Theme.of(context).primaryColor,
        ),
        suffixIcon: isSecret
            ? IconButton(
                onPressed: toggleObscureText,
                icon: Icon(
                  isObscured ? Icons.visibility : Icons.visibility_off,
                  color: Theme.of(context).primaryColor,
                ))
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 60),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 3,
            color: Theme.of(context).primaryColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 3,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}
