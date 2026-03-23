import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

void main() {
  runApp(const AcadexApp());
}

class AcadexApp extends StatelessWidget {
  const AcadexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Acadex',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.92),
        items: [
          BottomNavigationBarItem(
            icon: _tabIcon(Icons.description_outlined),
            activeIcon: _tabIcon(Icons.description),
            label: 'Papers',
          ),
          BottomNavigationBarItem(
            icon: _tabIcon(Icons.file_upload_outlined),
            activeIcon: _tabIcon(Icons.file_upload),
            label: 'My Uploads',
          ),
          BottomNavigationBarItem(
            icon: _tabIcon(Icons.account_circle_outlined),
            activeIcon: _tabIcon(Icons.account_circle),
            label: 'User',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const _PapersTab();
          case 1:
            return const _UploadsTab();
          default:
            return const _UserTab();
        }
      },
    );
  }
}

Widget _tabIcon(IconData icon) {
  return SizedBox(
    height: 24,
    width: 24,
    child: Center(
      child: Icon(icon, size: 22),
    ),
  );
}

class _PapersTab extends StatelessWidget {
  const _PapersTab();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Papers'),
        border: null,
      ),
      child: const SafeArea(child: SizedBox.expand()),
    );
  }
}

class _UploadsTab extends StatelessWidget {
  const _UploadsTab();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('My Uploads'),
        border: null,
      ),
      child: const SafeArea(child: SizedBox.expand()),
    );
  }
}

class _UserTab extends StatelessWidget {
  const _UserTab();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('User'),
        border: null,
      ),
      child: const SafeArea(child: SizedBox.expand()),
    );
  }
}

