import 'package:flutter/material.dart';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// List of colleges you want to display in the horizontal ListView
  final List<String> colleges;

  /// Callback when the search container is tapped
  final VoidCallback onSearchTap;

  const SearchAppBar({
    Key? key,
    required this.colleges,
    required this.onSearchTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      shadowColor: Colors.transparent,
      elevation: 0,
      bottomOpacity: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      // Instead of using `title` as a simple Text or Widget, 
      // we can use a Column or any widget you want.
      title: GestureDetector(
        onTap: onSearchTap,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures column wraps content
          children: [
            // Search Box
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
            ),

            const SizedBox(height: 16),

            // Horizontal List of Colleges
            SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }

  /// Here you specify the total size of your custom AppBar.
  ///
  /// The default `kToolbarHeight` is 56. 
  /// However, we have additional widgets (Column with the search box and the ListView).
  /// You can tweak this value until it fits your needs.
  @override
  Size get preferredSize => const Size.fromHeight(200);
}
