import 'package:flutter/material.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomAppBar(),
      body: Center(
        child: Text("LIBRARY"),
      ),
    );
  }
}
