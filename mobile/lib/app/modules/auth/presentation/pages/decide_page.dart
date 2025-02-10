import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/auth/presentation/pages/login_form.dart';
import 'package:lyria/app/modules/auth/presentation/pages/signup_form.dart';

class DecidePage extends StatefulWidget {
  const DecidePage({super.key});

  @override
  DecidePageState createState() => DecidePageState();
}

class DecidePageState extends State<DecidePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatingAnimation;
  late bool isExpanded = false;
  late bool isLogin = false;
  final duration = const Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              top: isExpanded ? 10 : screenHeight * 0.2,
              width: screenWidth,
              height: isExpanded ? screenWidth * 0.95 : screenWidth * 0.8,
              child: Center(
                child: Image.asset(
                  "assets/images/background.png",
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(.7),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: duration,
              top: isExpanded ? screenHeight * 0.05 : screenHeight * 0.1,
              left: isExpanded ? screenWidth * 0.3 : screenWidth * 0.15,
              right: screenWidth * 0.15,
              child: AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value),
                    child: Image.asset("assets/images/headset.png"),
                  );
                },
              ),
            ),
            Positioned(
              top: (screenHeight * 0.20) + (screenWidth * 0.8),
              width: screenWidth,
              child: Column(
                children: [
                  const SizedBox(height: 70),
                  const Text(
                    "Conecte-se à música, conecte-se ao mundo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: screenWidth * 0.9,
                    height: screenHeight * 0.06,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isExpanded = !isExpanded;
                          isLogin = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "LOGIN",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: screenWidth * 0.9,
                    height: screenHeight * 0.06,
                    child: OutlinedButton(
                      onPressed: () {
                        // setState(() {
                        //   isExpanded = !isExpanded;
                        //   isLogin = false;
                        // });
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Ainda não disponível")));
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 100,
                          vertical: 15,
                        ),
                        side: const BorderSide(color: Colors.white, width: 2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "REGISTRO",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: duration - const Duration(milliseconds: 100),
              width: screenWidth,
              height: screenHeight * 0.8,
              top: isExpanded ? screenHeight * 0.2 : screenHeight,
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(70),
                    topRight: Radius.circular(70),
                  ),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 160),
                        if (isLogin) const LoginForm() else const SignupForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800),
              top: isExpanded ? screenHeight * 0.05 : screenHeight * 0.1,
              left: isExpanded ? screenWidth * 0.3 : screenWidth * 0.15,
              right: screenWidth * 0.15,
              child: AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value),
                    child: Image.asset("assets/images/headset_half.png"),
                  );
                },
              ),
            ),
            if (isExpanded)
              Positioned(
                top: 20,
                left: 20,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.primaryContainer,
                    ),
                    shape: WidgetStateProperty.all(CircleBorder()),
                    padding: WidgetStateProperty.all(EdgeInsets.all(10)),
                  ),
                  child: Icon(
                    CustomIcons.goback,
                    size: 30,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
