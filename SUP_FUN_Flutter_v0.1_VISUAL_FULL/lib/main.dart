import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/storage_controller.dart';
import 'controllers/auth_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/community_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/waterbody_screen.dart';
import 'screens/prestart_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/result_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/chats_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/local_data_screen.dart';
import 'screens/create_event_screen.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Try to init local storage, but don't fail if path_provider not available
  try {
    await LocalStorageService.instance.init();
  } catch (e) {
    debugPrint('Local storage not available: $e');
  }
  runApp(const SupFunApp());
}

class SupFunApp extends StatelessWidget {
  const SupFunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StorageController()..loadAll(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final auth = AuthController();
            auth.initialize();
            return auth;
          },
        ),
      ],
      child: Consumer<AuthController>(
        builder: (context, auth, _) {
          Widget home;
          if (auth.isResumingSession) {
            // Пока идёт попытка тихого входа по refresh-токену -
            // показываем сплеш, без формы логина.
            home = const _SplashGate();
          } else if (auth.isAuthenticated) {
            home = const _AuthenticatedRoot();
          } else {
            home = const AuthScreen();
          }
          return MaterialApp(
            title: 'SUP FUN',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: home,
            routes: {
              '/home': (_) => const Shell(),
              '/auth': (_) => const AuthScreen(),
              '/waterbody': (_) => const WaterBodyScreen(waterBodyId: '1'),
              '/prestart': (_) => const PrestartScreen(),
              '/tracking': (_) => const TrackingScreen(),
              '/result': (_) => const ResultScreen(),
              '/marketplace': (_) => const MarketplaceScreen(),
              '/chats': (_) => const ChatsListScreen(),
              '/local-data': (_) => const LocalDataScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/chat') {
                final conversationId = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(conversationId: conversationId),
                );
              }
              if (settings.name == '/create-event') {
                return MaterialPageRoute(
                  builder: (_) => const CreateEventScreen(),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  final screens = const [
    HomeScreen(),
    MapScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  void go(int i) => setState(() => index = i);

  void quickAction() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Что хотите сделать?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              _ActionTile('🏄', 'Начать заплыв', 'Запустить GPS-трекинг',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrestartScreen()))),
              _ActionTile('📅', 'Создать заплыв', 'Одиночный или групповой',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()))),
              _ActionTile('🗺️', 'Опубликовать маршрут', 'Добавить маршрут в сообщество', () {}),
              _ActionTile('🛒', 'Создать объявление', 'Продать или обменять снаряжение', () {}),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      floatingActionButton: FloatingActionButton.large(
        onPressed: quickAction,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 76,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Nav('Главная', Icons.home_rounded, 0, index, go),
            _Nav('Карта', Icons.map_rounded, 1, index, go),
            const SizedBox(width: 72),
            _Nav('Лента', Icons.forum_rounded, 2, index, go),
            _Nav('Профиль', Icons.person_rounded, 3, index, go),
          ],
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final String label; final IconData icon; final int value, current; final void Function(int) onTap;
  const _Nav(this.label, this.icon, this.value, this.current, this.onTap);
  @override Widget build(BuildContext context) => IconButton(
    onPressed: () => onTap(value),
    tooltip: label,
    icon: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: current == value ? Theme.of(context).colorScheme.primary : Colors.grey),
      Text(label, style: TextStyle(fontSize: 10, color: current == value ? Theme.of(context).colorScheme.primary : Colors.grey)),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final String emoji, title, subtitle; final VoidCallback onTap;
  const _ActionTile(this.emoji, this.title, this.subtitle, this.onTap);
  @override Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(radius: 25, child: Text(emoji, style: const TextStyle(fontSize: 23))),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
  );
}

class Header extends StatelessWidget {
  final String title;
  const Header(this.title, {super.key});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 12),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900))),
      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
      const CircleAvatar(radius: 19, child: Icon(Icons.person)),
    ]),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override Widget build(BuildContext context) => SafeArea(
    child: ListView(padding: EdgeInsets.zero, children: [
      const Header('Доброе утро, Александр'),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Сегодня отличная погода для воды.', style: TextStyle(color: Colors.black54))),
      const SizedBox(height: 18),
      _HeroCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventScreen()))),
      const SizedBox(height: 18),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
        Expanded(child: _StatCard('Погода', '+22°', 'Ветер 4 м/с')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard('Вода', '17°', 'Волна 0,4 м')),
      ])),
      const SizedBox(height: 20),
      const _SectionTitle('Активность друзей'),
      _ActivityCard('Иван Петров', 'завершил маршрут «Амурская протока»', '12,4 км • 2ч 18м'),
      _ActivityCard('Мария', 'создала новый групповой заплыв', 'Суббота • 09:00'),
      const _SectionTitle('Популярные маршруты'),
      _RouteCard('Амурский рассвет', '12,8 км', 'Легкий'),
      _RouteCard('Остров Большой Уссурийский', '18,2 км', 'Средний'),
      const SizedBox(height: 30),
    ]),
  );
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    height: 245,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF007F86), Color(0xFF003D62)]),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 20, offset: const Offset(0, 10))],
    ),
    child: Stack(children: [
      const Positioned(right: -20, top: 20, child: Text('🌊', style: TextStyle(fontSize: 130))),
      Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('БЛИЖАЙШИЙ ЗАПЛЫВ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        const Text('Амурский рассвет', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Суббота • 06:00 • 12 км', style: TextStyle(color: Colors.white, fontSize: 15)),
        const Spacer(),
        FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.arrow_forward), label: const Text('Открыть заплыв')),
      ])),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String title, value, sub;
  const _StatCard(this.title, this.value, this.sub);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
  );
}

class _ActivityCard extends StatelessWidget {
  final String name, action, detail;
  const _ActivityCard(this.name, this.action, this.detail);
  @override Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
    elevation: 0,
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text('$name $action'),
      subtitle: Text(detail),
      trailing: const Icon(Icons.favorite_border),
    ),
  );
}

class _RouteCard extends StatelessWidget {
  final String title, distance, level;
  const _RouteCard(this.title, this.distance, this.level);
  @override Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
    elevation: 0,
    child: ListTile(
      leading: Container(width: 54, height: 54, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [Color(0xFF00A6A6), Color(0xFF006B8F)])), child: const Icon(Icons.waves, color: Colors.white)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$distance • $level'),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override Widget build(BuildContext context) => SafeArea(
    child: Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFDCEAE4), Color(0xFFBFD7CF)]),
        ),
        child: CustomPaint(painter: _MapPainter(), size: Size.infinite),
      ),
      const Positioned(top: 18, left: 18, right: 18, child: SearchBar(hintText: 'Найти водоём, маршрут или заплыв', leading: Icon(Icons.search))),
      Positioned(left: 18, bottom: 22, right: 18, child: Row(children: [
        _MapChip('Маршруты', true), _MapChip('Заплывы', false), _MapChip('Водоёмы', false),
      ])),
      Positioned(top: 90, right: 18, child: FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.my_location))),
    ]),
  );
}

class _MapChip extends StatelessWidget {
  final String text; final bool active;
  const _MapChip(this.text, this.active);
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    child: FilterChip(label: Text(text), selected: active, onSelected: (_) {}),
  );
}

class _MapPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withOpacity(.45)..strokeWidth = 2..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) c.drawLine(Offset(0, s.height*i/8), Offset(s.width, s.height*(i+1)/8), p);
    final r = Paint()..color = const Color(0xFF00A6A6)..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(s.width*.18, s.height*.75)..cubicTo(s.width*.32,s.height*.62,s.width*.42,s.height*.7,s.width*.52,s.height*.52)..cubicTo(s.width*.62,s.height*.32,s.width*.78,s.height*.4,s.width*.88,s.height*.18);
    c.drawPath(path, r);
    final dot = Paint()..color = const Color(0xFFFF7A45);
    c.drawCircle(Offset(s.width*.52,s.height*.52), 10, dot);
  }
  @override bool shouldRepaint(_) => false;
}

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Заплыв')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Амурский рассвет', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Суббота, 06:00 • 12 км • Лёгкий'),
      const SizedBox(height: 20),
      const _InfoPanel(),
      const SizedBox(height: 20),
      const Text('Участники • 6', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Row(children: [CircleAvatar(child: Icon(Icons.person)), SizedBox(width: 8), CircleAvatar(child: Icon(Icons.person)), SizedBox(width: 8), CircleAvatar(child: Icon(Icons.person)), SizedBox(width: 8), CircleAvatar(child: Text('+3'))]),
      const SizedBox(height: 25),
      FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrestartScreen())), child: const Padding(padding: EdgeInsets.all(14), child: Text('ПРИСОЕДИНИТЬСЯ'))),
    ]),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel();
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.white),
    child: const Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Погода', style: TextStyle(fontWeight: FontWeight.w800)), Text('Отлично', style: TextStyle(fontWeight: FontWeight.w800))]),
      SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _Mini('🌡️', '+22°'), _Mini('💨', '4 м/с'), _Mini('🌊', '0,4 м'), _Mini('💧', '17°')
      ])
    ]),
  );
}
class _Mini extends StatelessWidget {
  final String icon, value; const _Mini(this.icon, this.value);
  @override Widget build(BuildContext context) => Column(children: [Text(icon, style: const TextStyle(fontSize: 22)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]);
}

class PrestartScreen extends StatelessWidget {
  const PrestartScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Предстартовая проверка')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Готовы к выходу?', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      const _InfoPanel(),
      const SizedBox(height: 22),
      const Text('Чек-лист', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      for (final x in ['Жилет', 'Лиш', 'Телефон в гермокейсе', 'Вода']) CheckboxListTile(value: true, onChanged: (_) {}, title: Text(x), contentPadding: EdgeInsets.zero),
      const SizedBox(height: 15),
      FilledButton.icon(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TrackingScreen())), icon: const Icon(Icons.play_arrow), label: const Padding(padding: EdgeInsets.all(14), child: Text('НАЧАТЬ ЗАПЛЫВ'))),
    ]),
  );
}

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override State<TrackingScreen> createState() => _TrackingState();
}
class _TrackingState extends State<TrackingScreen> {
  bool paused = false;
  Duration elapsed = const Duration(minutes: 42, seconds: 18);
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF062D3B),
    appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: const Text('На воде')),
    body: SafeArea(child: Column(children: [
      Expanded(child: Stack(children: [
        CustomPaint(painter: _WaterPainter(), size: Size.infinite),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('12,84', style: TextStyle(color: Colors.white, fontSize: 76, fontWeight: FontWeight.w900)),
          const Text('КМ', style: TextStyle(color: Colors.white70, letterSpacing: 3)),
          const SizedBox(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _BigMetric('ВРЕМЯ', '2:45:32'), _BigMetric('СР. СКОРОСТЬ', '4,7 км/ч'),
          ]),
        ])),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 22), child: Row(children: [
        Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.all(17)), onPressed: () => setState(() => paused = !paused), icon: Icon(paused ? Icons.play_arrow : Icons.pause), label: Text(paused ? 'Продолжить' : 'Пауза'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7043), padding: const EdgeInsets.all(17)), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultScreen())), icon: const Icon(Icons.stop), label: const Text('Стоп'))),
      ])),
    ])),
  );
}
class _BigMetric extends StatelessWidget {
  final String a,b; const _BigMetric(this.a,this.b);
  @override Widget build(BuildContext context) => Column(children: [Text(a, style: const TextStyle(color: Colors.white54, fontSize: 11)), const SizedBox(height: 5), Text(b, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))]);
}
class _WaterPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withOpacity(.09)..strokeWidth = 2;
    for (int i=0;i<12;i++) c.drawLine(Offset(0,i*s.height/12), Offset(s.width,i*s.height/12), p);
  }
  @override bool shouldRepaint(_) => false;
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Результат')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF007F86), Color(0xFF004B72)])), child: const Column(children: [
        Text('ЗАПЛЫВ ЗАВЕРШЁН', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
        SizedBox(height: 12), Text('12,8 км', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
        Text('2:45:32 • 4,7 км/ч', style: TextStyle(color: Colors.white)),
      ])),
      const SizedBox(height: 20),
      const ListTile(leading: Icon(Icons.stars), title: Text('+48 баллов', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Награда за заплыв')),
      const ListTile(leading: Icon(Icons.emoji_events), title: Text('Новое достижение!', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Дальний маршрут')),
      const SizedBox(height: 20),
      FilledButton(onPressed: () {}, child: const Padding(padding: EdgeInsets.all(14), child: Text('СОХРАНИТЬ МАРШРУТ'))),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () {}, child: const Padding(padding: EdgeInsets.all(14), child: Text('ОПУБЛИКОВАТЬ'))),
    ]),
  );
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});
  @override Widget build(BuildContext context) => SafeArea(child: ListView(children: [
    const Header('Сообщество'),
    const Padding(padding: EdgeInsets.fromLTRB(20,0,20,14), child: SearchBar(hintText: 'Поиск в SUP FUN', leading: Icon(Icons.search))),
    const _PostCard('Мария', 'создала заплыв «Утро на Амуре»', 'Суббота • 09:00 • 8 участников', '🏄'),
    const _PostCard('Иван Петров', 'завершил маршрут', '12,4 км • 2ч 18м • +42 XP', '🌊'),
    const _PostCard('SUP CLUB', 'Новый челлендж сезона', '100 км за месяц', '🏆'),
  ]));
}
class _PostCard extends StatelessWidget {
  final String name, action, detail, emoji;
  const _PostCard(this.name,this.action,this.detail,this.emoji);
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.fromLTRB(20, 5, 20, 8), elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const CircleAvatar(child: Icon(Icons.person)), const SizedBox(width: 10), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))), Text(emoji, style: const TextStyle(fontSize: 26))]),
    const SizedBox(height: 12), Text(action), const SizedBox(height: 6), Text(detail, style: const TextStyle(color: Colors.black54)),
    const SizedBox(height: 12), const Row(children: [Icon(Icons.favorite_border), SizedBox(width: 20), Icon(Icons.mode_comment_outlined), SizedBox(width: 20), Icon(Icons.share_outlined)])
  ])));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override Widget build(BuildContext context) => SafeArea(child: ListView(children: [
    const Header('Профиль'),
    const Padding(padding: EdgeInsets.symmetric(horizontal:20), child: Row(children: [
      CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)), SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Александр', style: TextStyle(fontSize: 24,fontWeight: FontWeight.w900)), Text('Хабаровск • SUP FUN', style: TextStyle(color: Colors.black54)), SizedBox(height:5), Text('Уровень 18 • 560 XP', style: TextStyle(fontWeight: FontWeight.w700))])
    ])),
    const SizedBox(height: 20),
    Padding(padding: const EdgeInsets.symmetric(horizontal:20), child: Row(children: [
      Expanded(child: _ProfileStat('Заплывы','86')), Expanded(child: _ProfileStat('Км','842')), Expanded(child: _ProfileStat('Достижения','24')),
    ])),
    const _SectionTitle('Мои разделы'),
    _ProfileTile(Icons.route, 'Мои маршруты'), _ProfileTile(Icons.calendar_month, 'Мои заплывы'),
    _ProfileTile(Icons.emoji_events, 'Достижения и челленджи'), _ProfileTile(Icons.surfing, 'Моё снаряжение'),
    _ProfileTile(Icons.storefront, 'Мои объявления'), _ProfileTile(Icons.settings, 'Настройки'),
  ]));
}
class _ProfileStat extends StatelessWidget {
  final String a,b; const _ProfileStat(this.a,this.b);
  @override Widget build(BuildContext context)=>Column(children:[Text(b,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),Text(a,style:const TextStyle(color:Colors.black54))]);
}
class _ProfileTile extends StatelessWidget {
  final IconData icon; final String text; const _ProfileTile(this.icon,this.text);
  @override Widget build(BuildContext context)=>ListTile(leading:Icon(icon),title:Text(text,style:const TextStyle(fontWeight:FontWeight.w700)),trailing:const Icon(Icons.chevron_right));
}

class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Создать заплыв')),body:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Новый групповой заплыв',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
    const SizedBox(height:20),
    for(final x in ['Название','Дата','Время','Место старта','Маршрут','Уровень']) Padding(padding:const EdgeInsets.only(bottom:14),child:TextField(decoration:InputDecoration(labelText:x,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))))),
    FilledButton(onPressed:()=>Navigator.pop(context),child:const Padding(padding:EdgeInsets.all(14),child:Text('СОЗДАТЬ ЗАПЛЫВ')))
  ]));
}


class ConceptGalleryScreen extends StatelessWidget {
  const ConceptGalleryScreen({super.key});

  static const screens = <Map<String, String>>[
    {'title': '01 — Splash', 'asset': 'assets/images/01_splash.png'},
    {'title': '02 — Главная', 'asset': 'assets/images/02_home.png'},
    {'title': '03 — Карта', 'asset': 'assets/images/03_map.png'},
    {'title': '04 — Водоём', 'asset': 'assets/images/04_waterbody.png'},
    {'title': '05 — Заплыв', 'asset': 'assets/images/05_event.png'},
    {'title': '06 — Предстарт', 'asset': 'assets/images/06_prestart.png'},
    {'title': '07 — Трекинг', 'asset': 'assets/images/07_tracking.png'},
    {'title': '08 — Результат', 'asset': 'assets/images/08_result.png'},
    {'title': '09 — Маршрут', 'asset': 'assets/images/09_route.png'},
    {'title': '10 — Маркетплейс', 'asset': 'assets/images/10_marketplace.png'},
    {'title': '11 — Профиль', 'asset': 'assets/images/11_profile.png'},
    {'title': '12 — Сообщество', 'asset': 'assets/images/12_community.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SUP FUN — визуальный концепт')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: .58,
        ),
        itemCount: screens.length,
        itemBuilder: (_, i) {
          final s = screens[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(s['title']!)),
                  body: InteractiveViewer(
                    minScale: .7,
                    maxScale: 4,
                    child: Center(
                      child: Image.asset(s['asset']!, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(child: Image.asset(s['asset']!, fit: BoxFit.contain)),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      s['title']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

/// Показывает сплеш, потом переводит в основной шелл
class _AuthenticatedRoot extends StatefulWidget {
  const _AuthenticatedRoot();

  @override
  State<_AuthenticatedRoot> createState() => _AuthenticatedRootState();
}

class _AuthenticatedRootState extends State<_AuthenticatedRoot> {
  @override
  void initState() {
    super.initState();
    // Сразу переходим в основной шелл без задержки — главный экран
    // (сплеш уже показан на фоне AuthScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/home', (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Заставка во время тихого возобновления сессии по refresh-токену.
/// Не показывает форму логина: либо завершается вход (родитель перестроит
/// `home` в `_AuthenticatedRoot`), либо — если refresh провалился —
/// переход на AuthScreen.
class _SplashGate extends StatelessWidget {
  const _SplashGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A4A6E),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/splash/splash_1080.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black54)),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Входим...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
