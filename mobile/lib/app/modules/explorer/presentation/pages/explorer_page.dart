import 'package:flutter/material.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_cubit.dart';
import 'package:lyria/app/modules/explorer/presentation/pages/category_include.dart';
import 'package:lyria/app/modules/explorer/presentation/pages/search_include.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final SearchCubit cubit = getIt<SearchCubit>();

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();
  bool isSearchFocused = false;
  List<Search> searches = [];
  bool isHistory = false;

  @override
  void initState() {
    super.initState();
    searchFocus.addListener(() {
      if (searches.isEmpty) {
        _getHistory();
        setState(() {
          isHistory = true;
        });
      }
      setState(() {
        isSearchFocused = searchFocus.hasFocus;
      });
    });
    searchController.addListener(() {
      if (searchController.text.isEmpty) {
        _getHistory();
      } else {
        _search(searchController.text);
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Future<void> _getHistory() async {
    final history = await cubit.getHistory();
    setState(() {
      searches = history;
      isHistory = true;
    });
  }

  Future<void> _search(String query) async {
    final history = await cubit.search(query);

    setState(() {
      searches = history;
      isHistory = false;
    });
  }

  Future<void> _removeHistory(Search search) async {
    final history = await cubit.removeFromHistory(search);
    setState(() {
      searches = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: TextField(
                controller: searchController,
                focusNode: searchFocus,
                decoration: InputDecoration(
                  hintText: 'Pesquisar',
                  prefixIcon: GestureDetector(
                    onTap: () {
                      if (isSearchFocused) {
                        setState(() {
                          isSearchFocused = false;
                          searchFocus.unfocus();
                        });
                      }
                    },
                    child: Icon(
                      isSearchFocused ? CustomIcons.goback : CustomIcons.search,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 60),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              isSearchFocused ? 'Buscas recentes' : 'Gêneros',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: !isSearchFocused
                  ? CategoryInclude()
                  : SearchInclude(
                      searches: searches,
                      onRemove: (index) => _removeHistory(searches[index]),
                      isHistory: isHistory,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
