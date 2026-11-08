/// A reminder to send: [day] days from today, with [due] cards waiting then.
typedef Reminder = ({int day, int due});

/// Which of the coming days get a reminder, at most [perWeek] of them.
///
/// [forecast] is Stats.forecast: cards due on each day from today, today
/// (with anything overdue) first. A card stays due until reviewed, so each
/// day's count includes everything earlier. Days with nothing due get no
/// reminder, and neither does today once [todayOpen] is false (the reminder
/// time has passed).
List<Reminder> planReminders(List<int> forecast, {required int perWeek, required bool todayOpen}) {
  final plan = <Reminder>[];
  var due = 0;
  for (var day = 0; day < forecast.length && plan.length < perWeek; day++) {
    due += forecast[day];
    if (due > 0 && (day > 0 || todayOpen)) plan.add((day: day, due: due));
  }
  return plan;
}
