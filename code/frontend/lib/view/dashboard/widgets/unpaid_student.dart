import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sama/controller/finance_controller.dart';
import 'package:sama/core/constants/app_font_style.dart';
import 'package:sama/core/utils/pagination.dart';
import 'package:sama/view/dashboard/widgets/row_unpaid_student.dart';

class UnpaidStudent extends StatelessWidget {
  const UnpaidStudent({super.key});
  @override
  Widget build(BuildContext context) {

    return Container(
        padding: EdgeInsets.all(32 * getScaleFactor(context)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                "Unpaid Student Intuition",
                style: AppFontStyle.styleBold24(context),
              ),
            ),
            const SizedBox(height: 24),
            GetBuilder<FinanceControllerImp>(builder: (controller) {
              // Add null check and empty list check
              if (controller.unPaidStudent.isEmpty) {
                return const Center(
                  child: Text("No unpaid students"),
                );
              }
              
              return Column(
                children: [
                  ...List.generate(
                    min(controller.unPaidStudent.length, 5),
                    (index) {
                      // Add safety check for remainingBalance
                      if (index >= controller.remainingBalance.length) {
                        return const SizedBox.shrink();
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: RowUnpaidStudent(
                          studentModel: controller.unPaidStudent[index],
                          remainingBalance: controller.remainingBalance[index],
                        ),
                      );
                    },
                  )
                ],
              );
            }),
            const SizedBox(height: 8),
            const MyPaginations(),
          ],
        ));
  }
}
