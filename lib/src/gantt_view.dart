import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gantt_chart/gantt_chart.dart';
import 'package:gantt_chart/src/body_view.dart';

typedef IsExtraHolidayFunc = bool Function(BuildContext context, DateTime date);
typedef EventCellBuilderFunction = Widget Function(
  BuildContext context,
  DateTime eventStart,
  DateTime eventEnd,
  bool isHoliday,
  GanttEventBase event,
  DateTime day,
  Color eventColor,
);

/// Displays a gantt chart
class GanttChartView extends StatefulWidget {
  GanttChartView({
    Key? key,
    required this.events,
    required this.startDate,
    this.maxDuration,
    this.stickyAreaWidth = 200,
    this.stickyAreaEventBuilder,
    this.stickyAreaDayBuilder,
    this.stickyAreaWeekBuilder,
    this.showDays = true,
    this.dayWidth = 30,
    this.eventHeight = 30,
    this.weekHeaderHeight = 30,
    this.dayHeaderHeight = 40,
    this.weekEnds = const {WeekDay.friday, WeekDay.saturday},
    this.dayHeaderBuilder,
    this.weekHeaderBuilder,
    this.isExtraHoliday,
    this.eventRowPerWeekBuilder,
    this.startOfTheWeek = WeekDay.sunday,
    this.eventCellPerDayBuilder,
    this.holidayColor,
    this.showStickyArea = true,
  })  : assert(
          !weekEnds.contains(startOfTheWeek),
          'startOfTheWeek must be a work day',
        ),
        super(key: key);

  final Widget Function(
    BuildContext context,
    int eventIndex,
    GanttEventBase event,
    Color eventColor,
  )? stickyAreaEventBuilder;

  final WidgetBuilder? stickyAreaWeekBuilder;
  final WidgetBuilder? stickyAreaDayBuilder;

  /// Color to mark holiday
  final Color? holidayColor;

  /// Initial datetime
  final DateTime startDate;

  /// Maximum duration that will be displayed by the gantt chart
  final Duration? maxDuration;

  /// override this to check if specific date is a holiday
  final IsExtraHolidayFunc? isExtraHoliday;

  final List<GanttEventBase> events;

  final bool showDays;

  /// the week header builder (gets called for every week)
  ///
  /// [weekDate] is the start of the week, which will always be a [startOfTheWeek]
  final Widget Function(BuildContext context, DateTime weekDate)?
      weekHeaderBuilder;

  /// Show sticky row headers on the left
  final bool showStickyArea;

  /// Sticky area width
  final double stickyAreaWidth;

  /// the day header builder
  final Widget Function(BuildContext context, DateTime date)? dayHeaderBuilder;

  final Widget Function(
    BuildContext context,
    DateTime eventStart,
    DateTime eventEnd,
    double dayWidth,
    double weekWidth,
    DateTime weekStartDate,
    bool Function(BuildContext, DateTime) isHoliday,
    GanttEventBase event,
    Color eventColor,
  )? eventRowPerWeekBuilder;

  final EventCellBuilderFunction? eventCellPerDayBuilder;

  /// a set of [WeekDay]s which are considered holidays that occur every week
  ///
  /// by default are [WeekDay.friday], [WeekDay.saturday]
  final Set<WeekDay> weekEnds;

  /// First workday of the week, by default [WeekDay.sunday]
  final WeekDay startOfTheWeek;

  /// Day column width (in pixels)
  final double dayWidth;

  /// Event row height (in pixels)
  final double eventHeight;

  /// Week header row height (in pixels)
  final double weekHeaderHeight;

  /// Day header row height (in pixels)
  final double dayHeaderHeight;

  @override
  State<GanttChartView> createState() => GanttChartViewState();
}

class GanttChartViewState extends State<GanttChartView> {
  late ScrollController controller; // = ScrollController();
  final extraHolidayCache = <DateTime>{};

  Set<WeekDay> get weekEnds => widget.weekEnds;
  double get weekWidth => widget.dayWidth * 7;
  WeekDay get startOfTheWeek => widget.startOfTheWeek;

  late DateTime startDate;
  late DateTime weekOfStartDate;
  double durationToWeekOffset(Duration duration) {
    final inWeeks = duration.inDays ~/ 7;
    return inWeeks * weekWidth;
  }

  final eventColors = <Color>[];
  @override
  void initState() {
    super.initState();
    eventColors.clear();
    eventColors.addAll(widget.events.asMap().entries.map((e) =>
        e.value.suggestedColor ??
        Colors.primaries[e.key % Colors.primaries.length]));
    controller = ScrollController();
    startDate = DateUtils.dateOnly(widget.startDate);
    weekOfStartDate = getWeekOf(startOfTheWeek, startDate);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showStickyArea)
          SizedBox(
            width: widget.stickyAreaWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                //
                SizedBox(
                  height: widget.weekHeaderHeight,
                  child: widget.stickyAreaWeekBuilder?.call(context),
                ),
                if (widget.showDays)
                  SizedBox(
                    height: widget.dayHeaderHeight,
                    child: widget.stickyAreaDayBuilder?.call(context),
                  ),
                ...widget.events.mapIndexed((index, event) {
                  final eventColor = eventColors[index];
                  return SizedBox(
                    height: widget.eventHeight,
                    child: widget.stickyAreaEventBuilder
                            ?.call(context, index, event, eventColor) ??
                        Container(
                          decoration: BoxDecoration(
                            color: eventColors[index],
                            border: BorderDirectional(
                              top: index == 0
                                  ? const BorderSide()
                                  : BorderSide.none,
                              start: const BorderSide(),
                              end: const BorderSide(),
                              bottom: const BorderSide(),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              event.getDisplayName(context),
                            ),
                          ),
                        ),
                  );
                })
              ],
            ),
          ),
        Expanded(
          child: SizedBox(
            height: widget.weekHeaderHeight +
                (widget.showDays ? widget.dayHeaderHeight : 0) +
                (widget.eventHeight * widget.events.length),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              controller: controller,
              itemCount: widget.maxDuration == null
                  ? null
                  : (widget.maxDuration!.inDays / 7).ceil(),
              itemBuilder: (context, index) {
                return BodyWidget(
                  indexNice: index,
                  startDate: startDate,
                  events: widget.events,
                  dayWidth: widget.dayWidth,
                  eventHeight: 40,
                  weekEnds: widget.weekEnds,
                  isExtraHoliday: widget.isExtraHoliday,
                  startOfTheWeek: WeekDay.monday,
                  dayHeaderBuilder: widget.dayHeaderBuilder,
                  showDays: widget.showDays,
                  dayHeaderHeight: widget.dayHeaderHeight,
                  weekHeaderHeight: widget.weekHeaderHeight,
                  weekHeaderBuilder: widget.weekHeaderBuilder,
                  holidayColor: widget.holidayColor,
                  eventCellPerDayBuilder: widget.eventCellPerDayBuilder,
                  eventRowPerWeekBuilder: widget.eventRowPerWeekBuilder,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

DateTime getWeekOf(WeekDay startOfTheWeek, DateTime date) {
  var targetWeekday = WeekDay.fromDateTime(date);
  var diff = -((targetWeekday.number - startOfTheWeek.number) % 7);
  return date.add(Duration(days: diff));
}
