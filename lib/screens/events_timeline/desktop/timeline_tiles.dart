/*
 * This file is a part of Bluecherry Client (https://github.com/bluecherrydvr/unity).
 *
 * Copyright 2022 Bluecherry, LLC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:math';

import 'package:bluecherry_client/models/event.dart';
import 'package:bluecherry_client/providers/settings_provider.dart';
import 'package:bluecherry_client/screens/events_timeline/desktop/timeline.dart';
import 'package:bluecherry_client/utils/extensions.dart';
import 'package:bluecherry_client/widgets/misc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const kDeviceNameWidth = 100.0;
const kTimelineTileHeight = 30.0;
const kTimelineHoursHeight = 20.0;

class TimelineTiles extends StatefulWidget {
  final Timeline timeline;
  final ValueChanged<List<TimelineEvent>> onSelectionChanged;

  const TimelineTiles({
    super.key,
    required this.timeline,
    required this.onSelectionChanged,
  });

  @override
  State<TimelineTiles> createState() => _TimelineTilesState();
}

class _TimelineTilesState extends State<TimelineTiles> {
  final verticalScrollController = ScrollController();
  final reorderableViewKey = GlobalKey();

  Timeline get timeline => widget.timeline;
  Map<TimelineTile, GlobalKey> keys = {};
  GlobalKey keyForTile(TimelineTile tile) {
    return keys.putIfAbsent(tile, GlobalKey.new);
  }

  Map<GlobalKey, ScrollController> controllers = {};
  ScrollController controllerForTile(GlobalKey key) {
    return controllers.putIfAbsent(key, () {
      final controller = ScrollController();
      controller.addListener(() {
        if (timeline.zoomController.hasClients) {
          timeline.zoomController.jumpTo(controller.offset);
        }
      });
      return controller;
    });
  }

  final selectionAreaKey = GlobalKey();

  List<TimelineEvent> selectedEvents() {
    if (selectionAreaKey.currentContext == null) return [];
    assert(selectionAreaKey.currentContext != null);

    final selectedEvents = <TimelineEvent>[];

    final selectedAreaBox =
        selectionAreaKey.currentContext!.findRenderObject() as RenderBox;
    if (!selectedAreaBox.hasSize) return [];
    final selectedArea =
        selectedAreaBox.localToGlobal(Offset.zero) & selectedAreaBox.size;
    for (final tile in timeline.tiles) {
      final tileKey = keyForTile(tile);
      if (tileKey.currentContext == null) continue;
      final tileBox = tileKey.currentContext!.findRenderObject()! as RenderBox;
      final tilePosition = tileBox.localToGlobal(Offset.zero);
      final tileRect = tilePosition & tileBox.size;
      if (selectedArea.overlaps(tileRect)) {
        if (tileKey.currentState == null) continue;
        final tileWidget = tileKey.currentState! as _TimelineTileState;
        final events = tileWidget.eventsInRect(selectedArea);
        selectedEvents.addAll(events);
      }
    }

    return selectedEvents;
  }

  void clearSelection() {
    setState(() => _selectedArea = null);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.onSelectionChanged(selectedEvents());
    });
  }

  void updateSelection() {
    final events = selectedEvents();
    if (events.isEmpty) {
      clearSelection();
    } else {
      widget.onSelectionChanged(selectedEvents());
    }
  }

  bool _isSelecting = false;

  Offset _initialSelectionPoint = Offset.zero;
  Rect? _selectedArea;

  void selectArea(Offset globalPosition) {
    final renderBox =
        reorderableViewKey.currentContext!.findRenderObject()! as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);
    final dx = localPosition.dx;
    final dy = localPosition.dy;
    final x = min(dx, _initialSelectionPoint.dx);
    final y = min(dy, _initialSelectionPoint.dy);
    final width = max(dx, _initialSelectionPoint.dx) - x;
    final height = max(dy, _initialSelectionPoint.dy) - y;
    setState(() => _selectedArea = Rect.fromLTWH(x, y, width, height));
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    verticalScrollController.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (mounted) setState(() {});
    return false;
  }

  double get zoomOffset =>
      timeline.zoomController.hasClients
          ? timeline.zoomController.positions.last.pixels
          : 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < kTimelineTileHeight / 1.9) {
          return const SizedBox.shrink();
        }

        final tileWidth =
            (constraints.maxWidth - kDeviceNameWidth) * timeline.zoom;
        final hourWidth = tileWidth / 24;
        final secondsWidth = tileWidth / secondsInADay;

        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

        if (timeline.zoomController.hasClients) {
          for (final controller in controllers.values) {
            if (controller.hasClients) {
              controller.jumpTo(timeline.zoomController.offset);
            }
          }
        }

        return RepaintBoundary(
          child: Stack(
            fit: StackFit.passthrough,
            alignment: AlignmentDirectional.bottomCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: timeline.zoomController,
                    padding: const EdgeInsetsDirectional.only(
                      start: kDeviceNameWidth,
                    ),
                    physics: const NeverScrollableScrollPhysics(),
                    child: _TimelineHours(hourWidth: hourWidth),
                  ),
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown:
                          isShiftPressed
                              ? (details) {
                                if (HardwareKeyboard.instance.isShiftPressed) {
                                  _isSelecting = true;
                                  _initialSelectionPoint =
                                      details.localPosition;
                                }
                              }
                              : null,
                      onPanUpdate:
                          isShiftPressed || _isSelecting
                              ? (details) {
                                if (_isSelecting) {
                                  selectArea(details.globalPosition);
                                }
                              }
                              : null,
                      onPanEnd:
                          isShiftPressed || _isSelecting
                              ? (details) {
                                _isSelecting = false;
                                updateSelection();
                              }
                              : null,
                      child: EnforceScrollbarScroll(
                        controller: verticalScrollController,
                        onPointerSignal: _receivedPointerSignal,
                        child: ReorderableListView.builder(
                          key: reorderableViewKey,
                          scrollController: verticalScrollController,
                          itemCount: timeline.tiles.length,
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = timeline.tiles.removeAt(oldIndex);
                              timeline.tiles.insert(newIndex, item);
                              timeline.notify();
                            });
                          },
                          itemBuilder: (context, index) {
                            final tile = timeline.tiles[index];

                            return Row(
                              key: ValueKey(tile.device.uuid),
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: kDeviceNameWidth,
                                  child: ReorderableDragStartListener(
                                    index: index,
                                    child: _TimelineTile.name(tile: tile),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTapUp: (details) {
                                      if (isShiftPressed) {
                                        selectArea(details.globalPosition);
                                        if (_selectedArea != null) {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback(
                                                (_) => updateSelection(),
                                              );
                                          return;
                                        }
                                      }
                                      if (_selectedArea != null) {
                                        clearSelection();
                                      } else {
                                        _onMove(
                                          details.localPosition,
                                          constraints,
                                          tileWidth,
                                        );
                                      }
                                    },
                                    onHorizontalDragUpdate:
                                        isShiftPressed || _isSelecting
                                            ? null
                                            : (details) {
                                              if (_selectedArea != null) {
                                                clearSelection();
                                              } else {
                                                _onMove(
                                                  details.localPosition,
                                                  constraints,
                                                  tileWidth,
                                                );
                                              }
                                            },
                                    child: Builder(
                                      builder: (context) {
                                        return ScrollConfiguration(
                                          behavior: ScrollConfiguration.of(
                                            context,
                                          ).copyWith(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            scrollbars: false,
                                          ),
                                          child: SingleChildScrollView(
                                            controller: controllerForTile(
                                              keyForTile(tile),
                                            ),
                                            scrollDirection: Axis.horizontal,
                                            child: SizedBox(
                                              width: tileWidth,
                                              child: _TimelineTile(
                                                key: keyForTile(tile),
                                                tile: tile,
                                                selectedEvents:
                                                    selectedEvents(),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (timeline.zoomController.hasClients)
                Builder(
                  builder: (context) {
                    final left =
                        (timeline.currentPosition.inSeconds * secondsWidth) -
                        zoomOffset -
                        ( /* the width of half of the triangle */ 8 / 2);
                    if (left < -8.0) return const SizedBox.shrink();

                    final pointerColor = switch (theme.brightness) {
                      Brightness.light => theme.colorScheme.onSurface,
                      Brightness.dark => theme.colorScheme.onSurface,
                    };

                    return Positioned(
                      key: timeline.indicatorKey,
                      left: kDeviceNameWidth + left,
                      width: 8,
                      top: 12.0,
                      bottom: 0.0,
                      child: IgnorePointer(
                        child: Column(
                          children: [
                            ClipPath(
                              clipper: InvertedTriangleClipper(),
                              child: Container(
                                width: 8,
                                height: 4,
                                color: pointerColor,
                              ),
                            ),
                            Expanded(
                              child: Container(width: 1.8, color: pointerColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (_selectedArea != null)
                Positioned.fromRect(
                  key: selectionAreaKey,
                  rect: Rect.fromLTWH(
                    _selectedArea!.left,
                    _selectedArea!.top + kTimelineHoursHeight,
                    _selectedArea!.width,
                    _selectedArea!.height,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Handle mousewheel and web trackpad scroll events.
  void _receivedPointerSignal(PointerSignalEvent event) {
    if (widget.timeline.tiles.isEmpty) return;
    final double scaleChange;
    if (event is PointerScrollEvent) {
      if (event.kind == PointerDeviceKind.trackpad) {
        return;
      }
      // Ignore left and right mouse wheel scroll.
      if (event.scrollDelta.dy == 0.0) {
        return;
      }
      scaleChange = exp(event.scrollDelta.dy / 200);
    } else if (event is PointerScaleEvent) {
      scaleChange = event.scale;
    } else {
      return;
    }
    if (scaleChange < 1.0) {
      timeline.zoom -= 0.8;
    } else {
      timeline.zoom += 0.6;
    }
  }

  void _onMove(
    Offset localPosition,
    BoxConstraints constraints,
    double tileWidth,
  ) {
    if (!timeline.zoomController.hasClients ||
        localPosition.dx >= (constraints.maxWidth - kDeviceNameWidth)) {
      return;
    }
    final zoomOffset = timeline.zoomController.positions.last.pixels;
    final pointerPosition = (localPosition.dx + zoomOffset) / tileWidth;
    if (pointerPosition < 0 || pointerPosition > 1) {
      return;
    }

    final seconds = (secondsInADay * pointerPosition).round();
    final position = Duration(seconds: seconds);
    timeline.seekTo(position);

    if (timeline.zoom > 1.0) {
      // the position that the seeker will start moving
      // 100. removes it from the border
      final endPosition = constraints.maxWidth - kDeviceNameWidth - 100.0;
      if (localPosition.dx >= endPosition) {
        timeline.scrollTo(zoomOffset + 25.0);
      } else if (localPosition.dx <= 100.0) {
        timeline.scrollTo(zoomOffset - 25.0);
      }
    }
  }
}

class _TimelineTile extends StatefulWidget {
  final TimelineTile tile;
  final List<TimelineEvent> selectedEvents;

  const _TimelineTile({
    super.key,
    required this.tile,
    required this.selectedEvents,
  });

  static Widget name({required TimelineTile tile}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final border = Border(
          right: BorderSide(color: theme.disabledColor.withValues(alpha: 0.5)),
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        );

        return
        // Tooltip(
        //   message:
        //       '${tile.device.server.name}/${tile.device.name} (${tile.events.length})',
        //   preferBelow: false,
        //   textStyle: theme.textTheme.labelMedium?.copyWith(
        //     color: theme.colorScheme.onInverseSurface,
        //   ),
        // child:
        Container(
          width: kDeviceNameWidth,
          height: kTimelineTileHeight,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 5.0),
          decoration: BoxDecoration(
            color: theme.dialogTheme.backgroundColor,
            border: border,
          ),
          alignment: AlignmentDirectional.centerStart,
          child: DefaultTextStyle(
            style: theme.textTheme.labelMedium!,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    tile.device.name,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                  ),
                ),
                Text(
                  ' (${tile.events.length})',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
        // ,
        // );
      },
    );
  }

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile> {
  late final Map<Event, Color> colors;
  var secondWidth = 0.0;

  Map<TimelineEvent, GlobalKey> keys = {};
  GlobalKey keyForTile(TimelineEvent event) {
    return keys.putIfAbsent(event, GlobalKey.new);
  }

  @override
  void initState() {
    super.initState();
    colors = Map.fromIterables(
      widget.tile.events.map((e) => e.event),
      widget.tile.events.mapIndexed((index, _) {
        return [...Colors.primaries, ...Colors.accents][index %
            [...Colors.primaries, ...Colors.accents].length];
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    final border = Border(
      right: BorderSide(color: theme.disabledColor.withValues(alpha: 0.5)),
      top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(24, (index) {
          final hour = index;

          return Expanded(
            child: Container(
              height: kTimelineTileHeight,
              decoration: BoxDecoration(border: border),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!widget.tile.events.any(
                    (event) => event.startTime.hour == hour,
                  )) {
                    return const SizedBox.shrink();
                  }

                  secondWidth = constraints.maxWidth / 60 / 60;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final event in widget.tile.events.where(
                        (event) => event.startTime.hour == hour,
                      ))
                        PositionedDirectional(
                          key: keyForTile(event),
                          // the minute (in seconds) + the start second * the width of
                          // a second
                          start:
                              ((event.startTime.minute * 60) +
                                  event.startTime.second) *
                              secondWidth,
                          width: event.duration.inSeconds * secondWidth,
                          height: kTimelineTileHeight,
                          child: ColoredBox(
                            color:
                                widget.selectedEvents.contains(event)
                                    ? theme.colorScheme.tertiary
                                    : settings.kShowDebugInfo.value ||
                                        settings
                                            .kShowDifferentColorsForEvents
                                            .value
                                    ? colors[event.event] ??
                                        theme.colorScheme.primary
                                    : switch (event.event.type) {
                                      EventType.motion =>
                                        theme.colorScheme.secondary,
                                      _ => theme.colorScheme.primary,
                                    },
                            // color: theme.colorScheme.primary,
                            child:
                                settings.kShowDebugInfo.value
                                    ? Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        '${widget.tile.events.indexOf(event)}',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                    : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  List<TimelineEvent> eventsInRect(Rect rect) {
    final events = <TimelineEvent>[];
    for (final event in widget.tile.events) {
      final key = keyForTile(event);
      final renderBox = key.currentContext!.findRenderObject()! as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final eventRect = position & renderBox.size;
      if (rect.overlaps(eventRect)) {
        events.add(event);
      }
    }
    return events;
  }
}

class _TimelineHours extends StatelessWidget {
  /// The width of an hour
  final double hourWidth;
  const _TimelineHours({required this.hourWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final decWidth = hourWidth / 6;
    return SizedBox(
      height: kTimelineHoursHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ...List.generate(24, (index) {
            final hour = index + 1;
            final shouldDisplayHour = hour < 24;

            final hourWidget =
                shouldDisplayHour
                    ? Transform.translate(
                      offset: Offset(hour.toString().length * 4, 0.0),
                      child: Text(
                        '$hour',
                        style: theme.textTheme.labelMedium,
                        textAlign: TextAlign.end,
                      ),
                    )
                    : const SizedBox.shrink();

            if (decWidth > 25.0) {
              return SizedBox(
                width: hourWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ...List.generate(5, (index) {
                      return SizedBox(
                        width: decWidth,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Container(
                            height: 6.5,
                            width: 2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    hourWidget,
                  ],
                ),
              );
            }

            return SizedBox(width: hourWidth, child: hourWidget);
          }),
        ],
      ),
    );
  }
}
