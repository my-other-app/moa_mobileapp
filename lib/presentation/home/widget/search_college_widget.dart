import 'package:flutter/material.dart';

class SearchAndCollegeList extends StatelessWidget {
  final List<String> colleges;

  const SearchAndCollegeList({
    Key? key,
    required this.colleges,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchBox(),
        const SizedBox(height: 16),
        _buildCollegesList(),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1E1E)),
      ),
      child: Row(
        children: const [
          Icon(Icons.search, color: Color(0xFF979797)),
          SizedBox(width: 8),
          Text(
            "Search for clubs or interests",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCollegesList() {
    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: colleges.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFAFAFAF)),
              ),
              child: Center(
                child: Text(
                  colleges[index],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFAFAFAF),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
