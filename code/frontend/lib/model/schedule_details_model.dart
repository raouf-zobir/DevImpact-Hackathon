import 'package:flutter/material.dart';
import 'package:sama/core/constants/app_colors.dart';

class ScheduleDetailsModel {
  final Color prefixColor;
  final String title;
  final String subtitle;
  final String date;
  final String time;

  ScheduleDetailsModel(
      {required this.prefixColor,
      required this.title,
      required this.subtitle,
      required this.date,
      required this.time});
}

List<ScheduleDetailsModel> scheduleDetailsModel = [
  ScheduleDetailsModel(
    prefixColor: AppColors.primaryPurple,
    title: "Intelligence Artuficial",
    subtitle: "Class 105",
    date: "March 20, 2023",
    time: "09.00 - 10.00 AM",
  ),
  ScheduleDetailsModel(
    prefixColor: AppColors.accentOrange,
    title: "cyber Security",
    subtitle: "Class 106",
    date: "March 20, 2023",
    time: "09.00 - 10.00 AM",
  ),
  ScheduleDetailsModel(
    prefixColor: AppColors.highlightYellow,
    title: "Alogothim",
    subtitle: "Class 203",
    date: "March 20, 2023",
    time: "09.00 - 10.00 AM",
  ),
  ScheduleDetailsModel(
    prefixColor: AppColors.textBlack,
    title: "Algebra",
    subtitle: "Class 204",
    date: "March 20, 2023",
    time: "09.00 - 10.00 AM",
  ),
];
