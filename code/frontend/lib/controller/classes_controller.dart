import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:sama/core/constants/classes.dart';
import 'package:sama/core/my_services.dart';
import 'package:sama/model/class_model.dart';
import 'package:sama/model/section_model.dart';
import 'package:sama/model/student_model.dart';

abstract class ClassesController extends GetxController {}

class ClassesControllerImp extends ClassesController {
  int paginationIndex = 0;
  int spilt = 4;
  List<SectionModel> paginationViewSection = [];

  late Box box;
  late int isActive;
  List<SectionModel> allSections = [];
  List<SectionModel> activeSections = [];
  changeIndex(int index) {
    isActive = index;
    paginationIndex = 0;
    getSections(isActive);
    update();
  }

  changeIndexPagination(int newPaginationIndex) {
    int skip = newPaginationIndex * spilt;
    if (newPaginationIndex < 0 || skip >= activeSections.length) {
      paginationViewSection = [];
      update();
      return;
    }
    paginationIndex = newPaginationIndex;
    paginationViewSection =
        activeSections.sublist(skip, min(activeSections.length, skip + spilt));
    update();
  }

  addSection() async {
    String? sectionName = await showDialog<String>(
      context: Get.context!,
      builder: (BuildContext context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Section'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter section name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (sectionName == null || sectionName.isEmpty) return;

    SectionModel sectionModel = SectionModel(
      name: sectionName,
      level: classesModel[isActive].educationLevel,
      grade: classesModel[isActive].grade,
      numberStudent: 0,
    );
    await box.add(sectionModel);
    allSections.add(sectionModel);
    activeSections.add(sectionModel);
    changeIndexPagination(paginationIndex);

    update();
  }

  deleteSection() async {
    if (activeSections.isEmpty) return;

    SectionModel? sectionToDelete = await showDialog<SectionModel>(
      context: Get.context!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Section'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: activeSections.map((section) {
              return ListTile(
                title: Text(section.name),
                onTap: () {
                  Navigator.of(context).pop(section);
                },
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (sectionToDelete == null) return;

    bool? confirmDelete = await showDialog<bool>(
      context: Get.context!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this section and all associated students?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == null || !confirmDelete) return;

    final items = box.values.toList();
    int index = items.indexWhere(
        (item) => item is SectionModel && item.name == sectionToDelete.name);

    List<int> listRemoveIndexSections = [];

    for (var i = 0; i < items.length; i++) {
      if (items[i] is StudentModel) {
        StudentModel student = items[i] as StudentModel;
        if (student.grade == levels[isActive] &&
            student.section == sectionToDelete.name) {
          listRemoveIndexSections.add(i);
        }
      }
    }
    listRemoveIndexSections.sort((a, b) => b.compareTo(a));
    for (var i = 0; i < listRemoveIndexSections.length; i++) {
      box.deleteAt(listRemoveIndexSections[i]);
    }
    box.deleteAt(index);
    allSections.remove(sectionToDelete);
    activeSections.remove(sectionToDelete);
    changeIndexPagination(paginationIndex);

    update();
  }

  getSections(int index) {
    activeSections = allSections.where((element) {
      return element.grade == "Grade ${index + 1}";
    }).toList();
    changeIndexPagination(paginationIndex);
    update();
  }

  getAllSections() {
    allSections = box.values.whereType<SectionModel>().toList();
    update();
  }

  @override
  void onInit() async {
    isActive = 0;
    box = MyAppServices().box;
    getAllSections();
    getSections(isActive);

    super.onInit();
  }
}
