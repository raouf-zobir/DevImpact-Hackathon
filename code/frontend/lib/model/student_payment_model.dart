class StudentPaymentModel {
  final String id;
  final String date;
  final String price;
  final String status;

  StudentPaymentModel(this.id, this.date, this.price, this.status);
}

List<StudentPaymentModel> studentsPaymentModel = [
  StudentPaymentModel(
      "#10125", "2 March 2021, 13:45 PM", r"$ 200,000 DZ", "Complete"),
  StudentPaymentModel(
      "#10138", "15 March 2022, 11:05 PM", r"$ 200,000 DZ", "   Pending "),
  StudentPaymentModel(
      "#10142", "01 Avril 2022, 12:37 PM", r"$ 200,000 DZ", "Canceled"),
  StudentPaymentModel(
      "#10180", "01 Avril 2022, 14:25 PM", r"$ 200,000 DZ", "Complete"),
];
