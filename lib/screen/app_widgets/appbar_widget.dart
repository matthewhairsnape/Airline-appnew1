import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const AppbarWidget({
    super.key,
    required this.title,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: AppStyles.appBarColor,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),

          // gradient: LinearGradient(
          //   begin: Alignment.topCenter,
          //   end: Alignment.bottomCenter,
          //   colors: [Colors.blue.shade100, Colors.white],
          // ),\
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withAlpha(0.1),
          //     spreadRadius: 5,
          //     blurRadius: 15,
          //   ),
          // ]
        ),
      ),
      leading: onBackPressed != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_sharp),
              onPressed: onBackPressed,
            )
          : null,
      centerTitle: true,
      title: Text(title,
          style:
              AppStyles.textStyle_18_600.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight * 1.2);
}
