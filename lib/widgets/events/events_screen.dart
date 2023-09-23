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

import 'dart:async';
import 'dart:io';

import 'package:bluecherry_client/api/api.dart';
import 'package:bluecherry_client/models/event.dart';
import 'package:bluecherry_client/models/server.dart';
import 'package:bluecherry_client/providers/downloads_provider.dart';
import 'package:bluecherry_client/providers/home_provider.dart';
import 'package:bluecherry_client/providers/server_provider.dart';
import 'package:bluecherry_client/providers/settings_provider.dart';
import 'package:bluecherry_client/utils/constants.dart';
import 'package:bluecherry_client/utils/extensions.dart';
import 'package:bluecherry_client/utils/methods.dart';
import 'package:bluecherry_client/utils/widgets/tree_view.dart';
import 'package:bluecherry_client/widgets/desktop_buttons.dart';
import 'package:bluecherry_client/widgets/downloads_manager.dart';
import 'package:bluecherry_client/widgets/error_warning.dart';
import 'package:bluecherry_client/widgets/events/event_player_desktop.dart';
import 'package:bluecherry_client/widgets/misc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unity_video_player/unity_video_player.dart';

part 'event_player_mobile.dart';
part 'events_screen_desktop.dart';
part 'events_screen_mobile.dart';

typedef EventsData = Map<Server, Iterable<Event>>;

final eventsScreenKey = GlobalKey<EventsScreenState>();

class EventsScreen extends StatefulWidget {
  const EventsScreen({required super.key});

  @override
  State<EventsScreen> createState() => EventsScreenState<EventsScreen>();
}

class EventsScreenState<T extends StatefulWidget> extends State<T> {
  DateTime? startTime, endTime;
  EventsMinLevelFilter levelFilter = EventsMinLevelFilter.any;
  Set<Server> allowedServers = {};

  final EventsData events = {};
  Map<Server, bool> invalid = {};

  Iterable<Event> filteredEvents = [];

  /// The devices that can't be displayed in the list.
  ///
  /// The rtsp url is used to identify the device.
  Set<String> disabledDevices = {
    for (final server in ServersProvider.instance.servers)
      ...server.devices.map((d) => d.rtspURL)
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => fetch());
  }

  /// Fetches the events from the servers.
  Future<void> fetch() async {
    events.clear();
    filteredEvents = [];
    final home = context.read<HomeProvider>()
      ..loading(UnityLoadingReason.fetchingEventsHistory);
    try {
      // Load the events at the same time
      await Future.wait(ServersProvider.instance.servers.map((server) async {
        if (!server.online || !allowedServers.contains(server)) return;

        try {
          final allowedDevices = server.devices
              .where((d) => d.status && !disabledDevices.contains(d.rtspURL));

          // Perform a query for each selected device
          await Future.wait(allowedDevices.map((device) async {
            final iterable = await API.instance.getEvents(
              await API.instance.checkServerCredentials(server),
              startTime: startTime,
              endTime: endTime,
              device: device,
            );
            if (mounted) {
              super.setState(() {
                events[server] ??= [];
                events[server] = [...events[server]!, ...iterable];
                invalid[server] = false;
              });
            }
          }));
        } catch (exception, stacktrace) {
          debugPrint(exception.toString());
          debugPrint(stacktrace.toString());
          invalid[server] = true;
        }
      }));
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }

    await computeFiltered();

    home.notLoading(UnityLoadingReason.fetchingEventsHistory);
  }

  Future<void> computeFiltered() async {
    filteredEvents = await compute(_updateFiltered, {
      'events': events,
      'allowedServers': allowedServers,
      'levelFilter': levelFilter,
      'disabledDevices': disabledDevices,
    });
  }

  static Iterable<Event> _updateFiltered(Map<String, dynamic> data) {
    final events = data['events'] as EventsData;
    final allowedServers = data['allowedServers'] as Set<Server>;
    final levelFilter = data['levelFilter'] as EventsMinLevelFilter;
    final disabledDevices = data['disabledDevices'] as Set<String>;

    return events.values.expand((events) sync* {
      for (final event in events) {
        // allow events from the allowed servers
        if (!allowedServers.any((element) => event.server.ip == element.ip)) {
          continue;
        }

        switch (levelFilter) {
          case EventsMinLevelFilter.alarming:
            if (!event.isAlarm) continue;
            break;
          case EventsMinLevelFilter.warning:
            if (event.priority != EventPriority.warning) continue;
            break;
          default:
            break;
        }

        // This is hacky. Maybe find a way to move this logic to [API.getEvents]
        // It'd also be useful to find a way to get the device at Event creation time
        final devices = event.server.devices.where((device) =>
            device.name.toLowerCase() == event.deviceName.toLowerCase());
        if (devices.isNotEmpty) {
          if (disabledDevices.contains(devices.first.rtspURL)) continue;
        }

        yield event;
      }
    });
  }

  /// We override setState because we need to update the filtered events
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // computes the events based on the filter, then update the screen
    computeFiltered().then((_) {
      if (mounted) super.setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ServersProvider.instance.servers.isEmpty) {
      return const NoServerWarning();
    }

    final hasDrawer = Scaffold.hasDrawer(context);
    final loc = AppLocalizations.of(context);
    final isLoading = HomeProvider.instance.isLoadingFor(
      UnityLoadingReason.fetchingEventsHistory,
    );

    return LayoutBuilder(builder: (context, consts) {
      if (hasDrawer || consts.maxWidth < kMobileBreakpoint.width) {
        return EventsScreenMobile(
          events: filteredEvents,
          loadedServers: events.keys,
          refresh: fetch,
          invalid: invalid,
          showFilter: () => showMobileFilter(context),
        );
      }

      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 220,
          child: Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(),
            child: SafeArea(
              child: DropdownButtonHideUnderline(
                child: Column(children: [
                  SubHeader(
                    loc.servers,
                    height: 38.0,
                    trailing: Text(
                      '${ServersProvider.instance.servers.length}',
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: EventsDevicesPicker(
                        events: events,
                        disabledDevices: disabledDevices,
                        allowedServers: allowedServers,
                        onServerAdded: (server) =>
                            setState(() => allowedServers.add(server)),
                        onServerRemoved: (server) =>
                            setState(() => allowedServers.remove(server)),
                        onDisabledDeviceAdded: (device) =>
                            setState(() => disabledDevices.add(device)),
                        onDisabledDeviceRemoved: (device) =>
                            setState(() => disabledDevices.remove(device)),
                      ),
                    ),
                  ),
                  SubHeader(loc.timeFilter, height: 24.0),
                  buildTimeFilterTile(),
                  // const SubHeader('Minimum level', height: 24.0),
                  // DropdownButton<EventsMinLevelFilter>(
                  //   isExpanded: true,
                  //   value: levelFilter,
                  //   items: EventsMinLevelFilter.values.map((level) {
                  //     return DropdownMenuItem(
                  //       value: level,
                  //       child: Text(level.name.uppercaseFirst()),
                  //     );
                  //   }).toList(),
                  //   onChanged: (v) => setState(
                  //     () => levelFilter = v ?? levelFilter,
                  //   ),
                  // ),
                  const SizedBox(height: 8.0),
                  FilledButton(
                    onPressed: isLoading ? null : fetch,
                    child: Text(loc.filter),
                  ),
                  const SizedBox(height: 12.0),
                ]),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: EventsScreenDesktop(events: filteredEvents)),
      ]);
    });
  }

  Widget buildTimeFilterTile({VoidCallback? onSelect}) {
    return Builder(builder: (context) {
      final loc = AppLocalizations.of(context);
      return ListTile(
        title: Text(() {
          final formatter = DateFormat.MEd();
          if (startTime == null || endTime == null) {
            return loc.today;
          } else if (DateUtils.isSameDay(startTime, endTime)) {
            return formatter.format(startTime!);
          } else {
            return loc.fromToDate(
              formatter.format(startTime!),
              formatter.format(endTime!),
            );
          }
        }()),
        onTap: () async {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(1970),
            lastDate: DateTime.now(),
            initialEntryMode: DatePickerEntryMode.calendarOnly,
          );
          if (range != null) {
            startTime = range.start;
            endTime = range.end;
            onSelect?.call();
          }
        },
      );
    });
  }

  Future<void> showMobileFilter(BuildContext context) async {
    /// This is used to update the screen when the bottom sheet is closed.
    var hasChanged = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.85,
          initialChildSize: 0.85,
          builder: (context, controller) {
            final loc = AppLocalizations.of(context);
            return ListView(controller: controller, children: [
              SubHeader(loc.timeFilter, height: 20.0),
              buildTimeFilterTile(onSelect: () => hasChanged = true),
              // const SubHeader('Minimum level'),
              // DropdownButtonHideUnderline(
              //   child: DropdownButton<EventsMinLevelFilter>(
              //     isExpanded: true,
              //     value: levelFilter,
              //     items: EventsMinLevelFilter.values.map((level) {
              //       return DropdownMenuItem(
              //         value: level,
              //         child: Text(level.name.uppercaseFirst()),
              //       );
              //     }).toList(),
              //     onChanged: (v) => setState(
              //       () => levelFilter = v ?? levelFilter,
              //     ),
              //   ),
              // ),
              SubHeader(loc.servers, height: 36.0),
              EventsDevicesPicker(
                events: events,
                disabledDevices: disabledDevices,
                allowedServers: allowedServers,
                gapCheckboxText: 10.0,
                checkboxScale: 1.15,
                onServerAdded: (server) =>
                    setState(() => allowedServers.add(server)),
                onServerRemoved: (server) =>
                    setState(() => allowedServers.remove(server)),
                onDisabledDeviceAdded: (device) =>
                    setState(() => disabledDevices.add(device)),
                onDisabledDeviceRemoved: (device) =>
                    setState(() => disabledDevices.remove(device)),
              ),
            ]);
          },
        );
      },
    );

    if (hasChanged) fetch();
  }
}

enum EventsMinLevelFilter {
  any,
  info,
  warning,
  alarming,
  critical,
}

class EventsDevicesPicker extends StatelessWidget {
  final EventsData events;
  final Set<String> disabledDevices;
  final Set<Server> allowedServers;
  final double checkboxScale;
  final double gapCheckboxText;

  final ValueChanged<Server> onServerAdded;
  final ValueChanged<Server> onServerRemoved;
  final ValueChanged<String> onDisabledDeviceAdded;
  final ValueChanged<String> onDisabledDeviceRemoved;

  const EventsDevicesPicker({
    super.key,
    required this.events,
    required this.disabledDevices,
    required this.allowedServers,
    required this.onServerAdded,
    required this.onServerRemoved,
    required this.onDisabledDeviceAdded,
    required this.onDisabledDeviceRemoved,
    this.checkboxScale = 0.8,
    this.gapCheckboxText = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServersProvider>();

    return TreeView(
      indent: 56,
      iconSize: 18.0,
      nodes: servers.servers.map((server) {
        final isTriState = disabledDevices
            .any((d) => server.devices.any((device) => device.rtspURL == d));
        final isOffline = !server.online;
        final serverEvents = events[server];

        return TreeNode(
          content: buildCheckbox(
            value: !allowedServers.contains(server) || isOffline
                ? false
                : isTriState
                    ? null
                    : true,
            isError: isOffline,
            onChanged: (v) {
              if (isTriState) {
                disabledDevices
                    .where((d) =>
                        server.devices.any((device) => device.rtspURL == d))
                    .forEach(onDisabledDeviceRemoved);
              } else if (v == null || !v) {
                onServerRemoved(server);
              } else {
                onServerAdded(server);
              }
            },
            checkboxScale: checkboxScale,
            text: server.name,
            secondaryText: isOffline ? null : '${server.devices.length}',
            gapCheckboxText: gapCheckboxText,
            textFit: FlexFit.tight,
          ),
          children: () {
            if (isOffline) {
              return <TreeNode>[];
            } else {
              return server.devices.sorted().map((device) {
                final enabled = isOffline || !allowedServers.contains(server)
                    ? false
                    : !disabledDevices.contains(device.rtspURL);
                final eventsForDevice =
                    serverEvents?.where((event) => event.deviceID == device.id);
                return TreeNode(
                  content: IgnorePointer(
                    ignoring: !device.status,
                    child: buildCheckbox(
                      value: device.status ? enabled : false,
                      isError: !device.status,
                      onChanged: (v) {
                        if (!device.status) return;

                        if (!allowedServers.contains(server)) {
                          onServerAdded(server);
                        }

                        if (enabled) {
                          onDisabledDeviceAdded(device.rtspURL);
                        } else {
                          onDisabledDeviceRemoved(device.rtspURL);
                        }
                      },
                      checkboxScale: checkboxScale,
                      text: device.name,
                      secondaryText: eventsForDevice != null && device.status
                          ? ' (${eventsForDevice.length})'
                          : null,
                      gapCheckboxText: gapCheckboxText,
                    ),
                  ),
                );
              }).toList();
            }
          }(),
        );
      }).toList(),
    );
  }
}
