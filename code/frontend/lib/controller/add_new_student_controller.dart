import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sama/controller/finance_controller.dart';
import 'package:sama/controller/navigations_controller.dart';
import 'package:sama/core/constants/app_colors.dart';
import 'package:sama/core/constants/classes.dart';
import 'package:sama/core/enum/enum_pament.dart';
import 'package:sama/core/enum/navigations_enum.dart';
import 'package:sama/core/helper/random_id.dart';
import 'package:sama/core/my_services.dart';
import 'package:sama/core/utils/validation.dart';
import 'package:sama/model/section_model.dart';
import 'package:sama/model/student_model.dart';
import 'dart:io';
import 'package:csv/csv.dart';

abstract class AddNewStudentController extends GetxController {
  selectChoicePayment(PaymentEnum paymentEnum);
}

class AddNewStudentControllerImp extends AddNewStudentController {
  AddNewStudentControllerImp({this.student});

  late Box box;
  late PaymentEnum statePayment;
  String grade = levels[0];
  XFile? image;
  final StudentModel? student;

  GlobalKey<FormState> globalKey = GlobalKey<FormState>();
  late TextEditingController firstName;
  late TextEditingController lastName;
  late TextEditingController dateOfBirth;
  late TextEditingController placeOfBirth;
  late TextEditingController parentName;
  late TextEditingController email;
  late TextEditingController phone;
  late TextEditingController address;
  late TextEditingController parentEmail;
  late TextEditingController parentPhone;
  late TextEditingController parentAddress;

  List<List<TextEditingController>> textControllerStudentColumn1 = [];
  List<List<TextEditingController>> textControllerStudentColumn2 = [];
  List<List<TextEditingController>> textControllerParentStudentColumn1 = [];
  List<List<TextEditingController>> textControllerParentStudentColumn2 = [];
  List<String> titleStudentColumn1 = [];
  List<String> titleStudentColumn2 = [];
  List<String> titleParentStudentColumn1 = [];
  List<String> titleParentStudentColumn2 = [];
  List<List<String>> hintStudentColumn1 = [];
  List<List<String>> hintStudentColumn2 = [];
  List<List<String>> hintParentStudentColumn1 = [];
  List<List<String>> hintParentStudentColumn2 = [];
  List<List<String? Function(String?)?>> validationStudentColumn1 = [];
  List<List<String? Function(String?)?>> validationStudentColumn2 = [];
  List<List<String? Function(String?)?>> validationParentStudentColumn1 = [];
  List<List<String? Function(String?)?>> validationParentStudentColumn2 = [];
  List<SectionModel> sections = [];
  String? activeSection;

  Future<void> saveFileToLocal(XFile file) async {
    file.saveTo(
        "C:/Users/msi/Desktop/Project/Students/StudentsPhoto/${file.name}");
  }

  void pop() {
    Get.find<NavigationControllerImp>()
        .replaceLastWidget(NavigationEnum.Students);
  }

  Future addNewStudent() async {
    if (globalKey.currentState!.validate()) {
      if (activeSection == null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: const Text(
              'Section is required. Please choose one. If no sections are found, create a new section.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.errorRed,
            action: SnackBarAction(
              label: 'Create Section',
              textColor: AppColors.lightPurple,
              onPressed: () {
                Get.find<NavigationControllerImp>()
                    .replaceLastWidget(NavigationEnum.Classes, info: {
                  "isActive":
                      (int.tryParse(grade.substring(grade.length - 2).trim()) ??
                              1) -
                          1
                });
              },
            ),
          ),
        );
      } else {
        StudentModel studentModel = StudentModel(
          id: student?.id ?? generateUniqueNumber(),
          firstName: firstName.text,
          lastName: lastName.text,
          dateOfBirth: dateOfBirth.text,
          placeOfBirth: placeOfBirth.text,
          email: email.text,
          phone: phone.text,
          address: address.text,
          parentName: parentName.text,
          parentAddress: parentAddress.text,
          parentEmail: parentEmail.text,
          parentPhone: parentPhone.text,
          image: image?.path,
          grade: grade,
          section: activeSection!,
          typeapid: statePayment.name,
        );

        // Save to Hive
        if (student != null) {
          final items = box.values.toList();
          for (int i = 0; i < items.length; i++) {
            if (items[i] is StudentModel && items[i].id == student!.id) {
              await box.putAt(i, studentModel);
            }
          }
        } else {
          await box.add(studentModel);
        }

        // Save to CSV
        try {
          // final directory = await getApplicationDocumentsDirectory();
          const filePath =
              'C:/Users/msi/Desktop/Project/Students/students.csv';

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
                "Parent Name",
                "Parent Address",
                "Parent Email",
                "Parent Phone",
                "Image",
                "Grade",
                "Section",
                "Type of Payment"
              ]
            ];
          }

          // Add new student data to CSV
          csvData.add([
            studentModel.id.toString(),
            studentModel.firstName,
            studentModel.lastName,
            studentModel.dateOfBirth,
            studentModel.placeOfBirth,
            studentModel.email,
            studentModel.phone,
            studentModel.address,
            studentModel.parentName,
            studentModel.parentAddress,
            studentModel.parentEmail,
            studentModel.parentPhone,
            studentModel.image ?? "",
            studentModel.grade,
            studentModel.section,
            studentModel.typeapid,
          ]);

          // Convert to CSV string and save
          String csvString = const ListToCsvConverter().convert(csvData);
          await file.writeAsString(csvString);

          debugPrint("Data saved to CSV successfully: $filePath");
        } catch (e) {
          debugPrint("Error saving CSV: $e");
        }

        Get.find<NavigationControllerImp>()
            .replaceLastWidget(NavigationEnum.Students);
      }
    }
    Get.find<FinanceControllerImp>().resetController();
  }

  void pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      image = pickedFile;
      saveFileToLocal(pickedFile);
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
        image = file;
        saveFileToLocal(image!);

        update();
        return;
      }
    }
  }

  void setGrade(String value) {
    grade = value;
    // Extract grade number (1, 2, or 3) from the grade string
    String gradeNumber = value.split(' ')[1];
    
    sections = box.values.whereType<SectionModel>().where((section) {
      // Compare just the grade number part
      return section.grade == "Grade $gradeNumber";
    }).toList();

    if (sections.isNotEmpty) {
      activeSection = sections.last.name;
    } else {
      activeSection = null;
    }
    update();
  }

  setSection(String value) {
    activeSection = value;
    update();
  }

  @override
  void onInit() async {
    statePayment = PaymentEnum.cache;
    initListAndController();
    box = MyAppServices().box;
    if (student == null) {
      setGrade(levels[0]);
    }
    super.onInit();
  }

  void initListAndController() {
    firstName = TextEditingController(text: student?.firstName);
    lastName = TextEditingController(text: student?.lastName);
    dateOfBirth = TextEditingController(text: student?.dateOfBirth);
    placeOfBirth = TextEditingController(text: student?.placeOfBirth);
    parentName = TextEditingController(text: student?.parentName);
    email = TextEditingController(text: student?.email);
    phone = TextEditingController(text: student?.phone);
    address = TextEditingController(text: student?.address);
    parentEmail = TextEditingController(text: student?.parentEmail);
    parentPhone = TextEditingController(text: student?.parentPhone);
    parentAddress = TextEditingController(text: student?.parentAddress);

    image = student?.image != null && student!.image!.isNotEmpty
        ? XFile(student!.image!)
        : null;
    grade = student?.grade ?? grade;
    activeSection = student?.section ?? activeSection;

    if (student != null) {
      if (student!.typeapid == PaymentEnum.cache.name) {
        statePayment = PaymentEnum.cache;
      } else {
        statePayment = PaymentEnum.debit;
      }
    }

    titleStudentColumn1 = [
      "First Name *",
      "Date & Place of Brith*",
      "Email *",
      "Address *"
    ];
    titleStudentColumn2 = ["Last Name *", "Parent Name *", "Phone"];
    titleParentStudentColumn1 = ["First Name *", "Email *", "Address *"];
    titleParentStudentColumn2 = ["Last Name *", "Phone"];

    hintStudentColumn1 = [
      ["First Name"],
      ["ex: 2005-12-02", "ex: Rahmania"],
      ["Email"],
      ["Rue des 1er Novembre, Villa 45 Rahmania, Wilaya of Algiers"]
    ];
    hintStudentColumn2 = [
      ["Last Name"],
      ["Parent Name"],
      ["Phone"],
    ];
    hintParentStudentColumn1 = [
      ["First Name"],
      ["Email"],
      ["Rue des 1er Novembre, Villa 45 Rahmania, Wilaya of Algiers"]
    ];
    hintParentStudentColumn2 = [
      ["Last Name"],
      ["Phone"],
    ];

    validationStudentColumn1 = [
      [Validation.length],
      [Validation.dateFormat, Validation.length],
      [Validation.validateEmail],
      [Validation.length]
    ];
    validationStudentColumn2 = [
      [Validation.length],
      [Validation.length],
      [Validation.isPhoneNumberValid],
      [Validation.length]
    ];
    validationParentStudentColumn1 = [
      [Validation.length],
      [Validation.validateEmail],
      [Validation.length]
    ];
    validationParentStudentColumn2 = [
      [Validation.length],
      [Validation.isPhoneNumberValid],
    ];

    textControllerStudentColumn1 = [
      [firstName],
      [dateOfBirth, placeOfBirth],
      [email],
      [address],
    ];
    textControllerStudentColumn2 = [
      [lastName],
      [parentName],
      [phone],
    ];

    textControllerParentStudentColumn1 = [
      [parentName],
      [parentEmail],
      [parentAddress],
    ];
    textControllerParentStudentColumn2 = [
      [lastName],
      [parentPhone],
    ];
  }

  @override
  void selectChoicePayment(PaymentEnum paymentEnum) {
    statePayment = paymentEnum;
    update();
  }
}
