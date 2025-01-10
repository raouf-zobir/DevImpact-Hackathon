import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sama/core/constants/app_colors.dart';
import 'package:sama/core/constants/app_font_style.dart';
import 'package:sama/core/constants/assets.dart';

class MyPaginations extends StatelessWidget {
  const MyPaginations({
    super.key,
    this.showLength = true,
    this.next,
    this.previous,
    this.index = 1,
    this.length = 3,
    this.maxIndex = 10,
    this.totalItems = 100,
    this.itemsPerPage = 5,
  });

  final bool showLength;
  final int index;
  final int maxIndex;
  final int length;
  final int totalItems;
  final int itemsPerPage;
  final void Function()? next;
  final void Function()? previous;

  @override
  Widget build(BuildContext context) {
    List<String> numActive =
        List.generate(maxIndex + 1, (index) => (index + 1).toString());

    int start = max(0, min(index - 1, maxIndex - length + 1));
    int end = min(maxIndex + 1, start + length);
    if (start >= end) {
      start = max(0, end - length);
    }
    numActive = numActive.sublist(start, end);

    return Row(
      mainAxisAlignment: showLength
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showLength)
          Flexible(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Showing ',
                        style: AppFontStyle.styleRegular16(context)
                            .copyWith(color: AppColors.darkGray)),
                    TextSpan(
                        text:
                            '${(index - 1) * itemsPerPage + 1}-${min(index * itemsPerPage, totalItems)} ',
                        style: AppFontStyle.styleRegular16(context)),
                    TextSpan(
                        text: 'from ',
                        style: AppFontStyle.styleRegular16(context)
                            .copyWith(color: AppColors.darkGray)),
                    TextSpan(
                        text: '$totalItems ',
                        style: AppFontStyle.styleRegular16(context)),
                    TextSpan(
                        text: 'data',
                        style: AppFontStyle.styleRegular16(context)
                            .copyWith(color: AppColors.darkGray)),
                  ],
                ),
              ),
            ),
          ),
        if (showLength)
          Flexible(
              child: SizedBox(width: 120 * getPaginationScaleFactor(context))),
        Flexible(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Dropdown(
                  isActive: index == 1,
                  index: index,
                  maxIndex: maxIndex,
                  angle: pi / 2,
                  onTap: previous,
                ),
                ...List.generate(numActive.length, (i) {
                  bool isActive = (index).toString() == numActive[i];

                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < numActive.length - 1 ? 6 : 0),
                    child: CircleAvatar(
                      radius: 24 * getPaginationScaleFactor(context),
                      backgroundColor: !isActive
                          ? AppColors.darkGray
                          : AppColors.primaryPurple,
                      child: CircleAvatar(
                        radius: 24 * getPaginationScaleFactor(context) - 1.7,
                        backgroundColor:
                            isActive ? AppColors.primaryPurple : Colors.white,
                        child: Center(
                          child: Text(
                            numActive[i],
                            style: AppFontStyle.styleMedium18(context).copyWith(
                              color:
                                  !isActive ? AppColors.darkGray : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Dropdown(
                  isActive: index == maxIndex,
                  angle: -pi / 2,
                  onTap: next,
                  index: index,
                  maxIndex: maxIndex,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Dropdown extends StatelessWidget {
  const Dropdown({
    super.key,
    required this.angle,
    this.onTap,
    required this.index,
    required this.maxIndex,
    required this.isActive,
  });

  final double angle;
  final int index;
  final int maxIndex;
  final bool isActive;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: onTap,
        child: SvgPicture.asset(
          Assets.iconsDropdown,
          height: 32 * getPaginationScaleFactor(context),
          colorFilter: ColorFilter.mode(
              isActive ? AppColors.darkGray : AppColors.primaryPurple,
              BlendMode.srcIn),
        ),
      ),
    );
  }
}

double getPaginationScaleFactor(BuildContext context) {
  return MediaQuery.of(context).textScaleFactor;
}
