import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const QuranApp());
}

class QuranApp extends StatefulWidget {
  const QuranApp({Key? key}) : super(key: key);

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _saveThemePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
      _saveThemePreference(isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'আল কুরআন বাংলা - পবিত্র কুরআন শরীফ বাংলা অনুবাদ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1F6E43),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6E43),
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFF1F6E43),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: GoogleFonts.hindSiliguri(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          displayMedium: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          displaySmall: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          headlineMedium: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          headlineSmall: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          titleLarge: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          bodyLarge: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          bodyMedium: GoogleFonts.hindSiliguri(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
      home: SplashScreen(toggleTheme: toggleTheme, isDarkMode: isDarkMode),
      routes: {
        '/home': (context) => HomePage(toggleTheme: toggleTheme, isDarkMode: isDarkMode),
        '/about': (context) => AboutPage(isDarkMode: isDarkMode),
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/surah/') ?? false) {
          final surahNumber = int.tryParse(settings.name!.split('/').last);
          if (surahNumber != null) {
            return MaterialPageRoute(
              builder: (context) => SurahDetailPageWrapper(
                surahNumber: surahNumber,
                isDarkMode: isDarkMode,
                toggleTheme: toggleTheme,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}

class SurahDetailPageWrapper extends StatefulWidget {
  final int surahNumber;
  final bool isDarkMode;
  final Function toggleTheme;

  const SurahDetailPageWrapper({
    Key? key,
    required this.surahNumber,
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  @override
  State<SurahDetailPageWrapper> createState() => _SurahDetailPageWrapperState();
}

class _SurahDetailPageWrapperState extends State<SurahDetailPageWrapper> {
  String surahName = '';
  String arabicName = '';
  bool isBookmarked = false;
  List<dynamic> bookmarkedSurahs = [];

  @override
  void initState() {
    super.initState();
    _fetchSurahInfo();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bookmarkedSurahs = (prefs.getStringList('bookmarks') ?? []).map(int.parse).toList();
      isBookmarked = bookmarkedSurahs.contains(widget.surahNumber);
    });
  }

  Future<void> _fetchSurahInfo() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          surahName = data['data']['englishName'];
          arabicName = data['data']['name'];
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (isBookmarked) {
        bookmarkedSurahs.remove(widget.surahNumber);
      } else {
        bookmarkedSurahs.add(widget.surahNumber);
      }
      isBookmarked = !isBookmarked;
      prefs.setStringList(
        'bookmarks',
        bookmarkedSurahs.map((e) => e.toString()).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return surahName.isEmpty
        ? Scaffold(
            appBar: AppBar(
              title: Text(
                'সূরা ${widget.surahNumber}',
                style: GoogleFonts.hindSiliguri(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1F6E43),
              ),
            ),
          )
        : SurahDetailPage(
            surahNumber: widget.surahNumber,
            surahName: surahName,
            arabicName: arabicName,
            isDarkMode: widget.isDarkMode,
            toggleBookmark: toggleBookmark,
            isBookmarked: isBookmarked,
          );
  }
}

class SplashScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const SplashScreen({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomePage(
            toggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1F6E43),
              const Color(0xFF1F6E43).withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _animation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 60,
                    color: Color(0xFF1F6E43),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _animation,
                child: Text(
                  'আল কুরআন বাংলা',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _animation,
                child: Text(
                  'পবিত্র কুরআন শরীফ বাংলা অনুবাদ',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const HomePage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> surahs = [];
  List<dynamic> filteredSurahs = [];
  bool isLoading = true;
  String error = '';
  List<int> bookmarkedSurahs = [];
  TextEditingController searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    fetchSurahs();
    loadBookmarks();
    _initSEO();
  }

  void _initSEO() {
    if (kIsWeb) {
      // Set meta tags for SEO
      _setMetaTags();
    }
  }

  void _setMetaTags() {
    // This would be implemented in a real web app
    // For Flutter web, you would typically use a package like flutter_web_plugins
    // or modify the index.html file directly
    // Here's a conceptual example:
    /*
    document.querySelector('title')?.text = 'আল কুরআন বাংলা - পবিত্র কুরআন শরীফ বাংলা অনুবাদ';
    
    // Add meta description
    var metaDescription = document.createElement('meta');
    metaDescription.setAttribute('name', 'description');
    metaDescription.setAttribute('content', 'পবিত্র কুরআন শরীফের বাংলা অনুবাদ সহ একটি সহজ অ্যাপ্লিকেশন। সম্পূর্ণ কুরআন শরীফ বাংলা অনুবাদ এবং আরবি টেক্সট সহ।');
    document.head?.appendChild(metaDescription);
    
    // Add meta keywords
    var metaKeywords = document.createElement('meta');
    metaKeywords.setAttribute('name', 'keywords');
    metaKeywords.setAttribute('content', 'কুরআন, বাংলা কুরআন, আল কুরআন, কুরআন শরীফ, বাংলা অনুবাদ, ইসলাম, quran, bangla quran');
    document.head?.appendChild(metaKeywords);
    
    // Add canonical URL
    var canonicalLink = document.createElement('link');
    canonicalLink.setAttribute('rel', 'canonical');
    canonicalLink.setAttribute('href', 'https://alquranbn.web.app/');
    document.head?.appendChild(canonicalLink);
    
    // Add Open Graph tags for social sharing
    var ogTitle = document.createElement('meta');
    ogTitle.setAttribute('property', 'og:title');
    ogTitle.setAttribute('content', 'আল কুরআন বাংলা - পবিত্র কুরআন শরীফ বাংলা অনুবাদ');
    document.head?.appendChild(ogTitle);
    
    var ogDescription = document.createElement('meta');
    ogDescription.setAttribute('property', 'og:description');
    ogDescription.setAttribute('content', 'পবিত্র কুরআন শরীফের বাংলা অনুবাদ সহ একটি সহজ অ্যাপ্লিকেশন।');
    document.head?.appendChild(ogDescription);
    
    var ogImage = document.createElement('meta');
    ogImage.setAttribute('property', 'og:image');
    ogImage.setAttribute('content', 'https://alquranbn.web.app/quran-app-preview.jpg');
    document.head?.appendChild(ogImage);
    
    // Add structured data for rich results
    var structuredData = document.createElement('script');
    structuredData.setAttribute('type', 'application/ld+json');
    structuredData.textContent = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'MobileApplication',
      'name': 'আল কুরআন বাংলা',
      'description': 'পবিত্র কুরআন শরীফের বাংলা অনুবাদ সহ একটি সহজ অ্যাপ্লিকেশন।',
      'operatingSystem': 'Android, iOS',
      'applicationCategory': 'ReligiousApp',
      'offers': {
        '@type': 'Offer',
        'price': '0',
        'priceCurrency': 'USD'
      }
    });
    document.head?.appendChild(structuredData);
    */
  }

  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bookmarkedSurahs = prefs.getStringList('bookmarks')?.map(int.parse).toList() ?? [];
    });
  }

  Future<void> saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks',
      bookmarkedSurahs.map((e) => e.toString()).toList(),
    );
  }

  void toggleBookmark(int surahNumber) {
    setState(() {
      if (bookmarkedSurahs.contains(surahNumber)) {
        bookmarkedSurahs.remove(surahNumber);
      } else {
        bookmarkedSurahs.add(surahNumber);
      }
      saveBookmarks();
    });
  }

  Future<void> fetchSurahs() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          surahs = data['data'];
          filteredSurahs = surahs;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'সূরা লোড করতে সমস্যা হয়েছে';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'ইন্টারনেট সংযোগ চেক করুন';
        isLoading = false;
      });
    }
  }

  void filterSurahs(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredSurahs = surahs;
      } else {
        filteredSurahs = surahs.where((surah) {
          return surah['englishName'].toString().toLowerCase().contains(query.toLowerCase()) ||
              surah['number'].toString().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          'আল কুরআন বাংলা',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.toggleTheme(),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF1F6E43),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 40,
                        color: Color(0xFF1F6E43),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'আল কুরআন বাংলা',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'পবিত্র কুরআন শরীফ',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: Text(
                  'হোম',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(
                  'বুকমার্কস',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookmarksPage(
                        surahs: surahs,
                        bookmarkedSurahs: bookmarkedSurahs,
                        isDarkMode: widget.isDarkMode,
                        toggleBookmark: toggleBookmark,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.headphones),
                title: Text(
                  'অডিও সেটিংস',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AudioSettingsPage(
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(
                  'অডিও ডাউনলোড',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AudioDownloadPage(
                        isDarkMode: widget.isDarkMode,
                        surahs: surahs,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: Text(
                  'তাফসীর',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TafsirListPage(
                        isDarkMode: widget.isDarkMode,
                        surahs: surahs,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(
                  'অ্যাপ সম্পর্কে',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AboutPage(
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                title: Text(
                  widget.isDarkMode ? 'লাইট মোড' : 'ডার্ক মোড',
                  style: GoogleFonts.hindSiliguri(),
                ),
                onTap: () {
                  widget.toggleTheme();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: filterSurahs,
              style: GoogleFonts.hindSiliguri(),
              decoration: InputDecoration(
                hintText: 'সূরা খুঁজুন...',
                hintStyle: GoogleFonts.hindSiliguri(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1F6E43),
                    ),
                  )
                : error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error,
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 16,
                                color: Colors.red.shade300,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                  error = '';
                                });
                                fetchSurahs();
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                'আবার চেষ্টা করুন',
                                style: GoogleFonts.hindSiliguri(),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredSurahs.isEmpty
                        ? Center(
                            child: Text(
                              'কোন সূরা পাওয়া যায়নি',
                              style: GoogleFonts.hindSiliguri(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredSurahs.length,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemBuilder: (context, index) {
                              final surah = filteredSurahs[index];
                              final isBookmarked = bookmarkedSurahs.contains(surah['number']);
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      if (kIsWeb) {
                                        Navigator.pushNamed(
                                          context,
                                          '/surah/${surah['number']}',
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SurahDetailPage(
                                              surahNumber: surah['number'],
                                              surahName: surah['englishName'],
                                              arabicName: surah['name'],
                                              isDarkMode: widget.isDarkMode,
                                              toggleBookmark: () => toggleBookmark(surah['number']),
                                              isBookmarked: isBookmarked,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1F6E43).withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${surah['number']}',
                                                style: GoogleFonts.roboto(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${surah['englishName']}',
                                                  style: GoogleFonts.roboto(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'আয়াত: ${surah['numberOfAyahs']}',
                                                  style: GoogleFonts.hindSiliguri(
                                                    fontSize: 14,
                                                    color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                                  color: isBookmarked ? const Color(0xFF1F6E43) : null,
                                                ),
                                                onPressed: () => toggleBookmark(surah['number']),
                                              ),
                                              Text(
                                                '${surah['name']}',
                                                style: const TextStyle(
                                                  fontFamily: 'Amiri',
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class BookmarksPage extends StatelessWidget {
  final List<dynamic> surahs;
  final List<int> bookmarkedSurahs;
  final bool isDarkMode;
  final Function(int) toggleBookmark;

  const BookmarksPage({
    Key? key,
    required this.surahs,
    required this.bookmarkedSurahs,
    required this.isDarkMode,
    required this.toggleBookmark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bookmarkedSurahsList = surahs.where((surah) => bookmarkedSurahs.contains(surah['number'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'বুকমার্কস',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: bookmarkedSurahsList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'কোন বুকমার্ক নেই',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'সূরা পাতায় বুকমার্ক আইকন ক্লিক করে বুকমার্ক করুন',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: bookmarkedSurahsList.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final surah = bookmarkedSurahsList[index];
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SurahDetailPage(
                            surahNumber: surah['number'],
                            surahName: surah['englishName'],
                            arabicName: surah['name'],
                            isDarkMode: isDarkMode,
                            toggleBookmark: () => toggleBookmark(surah['number']),
                            isBookmarked: true,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F6E43),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                '${surah['number']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${surah['englishName']}',
                                  style: GoogleFonts.roboto(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'আয়াত: ${surah['numberOfAyahs']}',
                                  style: GoogleFonts.hindSiliguri(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.bookmark,
                                  color: Color(0xFF1F6E43),
                                ),
                                onPressed: () => toggleBookmark(surah['number']),
                              ),
                              Text(
                                '${surah['name']}',
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AudioSettingsPage extends StatefulWidget {
  final bool isDarkMode;

  const AudioSettingsPage({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage> {
  String selectedReciter = 'ar.alafasy';
  double playbackSpeed = 1.0;
  bool autoPlayNext = true;
  bool downloadAudioWhenOnWifi = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedReciter = prefs.getString('selectedReciter') ?? 'ar.alafasy';
      playbackSpeed = prefs.getDouble('playbackSpeed') ?? 1.0;
      autoPlayNext = prefs.getBool('autoPlayNext') ?? true;
      downloadAudioWhenOnWifi = prefs.getBool('downloadAudioWhenOnWifi') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedReciter', selectedReciter);
    await prefs.setDouble('playbackSpeed', playbackSpeed);
    await prefs.setBool('autoPlayNext', autoPlayNext);
    await prefs.setBool('downloadAudioWhenOnWifi', downloadAudioWhenOnWifi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'অডিও সেটিংস',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ক্বারী নির্বাচন করুন',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReciter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'ar.alafasy',
                        child: Text(
                          'মিশারী রাশিদ আল-আফাসী',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ar.abdurrahmaansudais',
                        child: Text(
                          'আব্দুর রহমান আস-সুদাইস',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ar.abdulbasitmurattal',
                        child: Text(
                          'আব্দুল বাসিত আব্দুস সামাদ',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ar.mahermuaiqly',
                        child: Text(
                          'মাহের আল মুয়াইকলী',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedReciter = value;
                        });
                        _saveSettings();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'প্লেব্যাক স্পিড',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'অডিও প্লেব্যাক স্পিড সমন্বয় করুন',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0.5x',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '1.0x',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '2.0x',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 3,
                    label: '${playbackSpeed}x',
                    onChanged: (value) {
                      setState(() {
                        playbackSpeed = value;
                      });
                    },
                    onChangeEnd: (value) {
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'অডিও সেটিংস',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'স্বয়ংক্রিয়ভাবে পরবর্তী আয়াত প্লে করুন',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    value: autoPlayNext,
                    onChanged: (value) {
                      setState(() {
                        autoPlayNext = value;
                      });
                      _saveSettings();
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(
                      'ওয়াইফাই থাকলে অডিও ডাউনলোড করুন',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    value: downloadAudioWhenOnWifi,
                    onChanged: (value) {
                      setState(() {
                        downloadAudioWhenOnWifi = value;
                      });
                      _saveSettings();
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AudioCacheClearPage(
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'অডিও ক্যাশে পরিচালনা করুন',
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioCacheClearPage extends StatefulWidget {
  final bool isDarkMode;

  const AudioCacheClearPage({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<AudioCacheClearPage> createState() => _AudioCacheClearPageState();
}

class _AudioCacheClearPageState extends State<AudioCacheClearPage> {
  int cacheSize = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final audioDir = Directory('${dir.path}/audio_cache');
        
        if (await audioDir.exists()) {
          int size = 0;
          await for (final file in audioDir.list(recursive: true, followLinks: false)) {
            if (file is File) {
              size += await file.length();
            }
          }
          
          setState(() {
            cacheSize = size;
            isLoading = false;
          });
        } else {
          setState(() {
            cacheSize = 0;
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    if (!kIsWeb) {
      setState(() {
        isLoading = true;
      });
      
      try {
        final dir = await getApplicationDocumentsDirectory();
        final audioDir = Directory('${dir.path}/audio_cache');
        
        if (await audioDir.exists()) {
          await audioDir.delete(recursive: true);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'অডিও ক্যাশে সাফ করা হয়েছে',
              style: GoogleFonts.hindSiliguri(),
            ),
            backgroundColor: const Color(0xFF1F6E43),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ক্যাশে সাফ করতে সমস্যা হয়েছে',
              style: GoogleFonts.hindSiliguri(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _calculateCacheSize();
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'অডিও ক্যাশে',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'অডিও ক্যাশে সাইজ',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1F6E43),
                            ),
                          )
                        : kIsWeb
                            ? Center(
                                child: Text(
                                  'ওয়েব ভার্সনে ক্যাশে পরিচালনা উপলব্ধ নয়',
                                  style: GoogleFonts.hindSiliguri(),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'বর্তমান ক্যাশে সাইজ:',
                                    style: GoogleFonts.hindSiliguri(
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _formatBytes(cacheSize),
                                    style: GoogleFonts.roboto(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: cacheSize > 0 ? _clearCache : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.red.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'অডিও ক্যাশে সাফ করুন',
                            style: GoogleFonts.hindSiliguri(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ক্যাশে সম্পর্কে',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'অডিও ক্যাশে আপনার ডিভাইসে সংরক্ষিত অডিও ফাইলগুলি। এটি আপনার ইন্টারনেট ব্যবহার কমাতে এবং দ্রুত প্লেব্যাক নিশ্চিত করতে সাহায্য করে।',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ক্যাশে সাফ করলে সমস্ত ডাউনলোড করা অডিও ফাইল মুছে যাবে এবং পরবর্তীতে শোনার জন্য পুনরায় ডাউনলোড করতে হবে।',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioDownloadPage extends StatefulWidget {
  final bool isDarkMode;
  final List<dynamic> surahs;

  const AudioDownloadPage({
    Key? key,
    required this.isDarkMode,
    required this.surahs,
  }) : super(key: key);

  @override
  State<AudioDownloadPage> createState() => _AudioDownloadPageState();
}

class _AudioDownloadPageState extends State<AudioDownloadPage> {
  String selectedReciter = 'ar.alafasy';
  List<int> downloadedSurahs = [];
  List<int> downloadingSurahs = [];
  bool isLoading = true;
  final Dio dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkDownloadedSurahs();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedReciter = prefs.getString('selectedReciter') ?? 'ar.alafasy';
    });
  }

  Future<void> _checkDownloadedSurahs() async {
    if (kIsWeb) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio_cache/$selectedReciter');
      
      if (await audioDir.exists()) {
        List<int> downloaded = [];
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            final fileName = entity.path.split('/').last;
            final surahMatch = RegExp(r'(\d+)\.mp3').firstMatch(fileName);
            if (surahMatch != null) {
              final surahNumber = int.parse(surahMatch.group(1)!);
              downloaded.add(surahNumber);
            }
          }
        }
        
        setState(() {
          downloadedSurahs = downloaded;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _downloadSurah(int surahNumber) async {
    if (kIsWeb) return;
    
    setState(() {
      downloadingSurahs.add(surahNumber);
    });
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio_cache/$selectedReciter');
      
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      
      final filePath = '${audioDir.path}/$surahNumber.mp3';
      // Using Everyayah.com API instead of QuranicAudio
      final url = 'https://everyayah.com/data/$selectedReciter/${surahNumber.toString().padLeft(3, '0')}_001.mp3';
      
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          // Progress tracking could be implemented here
        },
      );
      
      setState(() {
        downloadedSurahs.add(surahNumber);
        downloadingSurahs.remove(surahNumber);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'সূরা ডাউনলোড সম্পন্ন হয়েছে',
            style: GoogleFonts.hindSiliguri(),
          ),
          backgroundColor: const Color(0xFF1F6E43),
        ),
      );
    } catch (e) {
      setState(() {
        downloadingSurahs.remove(surahNumber);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ডাউনলোড করতে সমস্যা হয়েছে',
            style: GoogleFonts.hindSiliguri(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSurah(int surahNumber) async {
    if (kIsWeb) return;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/audio_cache/$selectedReciter/$surahNumber.mp3';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        
        setState(() {
          downloadedSurahs.remove(surahNumber);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'সূরা মুছে ফেলা হয়েছে',
              style: GoogleFonts.hindSiliguri(),
            ),
            backgroundColor: const Color(0xFF1F6E43),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'সূরা মুছতে সমস্যা হয়েছে',
            style: GoogleFonts.hindSiliguri(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'অডিও ডাউনলোড',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ক্বারী নির্বাচন করুন',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReciter,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ar.alafasy',
                          child: Text(
                            'মিশারী রাশিদ আল-আফাসী',
                            style: GoogleFonts.hindSiliguri(),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ar.abdurrahmaansudais',
                          child: Text(
                            'আব্দুর রহমান আস-সুদাইস',
                            style: GoogleFonts.hindSiliguri(),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ar.abdulbasitmurattal',
                          child: Text(
                            'আব্দুল বাসিত আব্দুস সামাদ',
                            style: GoogleFonts.hindSiliguri(),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ar.mahermuaiqly',
                          child: Text(
                            'মাহের আল মুয়াইকলী',
                            style: GoogleFonts.hindSiliguri(),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedReciter = value;
                            isLoading = true;
                            downloadedSurahs = [];
                          });
                          _checkDownloadedSurahs();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1F6E43),
                    ),
                  )
                : kIsWeb
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_download,
                              size: 64,
                              color: widget.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ওয়েব ভার্সনে অডিও ডাউনলোড উপলব্ধ নয়',
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 18,
                                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.surahs.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final surah = widget.surahs[index];
                          final surahNumber = surah['number'];
                          final isDownloaded = downloadedSurahs.contains(surahNumber);
                          final isDownloading = downloadingSurahs.contains(surahNumber);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F6E43),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    '$surahNumber',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                '${surah['englishName']}',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'আয়াত: ${surah['numberOfAyahs']}',
                                style: GoogleFonts.hindSiliguri(),
                              ),
                              trailing: isDownloading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1F6E43),
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        isDownloaded ? Icons.delete : Icons.download,
                                        color: isDownloaded ? Colors.red : const Color(0xFF1F6E43),
                                      ),
                                      onPressed: () {
                                        if (isDownloaded) {
                                          _deleteSurah(surahNumber);
                                        } else {
                                          _downloadSurah(surahNumber);
                                        }
                                      },
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class TafsirListPage extends StatefulWidget {
  final bool isDarkMode;
  final List<dynamic> surahs;

  const TafsirListPage({
    Key? key,
    required this.isDarkMode,
    required this.surahs,
  }) : super(key: key);

  @override
  State<TafsirListPage> createState() => _TafsirListPageState();
}

class _TafsirListPageState extends State<TafsirListPage> {
  List<dynamic> filteredSurahs = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredSurahs = widget.surahs;
  }

  void filterSurahs(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredSurahs = widget.surahs;
      } else {
        filteredSurahs = widget.surahs.where((surah) {
          return surah['englishName'].toString().toLowerCase().contains(query.toLowerCase()) ||
              surah['number'].toString().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'তাফসীর',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: filterSurahs,
              style: GoogleFonts.hindSiliguri(),
              decoration: InputDecoration(
                hintText: 'সূরা খুঁজুন...',
                hintStyle: GoogleFonts.hindSiliguri(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: filteredSurahs.isEmpty
                ? Center(
                    child: Text(
                      'কোন সূরা পাওয়া যায়নি',
                      style: GoogleFonts.hindSiliguri(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSurahs.length,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final surah = filteredSurahs[index];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TafsirDetailPage(
                                    surahNumber: surah['number'],
                                    surahName: surah['englishName'],
                                    arabicName: surah['name'],
                                    isDarkMode: widget.isDarkMode,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F6E43).withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${surah['number']}',
                                        style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${surah['englishName']}',
                                          style: GoogleFonts.roboto(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'আয়াত: ${surah['numberOfAyahs']}',
                                          style: GoogleFonts.hindSiliguri(
                                            fontSize: 14,
                                            color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${surah['name']}',
                                    style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TafsirDetailPage extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final String arabicName;
  final bool isDarkMode;

  const TafsirDetailPage({
    Key? key,
    required this.surahNumber,
    required this.surahName,
    required this.arabicName,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<TafsirDetailPage> createState() => _TafsirDetailPageState();
}

class _TafsirDetailPageState extends State<TafsirDetailPage> {
  List<dynamic> ayahs = [];
  List<dynamic> banglaAyahs = [];
  List<dynamic> tafsirs = [];
  bool isLoading = true;
  String error = '';
  double fontSize = 18.0;
  ScrollController scrollController = ScrollController();
  String selectedTafsir = 'bn.bengali-tafsir';

  @override
  void initState() {
    super.initState();
    fetchSurahDetails();
    
    if (kIsWeb) {
      _initSEO();
    }
  }

  void _initSEO() {
    // This would be implemented in a real web app
    // For Flutter web, you would typically use a package like flutter_web_plugins
    // or modify the index.html file directly
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchSurahDetails() async {
    try {
      // Fetch Arabic text
      final arabicResponse = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}'),
      );

      // Fetch Bangla translation
      final banglaResponse = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}/bn.bengali'),
      );

      // Fetch Tafsir
      final tafsirResponse = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}/$selectedTafsir'),
      );

      if (arabicResponse.statusCode == 200 && banglaResponse.statusCode == 200 && tafsirResponse.statusCode == 200) {
        final arabicData = json.decode(arabicResponse.body);
        final banglaData = json.decode(banglaResponse.body);
        final tafsirData = json.decode(tafsirResponse.body);

        setState(() {
          ayahs = arabicData['data']['ayahs'];
          banglaAyahs = banglaData['data']['ayahs'];
          tafsirs = tafsirData['data']['ayahs'];
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'সূরার বিস্তারিত লোড করতে সমস্যা হয়েছে';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'ইন্টারনেট সংযোগ চেক করুন';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'তাফসীর: ${widget.surahName}',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.text_decrease),
                    const SizedBox(width: 8),
                    Text(
                      'ফন্ট সাইজ কমান',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    fontSize = max(14.0, fontSize - 2.0);
                  });
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.text_increase),
                    const SizedBox(width: 8),
                    Text(
                      'ফন্ট সাইজ বাড়ান',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    fontSize = min(30.0, fontSize + 2.0);
                  });
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.vertical_align_top),
                    const SizedBox(width: 8),
                    Text(
                      'শুরুতে যান',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF1F6E43),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'তাফসীর লোড হচ্ছে...',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                ],
              ),
            )
          : error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 16,
                          color: Colors.red.shade300,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            error = '';
                          });
                          fetchSurahDetails();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'আবার চেষ্টা করুন',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: ayahs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final ayah = ayahs[index];
                    final banglaAyah = banglaAyahs[index];
                    final tafsir = tafsirs[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F6E43),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${ayah['numberInSurah']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.share_outlined,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    // Share functionality would go here
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ayah['text'],
                                style: GoogleFonts.scheherazadeNew(
                                  fontSize: fontSize + 4,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                banglaAyah['text'],
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: fontSize,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'তাফসীর:',
                              style: GoogleFonts.hindSiliguri(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F6E43),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1F6E43).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                tafsir['text'],
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: fontSize - 1,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AboutPage extends StatelessWidget {
  final bool isDarkMode;

  const AboutPage({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'অ্যাপ সম্পর্কে',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF1F6E43),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'আল কুরআন বাংলা',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ভার্সন 1.0.0',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'পবিত্র কুরআন শরীফের বাংলা অনুবাদ সহ একটি সহজ অ্যাপ্লিকেশন।',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'বৈশিষ্ট্য',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FeatureItem(
                    icon: Icons.translate,
                    title: 'বাংলা অনুবাদ',
                    description: 'পবিত্র কুরআন শরীফের বাংলা অনুবাদ সহ আরবি টেক্সট',
                    isDarkMode: isDarkMode,
                  ),
                  FeatureItem(
                    icon: Icons.headphones,
                    title: 'অডিও তিলাওয়াত',
                    description: 'বিভিন্ন ক্বারীর তিলাওয়াত শুনুন এবং ডাউনলোড করুন',
                    isDarkMode: isDarkMode,
                  ),
                  FeatureItem(
                    icon: Icons.book,
                    title: 'তাফসীর',
                    description: 'আয়াতের বিস্তারিত ব্যাখ্যা পড়ুন',
                    isDarkMode: isDarkMode,
                  ),
                  FeatureItem(
                    icon: Icons.bookmark,
                    title: 'বুকমার্ক',
                    description: 'সূরা এবং আয়াত বুকমার্ক করুন',
                    isDarkMode: isDarkMode,
                  ),
                  FeatureItem(
                    icon: Icons.search,
                    title: 'সার্চ',
                    description: 'সূরা খুঁজুন',
                    isDarkMode: isDarkMode,
                  ),
                  FeatureItem(
                    icon: Icons.dark_mode,
                    title: 'ডার্ক মোড',
                    description: 'আরামদায়ক পাঠের জন্য ডার্ক মোড',
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ডেটা সোর্স',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'এই অ্যাপটি নিম্নলিখিত উৎস থেকে ডেটা ব্যবহার করে:',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• কুরআন টেক্সট এবং অনুবাদ: Alquran Cloud API',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '• অডিও তিলাওয়াত: EveryAyah.com',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '• তাফসীর: Alquran Cloud API',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'যোগাযোগ',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _launchURL('https://t.me/drkingbd'),
                    child: Row(
                      children: [
                        Icon(
                          Icons.telegram,
                          color: const Color(0xFF0088cc),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'টেলিগ্রাম চ্যানেল',
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              't.me/drkingbd',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'আমাদের টেলিগ্রাম চ্যানেলে যোগ দিন এবং নতুন আপডেট সম্পর্কে জানুন।',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} আল কুরআন বাংলা',
            style: GoogleFonts.hindSiliguri(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDarkMode;

  const FeatureItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1F6E43).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1F6E43),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SurahDetailPage extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final String arabicName;
  final bool isDarkMode;
  final VoidCallback toggleBookmark;
  final bool isBookmarked;

  const SurahDetailPage({
    Key? key,
    required this.surahNumber,
    required this.surahName,
    required this.arabicName,
    required this.isDarkMode,
    required this.toggleBookmark,
    required this.isBookmarked,
  }) : super(key: key);

  @override
  State<SurahDetailPage> createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends State<SurahDetailPage> {
  List<dynamic> ayahs = [];
  List<dynamic> banglaAyahs = [];
  bool isLoading = true;
  String error = '';
  double fontSize = 18.0;
  ScrollController scrollController = ScrollController();
  List<int> bookmarkedAyahs = [];
  
  // Audio player
  final AudioPlayer audioPlayer = AudioPlayer();
  int? currentPlayingAyah;
  bool isAudioLoading = false;
  bool isPlaying = false;
  Duration? duration;
  Duration position = Duration.zero;
  String selectedReciter = 'ar.alafasy';
  bool autoPlayNext = true;
  bool isAudioAvailable = false;
  String audioError = '';
  bool isDownloadedAudio = false;

  @override
  void initState() {
    super.initState();
    fetchSurahDetails();
    loadAyahBookmarks();
    _loadAudioSettings();
    _setupAudioPlayer();
    _checkAudioAvailability();
    
    if (kIsWeb) {
      _initSEO();
    }
  }

  void _initSEO() {
    // This would be implemented in a real web app
    // For Flutter web, you would typically use a package like flutter_web_plugins
    // or modify the index.html file directly
  }

  Future<void> _loadAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedReciter = prefs.getString('selectedReciter') ?? 'ar.alafasy';
      autoPlayNext = prefs.getBool('autoPlayNext') ?? true;
    });
  }

  Future<void> _checkAudioAvailability() async {
    if (kIsWeb) {
      setState(() {
        isAudioAvailable = true;
      });
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioFile = File('${dir.path}/audio_cache/$selectedReciter/${widget.surahNumber}.mp3');
      
      if (await audioFile.exists()) {
        setState(() {
          isAudioAvailable = true;
          isDownloadedAudio = true;
        });
      } else {
        // Check if online audio is available
        try {
          // Using EveryAyah.com API instead of QuranicAudio
          final url = 'https://everyayah.com/data/$selectedReciter/${widget.surahNumber.toString().padLeft(3, '0')}_001.mp3';
          final response = await http.head(Uri.parse(url));
          
          if (response.statusCode == 200) {
            setState(() {
              isAudioAvailable = true;
              isDownloadedAudio = false;
            });
          } else {
            setState(() {
              isAudioAvailable = false;
              audioError = 'অডিও ফাইল পাওয়া যায়নি';
            });
          }
        } catch (e) {
          setState(() {
            isAudioAvailable = false;
            audioError = 'ইন্টারনেট সংযোগ চেক করুন';
          });
        }
      }
    } catch (e) {
      setState(() {
        isAudioAvailable = false;
        audioError = 'অডিও চেক করতে সমস্যা হয়েছে';
      });
    }
  }

  void _setupAudioPlayer() {
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          isPlaying = false;
          position = Duration.zero;
        });
        
        if (autoPlayNext && currentPlayingAyah != null && currentPlayingAyah! < ayahs.length) {
          _playNextAyah();
        }
      }
    });
    
    audioPlayer.positionStream.listen((pos) {
      setState(() {
        position = pos;
      });
    });
    
    audioPlayer.durationStream.listen((dur) {
      setState(() {
        duration = dur;
      });
    });
  }

  Future<void> _playAyah(int ayahNumber) async {
    if (currentPlayingAyah == ayahNumber && isPlaying) {
      await audioPlayer.pause();
      setState(() {
        isPlaying = false;
      });
      return;
    }
    
    setState(() {
      isAudioLoading = true;
      currentPlayingAyah = ayahNumber;
    });
    
    try {
      String url;
      
      if (isDownloadedAudio) {
        final dir = await getApplicationDocumentsDirectory();
        final audioFile = File('${dir.path}/audio_cache/$selectedReciter/${widget.surahNumber}.mp3');
        url = audioFile.path;
      } else {
        // Using EveryAyah.com API
        url = 'https://everyayah.com/data/$selectedReciter/${widget.surahNumber.toString().padLeft(3, '0')}_${ayahNumber.toString().padLeft(3, '0')}.mp3';
      }
      
      await audioPlayer.setUrl(url);
      await audioPlayer.play();
      
      setState(() {
        isPlaying = true;
        isAudioLoading = false;
      });
    } catch (e) {
      setState(() {
        isAudioLoading = false;
        audioError = 'অডিও প্লে করতে সমস্যা হয়েছে';
      });
    }
  }

  void _playNextAyah() {
    if (currentPlayingAyah != null && currentPlayingAyah! < ayahs.length - 1) {
      _playAyah(currentPlayingAyah! + 1);
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadAyahBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bookmarkedAyahs = prefs.getStringList('ayahBookmarks_${widget.surahNumber}')?.map(int.parse).toList() ?? [];
    });
  }

  Future<void> saveAyahBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ayahBookmarks_${widget.surahNumber}',
      bookmarkedAyahs.map((e) => e.toString()).toList(),
    );
  }

  void toggleAyahBookmark(int ayahNumber) {
    setState(() {
      if (bookmarkedAyahs.contains(ayahNumber)) {
        bookmarkedAyahs.remove(ayahNumber);
      } else {
        bookmarkedAyahs.add(ayahNumber);
      }
      saveAyahBookmarks();
    });
  }

  Future<void> fetchSurahDetails() async {
    try {
      // Fetch Arabic text
      final arabicResponse = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}'),
      );

      // Fetch Bangla translation
      final banglaResponse = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}/bn.bengali'),
      );

      if (arabicResponse.statusCode == 200 && banglaResponse.statusCode == 200) {
        final arabicData = json.decode(arabicResponse.body);
        final banglaData = json.decode(banglaResponse.body);

        setState(() {
          ayahs = arabicData['data']['ayahs'];
          banglaAyahs = banglaData['data']['ayahs'];
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'সূরার বিস্তারিত লোড করতে সমস্যা হয়েছে';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'ইন্টারনেট সংযোগ চেক করুন';
        isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.surahName} (${widget.arabicName})',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: widget.isBookmarked ? Colors.white : Colors.white,
            ),
            onPressed: widget.toggleBookmark,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.text_decrease),
                    const SizedBox(width: 8),
                    Text(
                      'ফন্ট সাইজ কমান',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    fontSize = max(14.0, fontSize - 2.0);
                  });
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.text_increase),
                    const SizedBox(width: 8),
                    Text(
                      'ফন্ট সাইজ বাড়ান',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    fontSize = min(30.0, fontSize + 2.0);
                  });
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.vertical_align_top),
                    const SizedBox(width: 8),
                    Text(
                      'শুরুতে যান',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.book),
                    const SizedBox(width: 8),
                    Text(
                      'তাফসীর দেখুন',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TafsirDetailPage(
                        surahNumber: widget.surahNumber,
                        surahName: widget.surahName,
                        arabicName: widget.arabicName,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF1F6E43),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'সূরা লোড হচ্ছে...',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                ],
              ),
            )
          : error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 16,
                          color: Colors.red.shade300,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            error = '';
                          });
                          fetchSurahDetails();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'আবার চেষ্টা করুন',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: ayahs.length + 1, // +1 for the bismillah header
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Bismillah header
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (widget.surahNumber != 9) // Surah At-Tawbah doesn't have Bismillah
                                Text(
                                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                  style: GoogleFonts.scheherazadeNew(
                                    fontSize: fontSize + 6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'সূরা ${widget.surahName}',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'আয়াত সংখ্যা: ${ayahs.length}',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (isAudioAvailable) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: isAudioLoading ? null : () => _playAyah(1),
                                      icon: Icon(
                                        isPlaying && currentPlayingAyah == 1 ? Icons.pause : Icons.play_arrow,
                                      ),
                                      label: Text(
                                        isPlaying && currentPlayingAyah == 1 ? 'পজ করুন' : 'শুনুন',
                                        style: GoogleFonts.hindSiliguri(),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1F6E43),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    if (isAudioLoading)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: widget.isDarkMode ? Colors.white : const Color(0xFF1F6E43),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (isPlaying && duration != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: GoogleFonts.roboto(
                                          fontSize: 12,
                                        ),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: position.inSeconds.toDouble(),
                                          min: 0,
                                          max: duration!.inSeconds.toDouble(),
                                          onChanged: (value) {
                                            audioPlayer.seek(Duration(seconds: value.toInt()));
                                          },
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(duration!),
                                        style: GoogleFonts.roboto(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else if (audioError.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  audioError,
                                  style: GoogleFonts.hindSiliguri(
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final ayahIndex = index - 1;
                    final ayah = ayahs[ayahIndex];
                    final banglaAyah = banglaAyahs[ayahIndex];
                    final isAyahBookmarked = bookmarkedAyahs.contains(ayah['numberInSurah']);
                    final isCurrentlyPlaying = currentPlayingAyah == ayah['numberInSurah'] && isPlaying;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: isAyahBookmarked
                              ? Border.all(
                                  color: const Color(0xFF1F6E43),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F6E43),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${ayah['numberInSurah']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isAudioAvailable)
                                    IconButton(
                                      icon: Icon(
                                        isCurrentlyPlaying ? Icons.pause_circle : Icons.play_circle,
                                        color: isCurrentlyPlaying ? const Color(0xFF1F6E43) : null,
                                        size: 28,
                                      ),
                                      onPressed: () => _playAyah(ayah['numberInSurah']),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      isAyahBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                      color: isAyahBookmarked ? const Color(0xFF1F6E43) : null,
                                      size: 22,
                                    ),
                                    onPressed: () => toggleAyahBookmark(ayah['numberInSurah']),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      // Share functionality would go here
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ayah['text'],
                                  style: GoogleFonts.scheherazadeNew(
                                    fontSize: fontSize + 4,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  banglaAyah['text'],
                                  style: GoogleFonts.hindSiliguri(
                                    fontSize: fontSize,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

