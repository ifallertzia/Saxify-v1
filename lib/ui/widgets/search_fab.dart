import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell/shell_controller.dart';

/// Search stays one tap away on every new screen.
class SaxifySearchButton extends StatelessWidget {
  const SaxifySearchButton({super.key, this.popFirst = true});

  final bool popFirst;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Search',
      icon: const Icon(Icons.search_rounded),
      onPressed: () {
        context.read<ShellController>().goSearch();
        if (popFirst) Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      },
    );
  }
}
