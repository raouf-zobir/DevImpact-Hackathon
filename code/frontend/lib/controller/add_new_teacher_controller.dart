import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sama/controller/navigations_controller.dart';
import 'package:sama/core/enum/navigations_enum.dart';
import 'package:sama/core/helper/random_id.dart';
import 'package:sama/core/my_services.dart';
import 'package:sama/core/utils/validation.dart';
import 'package:sama/model/teacher_model.dart';
import 'dart:io';
import 'package:csv/csv.dart';

abstract class AddNewTeacherController extends GetxController {}

class AddNewTeacherControllerImp extends AddNewTeacherController {
  XFile? image;
  late Box box;

  late TextEditingController firstName;
  late TextEditingController lastName;
  late TextEditingController dateOfBirth;
  late TextEditingController placeOfBirth;
  late TextEditingController email;
  late TextEditingController phone;
  late TextEditingController address;
  late TextEditingController university;
  late TextEditingController degree;
  late TextEditingController startDate;
  late TextEditingController endDate;
  late TextEditingController city;
  late TextEditingController about;
  late TextEditingController expiration;
  GlobalKey<FormState> key = GlobalKey<FormState>();
  List<String> titleTeacherColumn1 = [];
  List<String> titleTeacherColumn2 = [];
  List<String> titleEducationTeacherColumn1 = [];
  List<String> titleEducationTeacherColumn2 = [];

  List<List<String>> hintTeacherColumn1 = [];
  List<List<String>> hintTeacherColumn2 = [];
  List<List<String>> hintEducationTeacherColumn1 = [];
  List<List<String>> hintEducationTeacherColumn2 = [];

  List<List<TextEditingController>> textControllerTeacherColumn1 = [];
  List<List<TextEditingController>> textControllerTeacherColumn2 = [];
  List<List<TextEditingController>> textControllerEducationTeacherColumn2 = [];
  List<List<TextEditingController>> textControllerEducationTeacherColumn1 = [];

  List<List<String? Function(String?)?>> validationTeacherColumn1 = [];
  List<List<String? Function(String?)?>> validationTeacherColumn2 = [];
  List<List<String? Function(String?)?>> validationEducationTeacherColumn1 = [];
  List<List<String? Function(String?)?>> validationEducationTeacherColumn2 = [];
  final TeacherModel? teacher;

  AddNewTeacherControllerImp({this.teacher});

  Future<void> saveFileToLocal(XFile file) async {
    file.saveTo(
        "C:/Users/Raouf/Desktop/Project/Teachers/TeachersPhoto/${file.name}");
  }

  Future addNewTeacher() async {
    if (key.currentState!.validate()) {
      TeacherModel teacherModel = TeacherModel(
        id: teacher?.id ?? generateUniqueNumber(),
        firstName: firstName.text,
        lastName: lastName.text,
        dateOfBirth: dateOfBirth.text,
        placeOfBirth: placeOfBirth.text,
        email: email.text,
        phone: phone.text,
        address: address.text,
        university: university.text,
        degree: degree.text,
        startDate: startDate.text,
        endDate: endDate.text,
        city: city.text,
        about: about.text,
        expiration: expiration.text,
        image: image?.path,
      );

      if (teacher != null) {
        final items = box.values.toList();
        for (int i = 0; i < items.length; i++) {
          if (items[i] is TeacherModel && items[i].id == teacher!.id) {
            await box.putAt(i, teacherModel);
          }
        }
      } else {
        await box.add(teacherModel);
      }

      // Save to CSV
      try {
        const filePath = 'C:/Users/Raouf/Desktop/Project/Teachers/teachers.csv';

        File file = File(filePath);
        List<List<String>> csvData;

        if (await file.exists()) {
          // Read existing CSV data
          String content = await file.readAsString();
          csvData = const CsvToListConverter()
              .convert(content)
              .map((row) => row.map((cell) => cell.toString()).toList())
              .toList();
        } else {
          // If file does not exist, initialize with a header
          csvData = [
            [
              "ID",
              "First Name",
              "Last Name",
              "Date of Birth",
              "Place of Birth",
              "Email",
              "Phone",
              "Address",
              "University",
              "Degree",
              "Start Date",
              "End Date",
              "City",
              "About",
              "Expiration",
              "Image"
            ]
          ];
        }

        // Add new teacher data to CSV
        csvData.add([
          teacherModel.id.toString(),
          teacherModel.firstName,
          teacherModel.lastName,
          teacherModel.dateOfBirth,
          teacherModel.placeOfBirth,
          teacherModel.email,
          teacherModel.phone,
          teacherModel.address,
          teacherModel.university,
          teacherModel.degree,
          teacherModel.startDate,
          teacherModel.endDate,
          teacherModel.city,
          teacherModel.about,
          teacherModel.expiration,
          teacherModel.image ?? "",
        ]);

        // Convert to CSV string and save
        String csvString = const ListToCsvConverter().convert(csvData);
        await file.writeAsString(csvString);

        debugPrint("Data saved to CSV successfully: $filePath");
      } catch (e) {
        debugPrint("Error saving CSV: $e");
      }

      Get.find<NavigationControllerImp>()
          .replaceLastWidget(NavigationEnum.Teachers);
    }
  }

  void pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      image = pickedFile;
      update();
    }
  }

  void removeImage() async {
    image = null;
    update();
  }

  dropImage(detail) async {
    for (final file in detail.files) {
      String extension = file.path.split('.').last.toLowerCase();
      if (extension == 'png' || extension == 'jpg') {
        image = await file;
        update();
        return;
      }
    }
  }

  @override
  void onInit() async {
    firstName = TextEditingController(text: teacher?.firstName);
    lastName = TextEditingController(text: teacher?.lastName);
    dateOfBirth = TextEditingController(text: teacher?.dateOfBirth);
    placeOfBirth = TextEditingController(text: teacher?.placeOfBirth);
    email = TextEditingController(text: teacher?.email);
    phone = TextEditingController(text: teacher?.phone);
    address = TextEditingController(text: teacher?.address);
    university = TextEditingController(text: teacher?.university);
    degree = TextEditingController(text: teacher?.degree);
    startDate = TextEditingController(text: teacher?.startDate);
    endDate = TextEditingController(text: teacher?.endDate);
    city = TextEditingController(text: teacher?.city);
    about = TextEditingController(text: teacher?.about);
    expiration = TextEditingController(text: teacher?.expiration);

    image = teacher?.image != null && teacher!.image!.isNotEmpty
        ? XFile(teacher!.image!)
        : null;

    titleTeacherColumn1 = [
      "First Name *",
      "Email *",
      "Address *",
      "Date of Birth *"
    ];
    titleTeacherColumn2 = ["Last Name *", "Phone *"];
    titleEducationTeacherColumn1 = ["University *", "Start & End Date *"];
    titleEducationTeacherColumn2 = ["Degree *", "City *"];

    hintTeacherColumn1 = [
      ["First Name"],
      ["Email"],
      ["Rue des 1er Novembre, Villa 45 Rahmania, Wilaya of Algiers"],
      ["ex: 2005-12-02"]
    ];
    hintTeacherColumn2 = [
      ["Last Name"],
      ["Phone"],
    ];
    hintEducationTeacherColumn1 = [
      ["University USTHB Algiers"],
      ["ex: 2013-10-03", "ex: 2017-10-03"],
    ];
    hintEducationTeacherColumn2 = [
      ["History Major"],
      ["Douera,Algier"],
    ];

    validationTeacherColumn1 = [
      [Validation.length],
      [Validation.validateEmail],
      [Validation.length],
      [Validation.dateFormat]
    ];
    validationTeacherColumn2 = [
      [Validation.length],
      [Validation.isPhoneNumberValid],
    ];
    validationEducationTeacherColumn1 = [
      [Validation.length],
      [Validation.dateFormat, Validation.dateFormat]
    ];
    validationEducationTeacherColumn2 = [
      [Validation.length],
      [Validation.length],
    ];

    textControllerTeacherColumn1 = [
      [firstName],
      [email],
      [address],
      [dateOfBirth]
    ];
    textControllerTeacherColumn2 = [
      [lastName],
      [phone],
    ];
    textControllerEducationTeacherColumn1 = [
      [university],
      [startDate, endDate],
    ];
    textControllerEducationTeacherColumn2 = [
      [degree],
      [city],
    ];

    box = MyAppServices().box;

    super.onInit();
  }
}
