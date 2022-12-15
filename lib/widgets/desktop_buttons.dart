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

import 'package:bluecherry_client/main.dart';
import 'package:bluecherry_client/providers/desktop_view_provider.dart';
import 'package:bluecherry_client/providers/home_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

final navigationStream = StreamController.broadcast();

class NObserver extends NavigatorObserver {
  void update(Route route) {
    // do not update if it's a popup
    if (route is PopupRoute) return;

    navigationStream.add(null);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    update(route);
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    update(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    update(route);
    super.didRemove(route, previousRoute);
  }
}

class WindowButtons extends StatefulWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tab = context.watch<HomeProvider>().tab;

    return StreamBuilder(
      stream: navigationStream.stream,
      builder: (child, _) {
        final canPop = navigatorKey.currentState?.canPop() ?? false;

        return Material(
          elevation: 0.0,
          color: theme.appBarTheme.backgroundColor,
          child: Row(children: [
            if (canPop)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                iconSize: 20.0,
                color: theme.hintColor,
                onPressed: () async {
                  await navigatorKey.currentState?.maybePop();
                  setState(() {});
                },
              ),
            const Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: 16.0),
                  child: Text('Bluecherry'),
                ),
              ),
            ),

            // if it's the grid tab
            if (tab == 0 && !canPop)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 8.0),
                child: _GridLayout(),
              ),
            SizedBox(
              width: 138,
              height: 40,
              child: WindowCaption(
                brightness: theme.brightness,
                backgroundColor: Colors.transparent,
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _GridLayout extends StatelessWidget {
  const _GridLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = context.watch<DesktopViewProvider>();

    return Row(
      children: DesktopLayoutType.values.map((type) {
        final selected = desktop.layoutType == type;

        return IconButton(
          icon: Icon(
            selected ? selectedIconForLayout(type) : iconForLayout(type),
          ),
          iconSize: 20.0,
          color: selected ? theme.primaryColor : theme.hintColor,
          onPressed: () async {
            desktop.setLayoutType(type);
          },
        );
      }).toList(),
    );
  }

  IconData iconForLayout(DesktopLayoutType type) {
    switch (type) {
      case DesktopLayoutType.singleView:
        return Icons.crop_square;
      case DesktopLayoutType.multipleView:
        return Icons.view_comfy_outlined;
      case DesktopLayoutType.compactView:
        return Icons.view_compact_outlined;
    }
  }

  IconData selectedIconForLayout(DesktopLayoutType type) {
    switch (type) {
      case DesktopLayoutType.singleView:
        return Icons.square_rounded;
      case DesktopLayoutType.multipleView:
        return Icons.view_comfy;
      case DesktopLayoutType.compactView:
        return Icons.view_compact;
    }
  }
}
