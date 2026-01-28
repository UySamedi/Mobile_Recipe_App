import 'package:flutter/material.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
          child: Text(
              "search you ",
            style: TextStyle(fontSize: 20, color: Colors.black),

          ),

        ),
    );
  }
}
