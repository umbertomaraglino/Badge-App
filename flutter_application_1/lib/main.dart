import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MaterialApp(home: AppEntrata()));

class Giorno {
  DateTime data;
  TimeOfDay? ingresso;
  TimeOfDay? uscita;
  Giorno(this.data, {this.ingresso, this.uscita});
}

class AppEntrata extends StatefulWidget {
  const AppEntrata({super.key});

  @override
  State<AppEntrata> createState() => _AppEntrataState();
}

class _AppEntrataState extends State<AppEntrata> {
  Future<void> resettaManuale() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Conferma reset'),
        content: Text(
          'Vuoi davvero cancellare tutti gli orari della settimana?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Conferma'),
          ),
        ],
      ),
    );
    if (conferma == true) {
      setState(() {
        giorni = [];
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('giorni', []);
    }
  }

  int minutiEffettiviSettimana() {
    final now = DateTime.now();
    final lunedi = now.subtract(Duration(days: now.weekday - 1));
    return giorni
        .where((g) => g.data.isAfter(lunedi.subtract(Duration(days: 1))))
        .fold(0, (sum, g) => sum + minutiEffettivi(g));
  }

  int minutiPrevistiSettimana() {
    final now = DateTime.now();
    final lunedi = now.subtract(Duration(days: now.weekday - 1));
    return giorni
        .where((g) => g.data.isAfter(lunedi.subtract(Duration(days: 1))))
        .fold(0, (sum, g) => sum + minutiPrevisti(g.data));
  }

  bool esisteOggiInLista() {
    final oggi = DateTime.now();
    return giorni.any(
      (g) =>
          g.data.day == oggi.day &&
          g.data.month == oggi.month &&
          g.data.year == oggi.year,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    caricaGiorni();
    resettaSeLunedi();
  }

  Future<void> caricaGiorni() async {
    final prefs = await SharedPreferences.getInstance();
    final giorniString = prefs.getStringList('giorni') ?? [];
    setState(() {
      giorni = giorniString.map((s) {
        final parts = s.split('|');
        final data = DateTime.parse(parts[0]);
        final ingresso = parts[1] != 'null' ? _parseTime(parts[1]) : null;
        final uscita = parts[2] != 'null' ? _parseTime(parts[2]) : null;
        return Giorno(data, ingresso: ingresso, uscita: uscita);
      }).toList();
    });
  }

  Future<void> salvaGiorni() async {
    final prefs = await SharedPreferences.getInstance();
    final giorniString = giorni
        .map(
          (g) =>
              '${g.data.toIso8601String()}|${_formatTime(g.ingresso)}|${_formatTime(g.uscita)}',
        )
        .toList();
    await prefs.setStringList('giorni', giorniString);
  }

  String _formatTime(TimeOfDay? t) =>
      t == null ? 'null' : '${t.hour}:${t.minute}';
  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> resettaSeLunedi() async {
    final now = DateTime.now();
    if (now.weekday == DateTime.monday) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('giorni', []);
      setState(() {
        giorni = [];
      });
    }
  }

  List<Giorno> giorni = [];
  Giorno? giornoCorrente;
  bool ingressoSegnato = false;
  bool bloccaPulsante = false;

  @override
  void initState() {
    super.initState();
    giornoCorrente = Giorno(DateTime.now());
  }

  void segnaOrario() async {
    DateTime oggi = DateTime.now();
    // Sblocca il pulsante se è cambiato il giorno
    if (giornoCorrente != null &&
        (giornoCorrente!.data.day != oggi.day ||
            giornoCorrente!.data.month != oggi.month ||
            giornoCorrente!.data.year != oggi.year)) {
      giornoCorrente = Giorno(oggi);
      bloccaPulsante = false;
      ingressoSegnato = false;
    }
    if (bloccaPulsante) return;
    final now = TimeOfDay.now();
    setState(() {
      if (giornoCorrente!.ingresso == null) {
        giornoCorrente!.ingresso = now;
        ingressoSegnato = true;
      } else if (giornoCorrente!.uscita == null) {
        giornoCorrente!.uscita = now;
        giorni.add(giornoCorrente!);
        bloccaPulsante = true;
        ingressoSegnato = false;
      }
    });
    await salvaGiorni();
  }

  int minutiPrevisti(DateTime data) {
    return data.weekday == DateTime.friday ? 360 : 480;
  }

  int minutiEffettivi(Giorno g) {
    if (g.ingresso == null || g.uscita == null) return 0;
    final ingressoMin = g.ingresso!.hour * 60 + g.ingresso!.minute;
    final uscitaMin = g.uscita!.hour * 60 + g.uscita!.minute;
    return uscitaMin - ingressoMin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Badging'),
        backgroundColor: Colors.indigo,
        elevation: 4,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.indigo.shade200,
              Colors.white,
              Colors.indigo.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 18.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Text(
                          'Minuti settimana:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.indigo,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '${minutiEffettiviSettimana() - minutiPrevistiSettimana() >= 0 ? '+' : ''}${minutiEffettiviSettimana() - minutiPrevistiSettimana()} min',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color:
                                (minutiEffettiviSettimana() -
                                        minutiPrevistiSettimana()) >=
                                    0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: Size(140, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () async {
                        await resettaManuale();
                      },
                      icon: Icon(Icons.refresh, size: 28),
                      label: Text(
                        'Resetta settimana',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ingressoSegnato
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(140, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: (bloccaPulsante || esisteOggiInLista())
                          ? null
                          : segnaOrario,
                      icon: Icon(
                        ingressoSegnato ? Icons.logout : Icons.login,
                        size: 28,
                      ),
                      label: Text(
                        ingressoSegnato ? 'Segna Uscita' : 'Segna Ingresso',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Divider(thickness: 2),
                Expanded(
                  child: ListView.builder(
                    itemCount: giorni.length,
                    itemBuilder: (context, index) {
                      final giorniOrdinati = List<Giorno>.from(giorni)
                        ..sort((a, b) => b.data.compareTo(a.data));
                      final g = giorniOrdinati[index];
                      final minuti = minutiEffettivi(g);
                      final diff = minuti - minutiPrevisti(g.data);
                      return Card(
                        margin: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 2,
                        ),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.calendar_today,
                            color: Colors.indigo,
                            size: 32,
                          ),
                          title: Text(
                            '${g.data.day.toString().padLeft(2, '0')}/${g.data.month.toString().padLeft(2, '0')}/${g.data.year}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 2),
                              Text(
                                'Ingresso: ${g.ingresso?.format(context) ?? "--:--"}',
                                style: TextStyle(fontSize: 15),
                              ),
                              Text(
                                'Uscita:   ${g.uscita?.format(context) ?? "--:--"}',
                                style: TextStyle(fontSize: 15),
                              ),
                              SizedBox(height: 2),
                              Text(
                                diff == 0
                                    ? 'OK'
                                    : diff > 0
                                    ? '+$diff min'
                                    : '$diff min',
                                style: TextStyle(
                                  color: diff >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.edit,
                            color: Colors.indigo,
                            size: 28,
                          ),
                          onTap: () async {
                            final ingresso = await showTimePicker(
                              context: context,
                              initialTime:
                                  g.ingresso ?? TimeOfDay(hour: 9, minute: 0),
                              helpText: 'Modifica orario di INGRESSO',
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                );
                              },
                              initialEntryMode: TimePickerEntryMode.input,
                            );
                            if (ingresso != null) {
                              setState(() {
                                g.ingresso = ingresso;
                              });
                            }
                            final uscita = await showTimePicker(
                              context: context,
                              initialTime:
                                  g.uscita ?? TimeOfDay(hour: 17, minute: 0),
                              helpText: 'Modifica orario di USCITA',
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                );
                              },
                              initialEntryMode: TimePickerEntryMode.input,
                            );
                            if (uscita != null) {
                              setState(() {
                                g.uscita = uscita;
                              });
                            }
                            await salvaGiorni();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
