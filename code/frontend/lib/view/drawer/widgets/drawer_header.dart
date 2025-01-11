import 'package:flutter/material.dart';
import 'package:sama/core/constants/app_colors.dart';
import 'package:sama/core/constants/app_font_style.dart';

class DrawerTitle extends StatelessWidget {
  const DrawerTitle({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Image.asset(
          //   Assets.imagesLogo,
          //   width: 55,
          //   color: AppColors.lightPurple,
          // ),

          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.accentOrange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "c",
                    style: AppFontStyle.styleBold36(context).copyWith(
                      color: AppColors.backgroundWhite,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Counselor",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightPurple,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
