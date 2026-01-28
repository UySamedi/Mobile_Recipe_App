import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../FavoritesScreen/Favorites_View.dart';
import '../HomeScreen/Home_view.dart';
import '../SearchScreen/Search_view.dart';
import 'bottom_nav_controller.dart';

class MainNavBar extends StatelessWidget {
  MainNavBar({super.key});

  final BottomNavController controller = Get.put(BottomNavController());

  final pages = const [
    HomeView(),
    SearchView(),
    FavoritesView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      body: IndexedStack(
        index: controller.selectedIndex.value,
        children: pages,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.1),
            ),
          ],
        ),
        child: GNav(
          gap: 8,
          selectedIndex: controller.selectedIndex.value,
          onTabChange: controller.changeTab,
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5),
          tabBackgroundColor: Colors.green.withOpacity(0.1),
          activeColor: Colors.green,
          color: Colors.grey,
          tabs: const [
            GButton(
              icon: Icons.home, // ✅ REQUIRED (even if using image)
              leading: ImageIcon(
                AssetImage('assets/icons/home.png'),
                size: 20,
              ),
              text: 'Home',
                  textStyle: TextStyle(
                  fontSize: 14, // 👈 text size
                  fontWeight: FontWeight.w600,
                  ),
            ),
            GButton(icon: Icons.home, // ✅ REQUIRED (even if using image)
              leading: ImageIcon(
                AssetImage('assets/icons/search.png'),
                size: 20,
              ),
              text: 'Search',
              textStyle: TextStyle(
                fontSize: 14, // 👈 text size
                fontWeight: FontWeight.w600,
              ),),
            GButton(icon: Icons.home, // ✅ REQUIRED (even if using image)
              leading: ImageIcon(
                AssetImage('assets/icons/favorite.png'),
                size: 20,
              ),
              text: 'Favorites',
              textStyle: TextStyle(
                fontSize: 14, // 👈 text size
                fontWeight: FontWeight.w600,
              ),),
          ],
        ),
      ),
    ));
  }
}
