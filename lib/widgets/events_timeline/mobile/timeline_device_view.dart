import 'dart:async';

import 'package:bluecherry_client/providers/settings_provider.dart';
import 'package:bluecherry_client/utils/extensions.dart';
import 'package:bluecherry_client/widgets/device_selector_screen.dart';
import 'package:bluecherry_client/widgets/events_timeline/desktop/timeline.dart';
import 'package:bluecherry_client/widgets/misc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:unity_video_player/unity_video_player.dart';

const _kEventSeparatorWidth = 8.0;

class TimelineDeviceView extends StatefulWidget {
  const TimelineDeviceView({super.key, required this.timeline});

  final Timeline timeline;

  @override
  State<TimelineDeviceView> createState() => _TimelineDeviceViewState();
}

class _TimelineDeviceViewState extends State<TimelineDeviceView> {
  TimelineTile? tile;

  DateTime? currentDate;

  TimelineEvent? get currentEvent {
    assert(currentDate != null, 'There must be a date');
    return tile?.events.firstWhereOrNull((event) {
      return event.isPlaying(currentDate!);
    });
  }

  final controller = ScrollController();

  Future<void> selectDevice(BuildContext context) async {
    final device = await showDeviceSelectorScreen(
      context,
      available: widget.timeline.tiles.map((t) => t.device),
    );
    if (device != null) {
      // If there is already a selected device, dispose it
      tile?.videoController.dispose();
      tile = null;

      setState(() {
        tile = widget.timeline.tiles.firstWhere(
          (t) => t.device == device,
        );
        positionSubscription = tile!.videoController.onCurrentPosUpdate
            .listen(_tilePositionListener);
        currentDate = tile!.events.first.event.published;
        tile!.videoController.setDataSource(currentEvent!.videoUrl);
        tile!.videoController.onPlayingStateUpdate
            .listen((_) => _updateScreen());
      });
    }
  }

  StreamSubscription<Duration>? positionSubscription;
  Duration _lastPosition = Duration.zero;
  void _tilePositionListener(Duration position) {
    if (mounted) {
      setState(() {
        if (tile!.videoController.currentPos ==
            tile!.videoController.duration) {
          final currentIndex = tile!.events.indexOf(currentEvent!);
          if (currentIndex == tile!.events.length - 1) {
            return;
          }
          currentDate =
              tile!.events.elementAt(currentIndex + 1).event.published;
        } else {
          currentDate = currentDate!.add(position - _lastPosition);

          final eventsBefore = tile!.events.where(
            (e) => e.event.published.isBefore(currentEvent!.event.published),
          );

          final eventsFactor = currentEvent == tile!.events.first
              ? Duration.zero
              : eventsBefore.map((e) => e.duration).reduce((a, b) => a + b);

          controller.animateTo(
            // The scroll position is:
            //   + the position of the event
            //   + the position of the events before the current event
            //   + the width of the separators
            (eventsFactor.inSeconds +
                    currentEvent!.position(currentDate!).inSeconds +
                    eventsBefore.length * _kEventSeparatorWidth)
                .toDouble(),
            duration: position - _lastPosition,
            curve: Curves.linear,
          );

          _lastPosition = position;
        }
      });
    }
  }

  void _updateScreen() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tile?.videoController.dispose();
    positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: () {
            if (tile == null) {
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () => selectDevice(context),
                  child: const Center(child: Icon(Icons.add, size: 42.0)),
                ),
              );
            }

            return UnityVideoView(
              player: tile!.videoController,
              paneBuilder: (context, controller) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(children: [
                    if (kDebugMode)
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.labelMedium?.copyWith(
                            shadows: outlinedText(),
                          ),
                          children: [
                            TextSpan(
                              text: currentEvent
                                  ?.position(currentDate!)
                                  .humanReadableCompact(context),
                            ),
                            const TextSpan(text: '\ndebug: '),
                            TextSpan(
                              text: tile?.videoController.currentPos
                                  .humanReadableCompact(context),
                            ),
                            const TextSpan(text: '\nindex: '),
                            TextSpan(
                              text: tile?.events
                                  .indexOf(currentEvent!)
                                  .toString(),
                            ),
                            const TextSpan(text: '\nscroll: '),
                            if (this.controller.hasClients)
                              TextSpan(
                                text:
                                    this.controller.position.pixels.toString(),
                              ),
                          ],
                        ),
                      ),
                  ]),
                );
              },
            );
          }(),
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8.0),
        child: Center(
          child: Material(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 2.0,
              ),
              child: currentDate == null
                  ? const Text(' - ')
                  : Text(
                      '${SettingsProvider.instance.dateFormat.format(currentDate!)}'
                      ' '
                      '${timelineTimeFormat.format(currentDate!)}',
                      style: theme.textTheme.labelMedium,
                    ),
            ),
          ),
        ),
      ),
      Container(
        height: 48.0,
        color: theme.colorScheme.secondaryContainer,
        child: tile == null
            ? Center(
                child: Text(loc.selectACamera),
              )
            : Stack(children: [
                Positioned.fill(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(8.0),
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: _kEventSeparatorWidth),
                    scrollDirection: Axis.horizontal,
                    itemCount: tile!.events.length,
                    itemBuilder: (context, index) {
                      final event = tile!.events.elementAt(index);
                      return Container(
                        // every second is a pixel
                        width: event.duration.inSeconds.toDouble(),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSecondaryContainer,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8.0,
                        ),
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          event.duration.humanReadable(context),
                          style: const TextStyle(color: Colors.black),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 8.0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
              ]),
      ),
      const SizedBox(height: 14.0),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: () {},
        ),
        const SizedBox(width: 6.0),
        IconButton.filled(
          icon: Icon(
            (tile?.videoController.isPlaying ?? false)
                ? Icons.pause
                : Icons.play_arrow,
          ),
          iconSize: 32,
          onPressed: () {
            if (tile == null) return;

            if (tile!.videoController.isPlaying) {
              tile!.videoController.pause();
            } else {
              tile!.videoController.start();
            }
            setState(() {});
          },
        ),
        const SizedBox(width: 6.0),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: () {},
        ),
      ]),
      const Spacer(),
      if (tile != null)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '${tile!.device.fullName}\n'),
                if (currentEvent != null) ...[
                  TextSpan(
                    text: 'Duration: '
                        '${currentEvent!.duration.humanReadableCompact(context)}'
                        '\n',
                  ),
                  TextSpan(
                    text: 'Type: ${currentEvent!.event.type.locale(context)}\n',
                  ),
                ]
              ],
            ),
          ),
        ),
    ]);
  }
}
