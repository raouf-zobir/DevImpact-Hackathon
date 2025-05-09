import 'package:sama/core/constants/assets.dart';

class ItemCardUserModel {
  final String title;
  final String icon;
  final String body;

  ItemCardUserModel(
      {required this.title, required this.icon, required this.body});
}

List<ItemCardUserModel> itemCardUserModel = [
  ItemCardUserModel(
      title: "Location", icon: Assets.iconsLocation, body: "Rahmania,Algiers"),
  // ItemCardUserModel(title: "Location", icon: Assets.iconsLocation, body: "Damascuse,Arbin"),
  ItemCardUserModel(
      title: "Phone", icon: Assets.iconsCall, body: "+213 555 555 555"),
  ItemCardUserModel(
      title: "Email", icon: Assets.iconsEmail, body: "admin@edu-platform.net"),
];

retListItemCardUserModel({
  String? location,
  String? phone,
  String? email,
}) {
  if (location != null) {
    location =
        location.length > 20 ? "${location.substring(0, 20)}.." : location;
  }
  return [
    if (location != null)
      ItemCardUserModel(
          title: "Location", icon: Assets.iconsLocation, body: location),
    if (phone != null)
      ItemCardUserModel(title: "Phone", icon: Assets.iconsCall, body: phone),
    if (email != null)
      ItemCardUserModel(title: "Email", icon: Assets.iconsEmail, body: email),
  ];
}
