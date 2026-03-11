import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';

Widget buildCountryFlag(String countryCode) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: CountryFlag.fromCountryCode(
        shape: RoundedRectangle(3),
        countryCode,
        width: 17,
        height: 12,
      ),
    );