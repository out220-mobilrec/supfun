import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const SupFunApp());

class SupFunApp extends StatelessWidget {
  const SupFunApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF087EEB);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SUP FUN',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: const Color(0xFFF5F8FB),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int tab = 0;
  bool tracking = false;
  final pages = const [HomePage(), MapPage(), CommunityPage(), ProfilePage()];

  void startFlow() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PrestartPage(onStart: () {
      setState(() => tracking = true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TrackingPage()));
    })));
  }

  void createMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Что хотите сделать?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _ActionTile(icon: Icons.play_arrow_rounded, title: 'Начать заплыв', subtitle: 'Записать GPS-трек', onTap: () { Navigator.pop(context); startFlow(); }),
            _ActionTile(icon: Icons.event_rounded, title: 'Создать заплыв', subtitle: 'Одиночный или групповой', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventPage())); }),
            _ActionTile(icon: Icons.route_rounded, title: 'Опубликовать маршрут', subtitle: 'Поделиться своим треком', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteDetailPage())); }),
            _ActionTile(icon: Icons.sell_rounded, title: 'Создать объявление', subtitle: 'Продажа оборудования', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplacePage())); }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: createMenu,
        backgroundColor: const Color(0xFF087EEB),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Карта'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Сообщество'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: CustomScrollView(slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), sliver: SliverToBoxAdapter(child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Доброе утро, Александр', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Хабаровск · Амур', style: TextStyle(color: Colors.black54))])),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        const CircleAvatar(radius: 21, child: Icon(Icons.person_rounded)),
      ]))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), sliver: SliverToBoxAdapter(child: _HeroEventCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventPage()))))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), sliver: SliverToBoxAdapter(child: Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrestartPage())), icon: const Icon(Icons.play_arrow_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('НАЧАТЬ ЗАПЛЫВ')))),
      ]))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 8), sliver: SliverToBoxAdapter(child: _WeatherCard())),
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 8), sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'Активность друзей', action: 'Все'))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), sliver: SliverToBoxAdapter(child: Column(children: const [
        _ActivityCard(name: 'Анна', text: 'завершила заплыв «Бухта Тихая»', stat: '8,8 км · 1:42:17', icon: Icons.waves_rounded),
        SizedBox(height: 10),
        _ActivityCard(name: 'Иван', text: 'создал групповой заплыв «Амурский рассвет»', stat: 'Сегодня · 06:00 · 6/12', icon: Icons.groups_rounded),
      ]))),
    ]));
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: MapPainter())),
      Positioned(top: 18, left: 18, right: 18, child: _MapSearch()),
      Positioned(top: 78, left: 18, right: 18, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: const [
        _FilterChip(label: 'Маршруты', active: true), _FilterChip(label: 'Заплывы'), _FilterChip(label: 'Люди'), _FilterChip(label: 'Водоёмы'),
      ]))),
      Positioned(right: 18, top: 150, child: Column(children: [
        FloatingActionButton.small(onPressed: () {}, heroTag: 'loc', child: const Icon(Icons.my_location_rounded)),
        const SizedBox(height: 8), FloatingActionButton.small(onPressed: () {}, heroTag: 'layers', child: const Icon(Icons.layers_outlined)),
      ])),
      Positioned(left: 18, right: 18, bottom: 18, child: _RouteBottomCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteDetailPage())))),
    ]));
  }
}

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: CustomScrollView(slivers: [
    const SliverPadding(padding: EdgeInsets.fromLTRB(20, 18, 20, 8), sliver: SliverToBoxAdapter(child: Text('Сообщество', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)))),
    SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: Row(children: const [Expanded(child: _FilterChip(label: 'Лента', active: true)), SizedBox(width: 8), Expanded(child: _FilterChip(label: 'Друзья'))]))),
    SliverPadding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), sliver: SliverToBoxAdapter(child: Column(children: const [
      _PostCard(name: 'Иван', time: '2 ч назад', title: 'Сегодня закрыл 12,6 км на рассвете!', stat: '12,6 км · 2:38:12 · +62 балла', reactions: '45', comments: '12'),
      SizedBox(height: 12),
      _PostCard(name: 'Анна', time: '4 ч назад', title: 'Создала групповой заплыв «Северный Амур»', stat: 'Сегодня · 18:30 · 10 км · 6/12', reactions: '18', comments: '7'),
      SizedBox(height: 12),
      _ChannelCard(),
    ]))),
  ]));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: CustomScrollView(slivers: [
    SliverPadding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 12), sliver: SliverToBoxAdapter(child: Row(children: [
      const CircleAvatar(radius: 38, child: Icon(Icons.person_rounded, size: 42)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Александр ✓', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)), Text('SUP-райдер · Хабаровск', style: TextStyle(color: Colors.black54)), SizedBox(height: 8), _LevelBar()]))
    ]))),
    SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), sliver: SliverToBoxAdapter(child: Row(children: const [Expanded(child: _Stat(value: '1 280', label: 'км')), Expanded(child: _Stat(value: '42', label: 'заплыва')), Expanded(child: _Stat(value: '128', label: 'дней на воде'))]))),
    SliverPadding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 8), sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'Любимые водоёмы', action: 'Все'))),
    SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: SizedBox(height: 92, child: Row(children: const [_MiniWater(title: 'Амур'), SizedBox(width: 10), _MiniWater(title: 'Уссури'), SizedBox(width: 10), _MiniWater(title: 'Японское море')])))),
    SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'Достижения', action: 'Все'))),
    SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), sliver: SliverToBoxAdapter(child: Row(children: const [_Achievement(icon: Icons.star_rounded), _Achievement(icon: Icons.route_rounded), _Achievement(icon: Icons.local_fire_department_rounded), _Achievement(icon: Icons.waves_rounded)]))),
  ]));
}

class PrestartPage extends StatelessWidget {
  final VoidCallback? onStart;
  const PrestartPage({super.key, this.onStart});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Предстартовая проверка')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Готовы к выходу?', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 6), const Text('Амур · Хабаровск', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18),
    _WeatherCard(), const SizedBox(height: 18),
    _Panel(title: 'Снаряжение', child: Column(children: const [_CheckRow('Спасательный жилет'), _CheckRow('Лиш'), _CheckRow('Телефон в гермокейсе'), _CheckRow('Вода'), _CheckRow('Заряд телефона · 78%')])), const SizedBox(height: 18),
    FilledButton(onPressed: () { if (onStart != null) { onStart!(); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingPage())); } }, child: const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('НАЧАТЬ ЗАПЛЫВ'))),
  ]));
}

class TrackingPage extends StatefulWidget { const TrackingPage({super.key}); @override State<TrackingPage> createState() => _TrackingPageState(); }
class _TrackingPageState extends State<TrackingPage> {
  bool paused = false; bool finished = false;
  @override Widget build(BuildContext context) {
    if (finished) return const ResultPage();
    return Scaffold(body: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: MapPainter(trackOnly: true))),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 0), child: Row(children: [IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back_rounded)), const Expanded(child: Text('Запись', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), const Icon(Icons.gps_fixed_rounded, color: Color(0xFF087EEB))])),
        const Spacer(),
        Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.fromLTRB(18, 18, 18, 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(blurRadius: 24, color: Color(0x22000000))]), child: Column(children: [
          Row(children: const [Expanded(child: _BigMetric('12,84', 'км')), Expanded(child: _BigMetric('2:45:32', 'время')), Expanded(child: _BigMetric('4,7', 'км/ч'))]), const SizedBox(height: 14),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => paused = !paused), icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded), label: Text(paused ? 'Продолжить' : 'Пауза'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => setState(() => finished = true), icon: const Icon(Icons.stop_rounded), label: const Text('Стоп')))]),
        ])),
      ])),
    ]));
  }
}

class ResultPage extends StatelessWidget { const ResultPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Результат')), body: ListView(padding: const EdgeInsets.all(20), children: [
  Container(height: 180, decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B78D0), Color(0xFF72D9FF)])), child: const Center(child: Icon(Icons.waves_rounded, size: 86, color: Colors.white))), const SizedBox(height: 20), const Text('Заплыв завершён!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const Text('Амурский рассвет', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18),
  Row(children: const [Expanded(child: _BigMetric('12,8', 'дистанция')), Expanded(child: _BigMetric('2:45:32', 'время')), Expanded(child: _BigMetric('4,7', 'км/ч'))]), const SizedBox(height: 18),
  Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.stars_rounded, color: Colors.green, size: 32), SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('+48 баллов', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text('Новое достижение «Дальний маршрут»')])])), const SizedBox(height: 18),
  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Сохранить')), const SizedBox(height: 8), OutlinedButton(onPressed: () {}, child: const Text('Опубликовать')),
 ]); }

class EventPage extends StatelessWidget { const EventPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Заплыв')), body: ListView(padding: const EdgeInsets.all(20), children: [
  _ImageHero(title: 'Амурский рассвет', subtitle: 'Групповой · Хабаровск'), const SizedBox(height: 18), const _Panel(title: 'Параметры', child: Column(children: [_InfoRow(Icons.calendar_today_rounded, '12 июля · 06:00'), _InfoRow(Icons.place_rounded, 'Амур, Хабаровск'), _InfoRow(Icons.straighten_rounded, '12 км · 2:45 · Сложность: синяя'), _InfoRow(Icons.groups_rounded, '6 / 12 участников')])), const SizedBox(height: 18), _WeatherCard(), const SizedBox(height: 18),
  Row(children: [Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Маршрут'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: () {}, child: const Text('Присоединиться')))]),
 ]); }

class CreateEventPage extends StatelessWidget { const CreateEventPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Создать заплыв')), body: ListView(padding: const EdgeInsets.all(20), children: [
 const Text('Новый заплыв', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), const _TextField(label: 'Название', hint: 'Например, Вечерний круг'), const SizedBox(height: 12), const _TextField(label: 'Водоём', hint: 'Амур'), const SizedBox(height: 12), const _TextField(label: 'Дата и время', hint: 'Сегодня · 18:30'), const SizedBox(height: 12), const _TextField(label: 'Маршрут', hint: 'Выберите маршрут'), const SizedBox(height: 12), const _TextField(label: 'Максимум участников', hint: '12'), const SizedBox(height: 20), FilledButton(onPressed: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('СОЗДАТЬ ЗАПЛЫВ'))),
 ]); }

class RouteDetailPage extends StatelessWidget { const RouteDetailPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Маршрут')), body: ListView(padding: const EdgeInsets.all(20), children: [
 _ImageHero(title: 'Бухта Тихая', subtitle: 'Хабаровск · Лёгкий'), const SizedBox(height: 18), Row(children: const [Expanded(child: _BigMetric('8,8', 'км')), Expanded(child: _BigMetric('1:42:17', 'время')), Expanded(child: _BigMetric('4,9', 'км/ч'))]), const SizedBox(height: 18), Container(height: 230, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFFE3F4FF)), child: CustomPaint(painter: MapPainter(trackOnly: true))), const SizedBox(height: 16), const _Panel(title: 'Высоты', child: SizedBox(height: 80, child: _MiniChart())), const SizedBox(height: 16), Row(children: [Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Скачать GPX'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: () {}, child: const Text('Начать по маршруту')))]),
 ]); }

class MarketplacePage extends StatelessWidget { const MarketplacePage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Маркетплейс')), body: CustomScrollView(slivers: [
 SliverPadding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), sliver: SliverToBoxAdapter(child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Поиск по товарам', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))))),
 SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), sliver: SliverToBoxAdapter(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: const [_FilterChip(label: 'Все', active: true), _FilterChip(label: 'Доски'), _FilterChip(label: 'Вёсла'), _FilterChip(label: 'Аксессуары')]))),
 SliverPadding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), sliver: SliverGrid(delegate: SliverChildListDelegate(const [_ProductCard(title: 'SUP-доска Red Paddle 12’6', price: '95 000 ₽'), _ProductCard(title: 'Весло Carbon 3K', price: '18 000 ₽'), _ProductCard(title: 'Гидрокостюм 5/4', price: '25 000 ₽'), _ProductCard(title: 'Гермомешок 30 л', price: '5 500 ₽')]), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .76))),
 ])); }

// ---------- Shared widgets ----------
class _HeroEventCard extends StatelessWidget { final VoidCallback onTap; const _HeroEventCard({required this.onTap}); @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Container(height: 210, padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF075EA8), Color(0xFF35B7E8)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Spacer(), Text('Ближайшие заплывы', style: TextStyle(color: Colors.white70)), SizedBox(height: 4), Text('Амурский рассвет', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 7), Text('12 июля · 06:00 · 12 км', style: TextStyle(color: Colors.white)), SizedBox(height: 12), Chip(label: Text('Подробнее'), backgroundColor: Colors.white)]))); }
class _WeatherCard extends StatelessWidget { @override Widget build(BuildContext context) => Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Погода в Хабаровске', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 14), Row(children: [Text('☀️', style: TextStyle(fontSize: 30)), SizedBox(width: 12), Expanded(child: _WeatherValue('+22°', 'сейчас')), _WeatherValue('4 м/с', 'ветер'), _WeatherValue('0,4 м', 'волна'), _WeatherValue('17°', 'вода')])]))); }
class _WeatherValue extends StatelessWidget { final String value,label; const _WeatherValue(this.value,this.label); @override Widget build(BuildContext context)=>Padding(padding: const EdgeInsets.only(left: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))])); }
class _SectionTitle extends StatelessWidget { final String title,action; const _SectionTitle({required this.title,required this.action}); @override Widget build(BuildContext context)=>Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800))),Text(action,style:const TextStyle(color:Color(0xFF087EEB),fontWeight:FontWeight.w700))]); }
class _ActivityCard extends StatelessWidget { final String name,text,stat; final IconData icon; const _ActivityCard({required this.name,required this.text,required this.stat,required this.icon}); @override Widget build(BuildContext context)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[const CircleAvatar(child:Icon(Icons.person_rounded)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[RichText(text:TextSpan(style:const TextStyle(color:Colors.black),children:[TextSpan(text:name,style:const TextStyle(fontWeight:FontWeight.w800)),TextSpan(text:' $text')]),const SizedBox(height:5),Text(stat,style:const TextStyle(color:Colors.black54,fontSize:12))])),Icon(icon,color:const Color(0xFF087EEB))]))); }
class _MapSearch extends StatelessWidget { @override Widget build(BuildContext context)=>Material(elevation:2,borderRadius:BorderRadius.circular(18),child:TextField(decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),hintText:'Поиск на карте',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none)))); }
class _FilterChip extends StatelessWidget { final String label; final bool active; const _FilterChip({required this.label,this.active=false}); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(right:8),child:Chip(label:Text(label),backgroundColor:active?const Color(0xFF087EEB):Colors.white,labelStyle:TextStyle(color:active?Colors.white:Colors.black87,fontWeight:FontWeight.w700),side:BorderSide.none)); }
class _RouteBottomCard extends StatelessWidget { final VoidCallback onTap; const _RouteBottomCard({required this.onTap}); @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(24),child:Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[Container(width:62,height:62,decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),color:const Color(0xFFE0F4FF)),child:const Icon(Icons.route_rounded,color:Color(0xFF087EEB),size:30)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Амурский рассвет',style:TextStyle(fontWeight:FontWeight.w900)),Text('12 км · 2:45:32 · 4,7 км/ч',style:TextStyle(color:Colors.black54,fontSize:12))])),const Icon(Icons.chevron_right_rounded)])))); }
class _PostCard extends StatelessWidget { final String name,time,title,stat,reactions,comments; const _PostCard({required this.name,required this.time,required this.title,required this.stat,required this.reactions,required this.comments}); @override Widget build(BuildContext context)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const CircleAvatar(radius:20,child:Icon(Icons.person_rounded)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),Text(time,style:const TextStyle(color:Colors.black45,fontSize:12))])),const Icon(Icons.more_horiz_rounded)]),const SizedBox(height:12),Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:6),Text(stat,style:const TextStyle(color:Colors.black54)),const SizedBox(height:12),Container(height:150,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(colors:[Color(0xFF0A7EC7),Color(0xFFB5EEFF)])),child:const Center(child:Icon(Icons.waves_rounded,size:60,color:Colors.white))),const SizedBox(height:8),Row(children:[Text('♥ $reactions'),const SizedBox(width:18),Text('💬 $comments'),const Spacer(),const Icon(Icons.share_outlined,size:19),const SizedBox(width:6),const Text('Поделиться')])]))); }
class _ChannelCard extends StatelessWidget { const _ChannelCard(); @override Widget build(BuildContext context)=>Card(color:const Color(0xFFE9F7FF),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[const CircleAvatar(child:Icon(Icons.campaign_rounded)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Канал «Хабаровск»',style:TextStyle(fontWeight:FontWeight.w900)),Text('Погода, события и общение',style:TextStyle(color:Colors.black54))])),FilledButton(onPressed:(){},child:const Text('Войти'))]))); }
class _LevelBar extends StatelessWidget { const _LevelBar(); @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Text('Уровень 18',style:TextStyle(fontWeight:FontWeight.w800)),Spacer(),Text('1 280 / 2 000 XP',style:TextStyle(fontSize:11,color:Colors.black54))]),const SizedBox(height:6),LinearProgressIndicator(value:.64,borderRadius:BorderRadius.circular(10))]); }
class _Stat extends StatelessWidget { final String value,label; const _Stat({required this.value,required this.label}); @override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:11,color:Colors.black54))]); }
class _MiniWater extends StatelessWidget { final String title; const _MiniWater({required this.title}); @override Widget build(BuildContext context)=>Expanded(child:Container(decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(colors:[Color(0xFF087EEB),Color(0xFF76DDF5)])),alignment:Alignment.bottomLeft,padding:const EdgeInsets.all(10),child:Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)))); }
class _Achievement extends StatelessWidget { final IconData icon; const _Achievement({required this.icon}); @override Widget build(BuildContext context)=>Expanded(child:Container(height:72,margin:const EdgeInsets.only(right:8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:const Color(0xFFFFB300),size:34))); }
class _Panel extends StatelessWidget { final String title; final Widget child; const _Panel({required this.title,required this.child}); @override Widget build(BuildContext context)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:12),child]))); }
class _CheckRow extends StatelessWidget { final String text; const _CheckRow(this.text); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[const Icon(Icons.check_circle_rounded,color:Colors.green),const SizedBox(width:10),Expanded(child:Text(text)),const Icon(Icons.chevron_right_rounded,color:Colors.black38)])); }
class _BigMetric extends StatelessWidget { final String value,label; const _BigMetric(this.value,this.label); @override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:11,color:Colors.black54))]); }
class _InfoRow extends StatelessWidget { final IconData icon; final String text; const _InfoRow(this.icon,this.text); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Icon(icon,size:20,color:const Color(0xFF087EEB)),const SizedBox(width:10),Text(text)])); }
class _ImageHero extends StatelessWidget { final String title,subtitle; const _ImageHero({required this.title,required this.subtitle}); @override Widget build(BuildContext context)=>Container(height:210,padding:const EdgeInsets.all(18),alignment:Alignment.bottomLeft,decoration:BoxDecoration(borderRadius:BorderRadius.circular(26),gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF7EDCF7),Color(0xFF075EA8)])),child:Column(mainAxisAlignment:MainAxisAlignment.end,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),Text(subtitle,style:const TextStyle(color:Colors.white70))])); }
class _TextField extends StatelessWidget { final String label,hint; const _TextField({required this.label,required this.hint}); @override Widget build(BuildContext context)=>TextField(decoration:InputDecoration(labelText:label,hintText:hint,filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none))); }
class _ProductCard extends StatelessWidget { final String title,price; const _ProductCard({required this.title,required this.price}); @override Widget build(BuildContext context)=>Card(color:Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Container(decoration:BoxDecoration(borderRadius:const BorderRadius.vertical(top:Radius.circular(22)),gradient:const LinearGradient(colors:[Color(0xFFB7ECFF),Color(0xFFE8FAFF)])),child:const Center(child:Icon(Icons.surfing_rounded,size:54,color:Color(0xFF087EEB))))),Padding(padding:const EdgeInsets.fromLTRB(12,10,12,12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(price,style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF087EEB))),const Text('Хабаровск',style:TextStyle(fontSize:11,color:Colors.black45))]))])); }
class _MiniChart extends StatelessWidget { const _MiniChart(); @override Widget build(BuildContext context)=>CustomPaint(painter: ChartPainter()); }
class _ActionTile extends StatelessWidget { final IconData icon; final String title,subtitle; final VoidCallback onTap; const _ActionTile({required this.icon,required this.title,required this.subtitle,required this.onTap}); @override Widget build(BuildContext context)=>ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:const Color(0xFFE6F5FF),child:Icon(icon,color:const Color(0xFF087EEB))),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right_rounded)); }

class MapPainter extends CustomPainter { final bool trackOnly; MapPainter({this.trackOnly=false}); @override void paint(Canvas c, Size s) { final p=Paint()..style=PaintingStyle.fill; p.color=const Color(0xFFE0EEF4); c.drawRect(Offset.zero & s,p); final water=Paint()..color=const Color(0xFF9BD9E8); final path=Path()..moveTo(s.width*.54,0)..cubicTo(s.width*.42,s.height*.2,s.width*.72,s.height*.32,s.width*.5,s.height*.5)..cubicTo(s.width*.25,s.height*.7,s.width*.62,s.height*.82,s.width*.48,s.height); c.drawPath(path,water); final route=Paint()..color=const Color(0xFF087EEB)..strokeWidth=5..style=PaintingStyle.stroke..strokeCap=StrokeCap.round; final r=Path()..moveTo(s.width*.22,s.height*.7)..cubicTo(s.width*.34,s.height*.62,s.width*.45,s.height*.72,s.width*.52,s.height*.55)..cubicTo(s.width*.62,s.height*.4,s.width*.55,s.height*.3,s.width*.69,s.height*.2); c.drawPath(r,route); for(final pt in [Offset(s.width*.22,s.height*.7),Offset(s.width*.52,s.height*.55),Offset(s.width*.69,s.height*.2)]){c.drawCircle(pt,8,Paint()..color=Colors.white);c.drawCircle(pt,5,Paint()..color=const Color(0xFF087EEB));} for(int i=0;i<18;i++){final x=(i*83)%s.width;final y=(i*137)%s.height;c.drawCircle(Offset(x,y),2,Paint()..color=const Color(0x335A7A86));}} @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false; }
class ChartPainter extends CustomPainter { @override void paint(Canvas c, Size s){final p=Paint()..color=const Color(0xFF087EEB)..strokeWidth=2..style=PaintingStyle.stroke;final path=Path()..moveTo(0,s.height*.7);for(int i=1;i<=20;i++){final x=s.width*i/20;final y=s.height*(.3+.4*((math.sin(i*1.5)+1)/2)*.7);path.lineTo(x,y);}c.drawPath(path,p);} @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false; }
