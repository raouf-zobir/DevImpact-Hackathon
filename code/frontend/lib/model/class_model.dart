import 'package:sama/core/constants/assets.dart';

class ClassModel {
  final String grade;
  final String educationLevel;
  final String image;
  final String romanNumerals;

  ClassModel({
    required this.grade,
    required this.educationLevel,
    required this.image,
    required this.romanNumerals,
  });
}

List<ClassModel> classesModel = [
  ClassModel(
      romanNumerals: 'I',
      grade: "Grade 1",
      educationLevel: "Primary School",
      image: Assets.numbers1),
  ClassModel(
      romanNumerals: 'II',
      grade: "Grade 2",
      educationLevel: "Primary School",
      image: Assets.numbers2),
  ClassModel(
      romanNumerals: 'III',
      grade: "Grade 3",
      educationLevel: "Primary School",
      image: Assets.numbers3),
];
