import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/music/presentation/includes/music_indicator.dart';
import 'package:lyria/app/modules/ui/components/custom_navigation_destination.dart';

class NavigatorPage extends StatefulWidget {
  final Widget child;
  const NavigatorPage({super.key, required this.child});

  @override
  State<NavigatorPage> createState() => NavigatorPageState();
}

class NavigatorPageState extends State<NavigatorPage> {
  int _selectedIndex = 0;

  final List<String> _routes = [
    '/auth/ui/home',
    '/auth/ui/explorer',
    '/auth/ui/library',
  ];

  void _navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(context).colorScheme.primaryContainer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (_selectedIndex != 0) {
          _navigateBottomBar(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: Stack(
          children: [
            IgnorePointer(
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              baseColor.withValues(alpha: 1),
                              baseColor.withValues(alpha: 0.97),
                              baseColor.withValues(alpha: 0.8),
                              baseColor.withValues(alpha: 0.4),
                              baseColor.withValues(alpha: 0),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedIndex != 0)
              Positioned(
                bottom: 85,
                left: 0,
                right: 0,
                child: const MusicIndicator(),
              ),
            Positioned(
              bottom: 0,
              left: 30,
              right: 30,
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  indicatorColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorShape: const CircleBorder(),
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) {
                      if (states.contains(WidgetState.selected)) {
                        return IconThemeData(
                          color: Theme.of(context).colorScheme.primary,
                          size: 35,
                        );
                      }
                      return IconThemeData(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
                        size: 35,
                      );
                    },
                  ),
                ),
                child: NavigationBar(
                  onDestinationSelected: _navigateBottomBar,
                  selectedIndex: _selectedIndex,
                  destinations: [
                    CustomNavigationDestination(
                      icon: _selectedIndex == 0
                          ? const Icon(CustomIcons.control)
                          : const Icon(CustomIcons.control_outline),
                      label: "Home",
                      isSelected: _selectedIndex == 0,
                    ),
                    CustomNavigationDestination(
                      icon: _selectedIndex == 1
                          ? const Icon(CustomIcons.explore)
                          : const Icon(CustomIcons.explore_outline),
                      label: "Explorer",
                      isSelected: _selectedIndex == 1,
                    ),
                    CustomNavigationDestination(
                      icon: _selectedIndex == 2
                          ? const Icon(CustomIcons.library)
                          : const Icon(CustomIcons.library_outline),
                      label: "Library",
                      isSelected: _selectedIndex == 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
