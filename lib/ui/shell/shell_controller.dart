import 'package:flutter/material.dart';

/// Bottom-nav tab indices.
enum SaxifyTab { home, search, library, downloader, settings }

/// Coordinates the shell: which tab is showing and what the search box should
/// run. Mood chips on Home, "Show all" links and deep links all go through here
/// so the app behaves like the site's router.
class ShellController extends ChangeNotifier {
  SaxifyTab _tab = SaxifyTab.home;
  String? _pendingQuery;
  int _queryNonce = 0;

  SaxifyTab get tab => _tab;

  /// Non-null when something asked the Search tab to run a query.
  String? get pendingQuery => _pendingQuery;
  int get queryNonce => _queryNonce;

  void select(SaxifyTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void goSearch([String? query]) {
    _tab = SaxifyTab.search;
    _pendingQuery = query;
    _queryNonce++;
    notifyListeners();
  }

  void goHome() {
    _tab = SaxifyTab.home;
    notifyListeners();
  }

  void goLibrary() {
    _tab = SaxifyTab.library;
    notifyListeners();
  }

  void goDownloader() {
    _tab = SaxifyTab.downloader;
    notifyListeners();
  }

  void goSettings() {
    _tab = SaxifyTab.settings;
    notifyListeners();
  }

  void clearPendingQuery() {
    if (_pendingQuery == null) return;
    _pendingQuery = null;
    notifyListeners();
  }
}
