import 'dart:async';
import 'dart:math';

import 'package:bluecherry_client/models/device.dart';
import 'package:bluecherry_client/models/event.dart';
import 'package:bluecherry_client/providers/settings_provider.dart';
import 'package:bluecherry_client/utils/extensions.dart';
import 'package:bluecherry_client/widgets/device_grid/device_grid.dart'
    show calculateCrossAxisCount;
import 'package:bluecherry_client/widgets/events_timeline/desktop/timeline_card.dart';
import 'package:bluecherry_client/widgets/events_timeline/desktop/timeline_sidebar.dart';
import 'package:bluecherry_client/widgets/events_timeline/events_playback.dart';
import 'package:bluecherry_client/widgets/reorderable_static_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:unity_video_player/unity_video_player.dart';

final timelineTimeFormat = DateFormat('hh:mm:ss a');

class TimelineTile {
  final Device device;
  final List<TimelineEvent> events;

  late final UnityVideoPlayer videoController;

  TimelineTile({
    required this.device,
    required this.events,
  }) {
    videoController = UnityVideoPlayer.create();
  }
}

class TimelineEvent {
  /// The duration of the event
  final Duration duration;

  /// When the event started
  final DateTime startTime;

  final String videoUrl;

  final Event event;

  TimelineEvent({
    required this.duration,
    required this.startTime,
    required this.event,
    this.videoUrl =
        'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4',
  });

  static List<TimelineEvent> get fakeData {
    return [
      TimelineEvent(
        duration: const Duration(minutes: 1),
        startTime: DateTime(2023).add(
          Duration(hours: Random().nextInt(4), minutes: Random().nextInt(60)),
        ),
        event: Event.dump(),
      ),
      TimelineEvent(
        duration: const Duration(hours: 1),
        startTime: DateTime(2023).add(Duration(hours: Random().nextInt(4) + 5)),
        event: Event.dump(),
      ),
      TimelineEvent(
        duration: const Duration(minutes: 1),
        startTime: DateTime(2023).add(Duration(hours: Random().nextInt(4) + 9)),
        event: Event.dump(),
      ),
      TimelineEvent(
        duration: const Duration(minutes: 1),
        startTime: DateTime(2023).add(
          Duration(
            hours: Random().nextInt(4) + 13,
            minutes: Random().nextInt(60),
          ),
        ),
        event: Event.dump(),
      ),
      TimelineEvent(
        duration: const Duration(minutes: 1),
        startTime: DateTime(2023).add(
          Duration(
            hours: Random().nextInt(4) + 14,
            minutes: Random().nextInt(60),
          ),
        ),
        event: Event.dump(),
      ),
      TimelineEvent(
        duration: const Duration(minutes: 1),
        startTime: DateTime(2023).add(
          Duration(
            hours: Random().nextInt(4) + 20,
            minutes: Random().nextInt(60),
          ),
        ),
        event: Event.dump(),
      ),
    ];
  }

  DateTime get endTime => startTime.add(duration);

  bool isPlaying(DateTime currentDate) {
    return currentDate.isInBetween(startTime, endTime);
  }

  /// The position of the video at the [currentDate]
  Duration position(DateTime currentDate) {
    return currentDate.difference(startTime);
  }
}

/// A timeline of events
///
/// Events are played as they happened in time. The timeline is limited to a
/// single day, so events are from hour 0 to 23.
class Timeline extends ChangeNotifier {
  /// Each tile of the timeline
  final List<TimelineTile> tiles = [];

  /// All the events must have happened in the same day
  final DateTime date;

  Timeline({required List<TimelineTile> tiles, required this.date}) {
    tiles.removeWhere((tile) => tile.events.isEmpty);
    add(tiles);

    for (final tile in tiles) {
      tile.videoController.onBufferUpdate.listen((_) => _eventCallback());
      tile.videoController.onDurationUpdate.listen((_) => _eventCallback());
      tile.videoController.onPlayingStateUpdate.listen((_) => _eventCallback());
    }
  }

  void _eventCallback() {
    notifyListeners();
  }

  Timeline.placeholder() : date = DateTime(2023);

  static Timeline get fakeTimeline {
    return Timeline(
      date: DateTime(2023),
      tiles: [
        TimelineTile(
          device: Device.dump(name: 'device1'),
          events: TimelineEvent.fakeData,
        ),
        TimelineTile(
          device: Device.dump(name: 'device2'),
          events: TimelineEvent.fakeData,
        ),
        TimelineTile(
          device: Device.dump(name: 'device3'),
          events: TimelineEvent.fakeData,
        ),
        TimelineTile(
          device: Device.dump(name: 'device4'),
          events: TimelineEvent.fakeData,
        ),
      ],
    );
  }

  void add(List<TimelineTile> tiles) {
    assert(tiles.every((tile) {
      return tile.events.every((event) =>
          event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day);
    }), 'All events must have happened in the same day');
    this.tiles.addAll(tiles);
    assert(
      this.tiles.length <= kMaxDevicesOnScreen,
      'There must be at most $kMaxDevicesOnScreen devices on screen',
    );
    notifyListeners();
  }

  void removeTile(TimelineTile tile) {
    tiles.remove(tile);
    notifyListeners();
  }

  void forEachEvent(
      void Function(TimelineTile tile, TimelineEvent event) callback) {
    for (var tile in tiles) {
      for (var event in tile.events) {
        callback(tile, event);
      }
    }
  }

  /// The current position of the timeline
  var currentPosition = const Duration();

  DateTime get currentDate => date.add(currentPosition);

  void seekTo(Duration position) {
    currentPosition = position;
    notifyListeners();

    forEachEvent((tile, event) {
      if (!event.isPlaying(currentDate)) return;
      tile.videoController.setDataSource(event.videoUrl);

      final position = event.position(currentDate);
      tile.videoController.seekTo(position);
      if (!isPlaying) tile.videoController.pause();

      debugPrint('Seeking ${tile.device} to $position');
    });
  }

  /// Seeks forward by [duration]
  void seekForward([Duration duration = const Duration(seconds: 15)]) =>
      seekTo(currentPosition + duration);

  /// Seeks backward by [duration]
  void seekBackward([Duration duration = const Duration(seconds: 15)]) =>
      seekTo(currentPosition - duration);

  double _volume = 1.0;
  bool get isMuted => volume == 0;
  double get volume => _volume;
  set volume(double value) {
    _volume = value;
    notifyListeners();

    for (final tile in tiles) {
      tile.videoController.setVolume(volume);
    }
  }

  double _speed = 1.0;
  double get speed => _speed;
  set speed(double value) {
    _speed = value;
    stop();
    notifyListeners();

    for (final tile in tiles) {
      tile.videoController.setSpeed(speed);
    }

    play();
  }

  double _zoom = 1.0;
  double get zoom => _zoom;
  set zoom(double value) {
    _zoom = value;
    notifyListeners();
  }

  Timer? timer;
  bool get isPlaying => timer != null && timer!.isActive;

  void stop() {
    if (timer == null) return;

    timer?.cancel();
    timer = null;

    for (final tile in tiles) {
      tile.videoController.pause();
    }
    notifyListeners();
  }

  void play() {
    timer ??= Timer.periodic(
      Duration(milliseconds: 1000 ~/ _speed),
      (timer) {
        currentPosition += const Duration(seconds: 1);
        notifyListeners();

        forEachEvent((tile, event) {
          if (event.isPlaying(currentDate)) {
            tile.videoController.seekTo(event.position(currentDate));
            tile.videoController.start();
          }
        });
      },
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    for (final tile in tiles) {
      tile.videoController.dispose();
    }
    super.dispose();
  }
}

const _kDeviceNameWidth = 100.0;
const _kTimelineTileHeight = 30.0;
final _minutesInADay = const Duration(days: 1).inMinutes;

class TimelineEventsView extends StatefulWidget {
  final Timeline? timeline;

  const TimelineEventsView({super.key, required this.timeline});

  @override
  State<TimelineEventsView> createState() => _TimelineEventsViewState();
}

class _TimelineEventsViewState extends State<TimelineEventsView> {
  double? _speed;
  double? _volume;

  @override
  void initState() {
    super.initState();
    widget.timeline?.addListener(_updateCallback);
  }

  void _updateCallback() {
    if (mounted) setState(() {});
  }

  Timeline get timeline => widget.timeline ?? Timeline.placeholder();

  @override
  void didUpdateWidget(covariant TimelineEventsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timeline != oldWidget.timeline) {
      oldWidget.timeline?.removeListener(_updateCallback);
      widget.timeline?.addListener(_updateCallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Column(children: [
      Expanded(
        child: Row(children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: StaticGrid(
                    padding: EdgeInsets.zero,
                    reorderable: false,
                    crossAxisCount: calculateCrossAxisCount(
                      timeline.tiles.length,
                    ),
                    onReorder: (a, b) {},
                    childAspectRatio: 16 / 9,
                    emptyChild: Center(child: Text(loc.noEventsFound)),
                    children: timeline.tiles.map((tile) {
                      return TimelineCard(tile: tile, timeline: timeline);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          TimelineSidebar(timeline: timeline),
        ]),
      ),
      Card(
        margin: const EdgeInsetsDirectional.only(
          start: 4.0,
          end: 4.0,
          bottom: 4.0,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(12.0),
            bottomStart: Radius.circular(12.0),
            bottomEnd: Radius.circular(12.0),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: 4.0,
              top: 2.0,
              start: 8.0,
              end: 8.0,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(_speed ?? timeline.speed) == 1.0 ? '1' : (_speed ?? timeline.speed).toStringAsFixed(1)}'
                      'x',
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120.0),
                      child: Slider(
                        value: _speed ?? timeline.speed,
                        min: 0.5,
                        max: 2.0,
                        onChanged: (s) => setState(() => _speed = s),
                        onChangeEnd: (s) {
                          _speed = null;
                          timeline.speed = s;
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20.0),
              IconButton(
                tooltip: timeline.isPlaying ? loc.pause : loc.play,
                icon: Icon(
                  timeline.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  setState(() {
                    if (timeline.isPlaying) {
                      timeline.stop();
                    } else {
                      timeline.play();
                    }
                  });
                },
              ),
              const SizedBox(width: 20.0),
              Expanded(
                child: Row(children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120.0),
                    child: Slider(
                      value:
                          _volume ?? (timeline.isMuted ? 0.0 : timeline.volume),
                      onChanged: (v) => setState(() => _volume = v),
                      onChangeEnd: (v) {
                        _volume = null;
                        timeline.volume = v;
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  Icon(() {
                    final volume = _volume ?? timeline.volume;
                    if ((_volume == null || _volume == 0.0) &&
                        (timeline.isMuted || volume == 0.0)) {
                      return Icons.volume_off;
                    } else if (volume < 0.5) {
                      return Icons.volume_down;
                    } else {
                      return Icons.volume_up;
                    }
                  }()),
                ]),
              ),
            ]),
          ),
          Text(
            '${SettingsProvider.instance.dateFormat.format(timeline.currentDate)} '
            '${timelineTimeFormat.format(timeline.currentDate)}',
          ),
          FractionallySizedBox(
            widthFactor: timeline.zoom,
            child: LayoutBuilder(builder: (context, constraints) {
              final minuteWidth =
                  (constraints.maxWidth - _kDeviceNameWidth) / _minutesInADay;

              return Stack(children: [
                Column(children: [
                  Row(children: [
                    const SizedBox(width: _kDeviceNameWidth),
                    ...List.generate(24, (index) {
                      final hour = index + 1;
                      if (hour == 24) {
                        return const Expanded(child: SizedBox.shrink());
                      }

                      return Expanded(
                        child: Transform.translate(
                          offset: Offset(
                            hour.toString().length * 4,
                            0.0,
                          ),
                          child: Text(
                            '$hour',
                            style: theme.textTheme.labelMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      );
                    }),
                  ]),
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final pointerPosition =
                          (details.localPosition.dx - _kDeviceNameWidth) /
                              (constraints.maxWidth - _kDeviceNameWidth);
                      if (pointerPosition < 0 || pointerPosition > 1) return;

                      final minutes =
                          (_minutesInADay * pointerPosition).round();
                      final position = Duration(minutes: minutes);
                      timeline.seekTo(position);
                    },
                    child: Column(children: [
                      ...timeline.tiles.map((tile) {
                        return _TimelineTile(
                          key: ValueKey(tile),
                          tile: tile,
                        );
                      }),
                    ]),
                  )
                ]),
                Positioned(
                  left: (timeline.currentPosition.inMinutes * minuteWidth) +
                      _kDeviceNameWidth,
                  width: 1.8,
                  top: 16.0,
                  height: _kTimelineTileHeight * timeline.tiles.length,
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ),
              ]);
            }),
          ),
        ]),
      ),
    ]);
  }
}

class _TimelineTile extends StatelessWidget {
  final TimelineTile tile;

  const _TimelineTile({super.key, required this.tile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final border = Border(
      right: BorderSide(color: theme.disabledColor.withOpacity(0.5)),
      top: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
    );

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: _kDeviceNameWidth,
        height: _kTimelineTileHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: theme.dialogBackgroundColor,
          border: border,
        ),
        alignment: AlignmentDirectional.centerStart,
        child: RichText(
          maxLines: 1,
          text: TextSpan(
            style: theme.textTheme.labelMedium,
            children: [
              TextSpan(text: tile.device.name),
              TextSpan(
                text: ' (${tile.events.length})',
                style: const TextStyle(fontSize: 11.0),
              ),
            ],
          ),
        ),
      ),
      ...List.generate(24, (index) {
        final hour = index;

        return Expanded(
          child: Container(
            height: _kTimelineTileHeight,
            decoration: BoxDecoration(border: border),
            child: LayoutBuilder(builder: (context, constraints) {
              if (!tile.events.any((event) => event.startTime.hour == hour)) {
                return const SizedBox.shrink();
              }

              final minuteWidth = constraints.maxWidth / 60;
              return Stack(clipBehavior: Clip.none, children: [
                for (final event in tile.events
                    .where((event) => event.startTime.hour == hour))
                  Positioned(
                    left: event.startTime.minute * minuteWidth,
                    width: event.duration.inMinutes * minuteWidth,
                    height: _kTimelineTileHeight,
                    child: ColoredBox(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ]);
            }),
          ),
        );
      }),
    ]);
  }
}
