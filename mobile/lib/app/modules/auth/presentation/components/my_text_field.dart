import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String title;
  final bool isObscured;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.title,
    required this.isObscured,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: TextField(
            controller: controller,
            obscureText: isObscured,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontWeight: FontWeight.normal),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(
                isObscured ? CustomIcons.lock : CustomIcons.profile,
                color: Theme.of(context).primaryColor,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 60),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide(
                  width: 1,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide(
                  width: 1,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
