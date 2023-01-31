import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gantt_chart/gantt_chart.dart';

class BodyWidget extends StatefulWidget {
  /// The horizontal scroll controller that gets passed to the internal listview
  final ScrollController? scrollController;
  final WeekDay startOfTheWeek;
  final DateTime startDate;
  final int indexNice;
  final double dayWidth;
  final double? eventHeight;
  final double? weekHeaderHeight;
  final double? dayHeaderHeight;
  final bool showDays;
  final Widget Function(BuildContext context, DateTime date)? dayHeaderBuilder;
  final Widget Function(BuildContext context, DateTime weekDate)?
      weekHeaderBuilder;
  final Set<WeekDay> weekEnds;
  final IsExtraHolidayFunc? isExtraHoliday;
  final List<GanttEventBase> events;
  final Duration? maxDuration;
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

  /// Color to mark holiday
  final Color? holidayColor;
  final EventCellBuilderFunction? eventCellPerDayBuilder;

  BodyWidget(
      {required this.indexNice,
      required this.startDate,
      this.scrollController,
      required this.events,
      this.startOfTheWeek = WeekDay.sunday,
      this.weekEnds = const {WeekDay.friday, WeekDay.saturday},
      this.dayWidth = 30,
      this.isExtraHoliday,
      this.eventHeight,
      this.weekHeaderHeight,
      this.dayHeaderHeight,
      this.showDays = true,
      this.dayHeaderBuilder,
      this.weekHeaderBuilder,
      this.eventRowPerWeekBuilder,
      this.holidayColor,
      this.eventCellPerDayBuilder,
      this.maxDuration,
      super.key})
      : assert(
          !weekEnds.contains(startOfTheWeek),
          'startOfTheWeek must be a work day',
        );

  @override
  State<BodyWidget> createState() => _BodyWidgetState();
}

class _BodyWidgetState extends State<BodyWidget> {
  final extraHolidayCache = <DateTime>{};
  final eventColors = <Color>[];
  late ScrollController controller; // = ScrollController();

  bool isHolidayCached(BuildContext context, DateTime date) {
    if (widget.weekEnds.contains(WeekDay.fromDateTime(date))) return true;

    final dateOnly = DateUtils.dateOnly(date);
    if (extraHolidayCache.contains(dateOnly)) return true;
    if (widget.isExtraHoliday?.call(context, dateOnly) == true) {
      extraHolidayCache.add(dateOnly);
      return true;
    }
    return false;
  }

  double get weekWidth => widget.dayWidth * 7;
  late DateTime startDate;
  late DateTime weekOfStartDate;

  void initFromCurrentWidget() {
    eventColors.clear();
    eventColors.addAll(widget.events.mapIndexed((index, element) =>
        element.suggestedColor ??
        Colors.primaries[index % Colors.primaries.length]));
    controller = widget.scrollController ?? ScrollController();
    startDate = DateUtils.dateOnly(widget.startDate);
    weekOfStartDate = getWeekOf(widget.startOfTheWeek, startDate);
  }

  @override
  void initState() {
    super.initState();
    initFromCurrentWidget();
  }

  @override
  void didUpdateWidget(covariant BodyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newScrollController = widget.scrollController;
    final oldScrollController = oldWidget.scrollController;
    if (newScrollController != oldScrollController &&
        oldScrollController == null) {
      //moves from null to not-null, dispose self-created controller
      controller.dispose();
    }
    initFromCurrentWidget();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      // dispose self-created controller
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.startDate.add(Duration(days: widget.indexNice * 7));
    final weekDate = getWeekOf(widget.startOfTheWeek, date);
    //1) get week of startDate

    return SizedBox(
      width: weekWidth,
      child: Column(
        children: [
          //Week Header row
          SizedBox(
            height: widget.weekHeaderHeight,
            width: weekWidth,
            child: widget.weekHeaderBuilder?.call(context, weekDate) ??
                GanttChartDefaultWeekHeader(
                  weekDate: weekDate,
                ),
          ),
          if (widget.showDays)
            SizedBox(
              height: widget.dayHeaderHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < 7; i++)
                    //Header row
                    SizedBox(
                      width: widget.dayWidth,
                      child: widget.dayHeaderBuilder?.call(
                              context, weekDate.add(Duration(days: i))) ??
                          GanttChartDefaultDayHeader(
                            date: weekDate.add(Duration(days: i)),
                            isHoliday: isHolidayCached,
                          ),
                    ),
                ],
              ),
            ),

          //Body
          ...widget.events.mapIndexed(
            (index, e) {
              final actStartDate = e.getStartDateInclusive(
                context,
                widget.startDate,
                widget.weekEnds,
                isHolidayCached,
              );
              final actEndDate = e.getEndDateExeclusive(
                context,
                actStartDate,
                widget.weekEnds,
                isHolidayCached,
              );

              final eventColor = eventColors[index];
              return Container(
                decoration: BoxDecoration(
                    border: Border(
                  bottom: index == widget.events.length - 1
                      ? const BorderSide()
                      : BorderSide.none,
                )),
                height: widget.eventHeight,
                child: widget.eventRowPerWeekBuilder?.call(
                      context,
                      actStartDate,
                      actEndDate,
                      widget.dayWidth,
                      weekWidth,
                      weekDate,
                      isHolidayCached,
                      e,
                      eventColor,
                    ) ??
                    GanttChartDefaultEventRowPerWeekBuilder(
                      eventEndDate: actEndDate,
                      eventStartDate: actStartDate,
                      dayWidth: widget.dayWidth,
                      event: e,
                      isHolidayFunc: isHolidayCached,
                      weekDate: weekDate,
                      func: widget.eventCellPerDayBuilder,
                      holidayColor: widget.holidayColor,
                      eventColor: eventColor,
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
