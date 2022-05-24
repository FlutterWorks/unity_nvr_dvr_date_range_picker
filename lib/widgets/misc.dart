/*
 * This file is a part of Bluecherry Client (https://https://github.com/bluecherrydvr/bluecherry_client).
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
import 'dart:io';

import 'package:flutter/material.dart';

const double kDesktopAppBarHeight = 64.0;
final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
final isMobile = Platform.isAndroid || Platform.isIOS;
final desktopTitleBarHeight = Platform.isWindows ? 0.0 : 0.0;

class NavigatorPopButton extends StatelessWidget {
  final Color? color;
  final void Function()? onTap;
  const NavigatorPopButton({Key? key, this.onTap, this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? Navigator.of(context).pop,
          borderRadius: BorderRadius.circular(20.0),
          child: SizedBox(
            height: 40.0,
            width: 40.0,
            child: Icon(
              Icons.arrow_back,
              size: 20.0,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopAppBar extends StatelessWidget {
  final String? title;
  final Widget? child;
  final Color? color;
  final Widget? leading;
  final double? height;
  final double? elevation;

  const DesktopAppBar({
    Key? key,
    this.title,
    this.child,
    this.color,
    this.leading,
    this.height,
    this.elevation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesktopTitleBar(
          color: color,
        ),
        ClipRect(
          child: ClipRect(
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: (height ?? kDesktopAppBarHeight) + 8.0,
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                animationDuration: Duration.zero,
                elevation: elevation ?? 4.0,
                color: color ?? Theme.of(context).appBarTheme.backgroundColor,
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    height: kDesktopAppBarHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        leading ??
                            NavigatorPopButton(
                              color: color != null
                                  ? isDark
                                      ? Colors.white
                                      : Colors.black
                                  : null,
                            ),
                        const SizedBox(
                          width: 16.0,
                        ),
                        if (title != null)
                          Text(
                            title!,
                            style:
                                Theme.of(context).textTheme.headline1?.copyWith(
                                    color: color != null
                                        ? isDark
                                            ? Colors.white
                                            : Colors.black
                                        : null),
                          ),
                        if (child != null)
                          SizedBox(
                            width: MediaQuery.of(context).size.width - 72.0,
                            child: child!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get isDark =>
      (0.299 * (color?.red ?? 256.0)) +
          (0.587 * (color?.green ?? 256.0)) +
          (0.114 * (color?.blue ?? 256.0)) <
      128.0;
}

class DesktopTitleBar extends StatelessWidget {
  final Color? color;
  const DesktopTitleBar({Key? key, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return Container(
        height: MediaQuery.of(context).padding.top,
        color: color ?? Theme.of(context).appBarTheme.backgroundColor,
      );
    }
    return
        // return Platform.isWindows
        //     ? Container(
        //         width: MediaQuery.of(context).size.width,
        //         height: desktopTitleBarHeight,
        //         color: color ?? Theme.of(context).appBarTheme.backgroundColor,
        //         child: Row(
        //           children: [
        //             Expanded(
        //               child: MoveWindow(
        //                 child: Row(
        //                   crossAxisAlignment: CrossAxisAlignment.center,
        //                   children: [
        //                     SizedBox(
        //                       width: 14.0,
        //                     ),
        //                     Text(
        //                       'Harmonoid Music',
        //                       style: TextStyle(
        //                         color: (color == null
        //                                 ? Theme.of(context).brightness ==
        //                                     Brightness.dark
        //                                 : isDark)
        //                             ? Colors.white
        //                             : Colors.black,
        //                         fontSize: 12.0,
        //                       ),
        //                     ),
        //                   ],
        //                 ),
        //               ),
        //             ),
        //             MinimizeWindowButton(
        //               colors: windowButtonColors(context),
        //             ),
        //             appWindow.isMaximized
        //                 ? RestoreWindowButton(
        //                     colors: windowButtonColors(context),
        //                   )
        //                 : MaximizeWindowButton(
        //                     colors: windowButtonColors(context),
        //                   ),
        //             CloseWindowButton(
        //               onPressed: () async {
        //                 if (!CollectionRefresh.instance.isCompleted) {
        //                   await showDialog(
        //                     context: context,
        //                     builder: (subContext) => AlertDialog(
        //                       title: Text(
        //                         Language.instance.WARNING,
        //                         style: Theme.of(subContext).textTheme.headline1,
        //                       ),
        //                       content: Text(
        //                         Language.instance.COLLECTION_INDEXING_LABEL,
        //                         style: Theme.of(subContext).textTheme.headline3,
        //                       ),
        //                       actions: [
        //                         MaterialButton(
        //                           textColor: Theme.of(context).primaryColor,
        //                           onPressed: Navigator.of(subContext).pop,
        //                           child: Text(Language.instance.OK),
        //                         ),
        //                       ],
        //                     ),
        //                   );
        //                 } else {
        //                   await Playback.instance.saveAppState();
        //                   if (Platform.isWindows) {
        //                     smtc.clear();
        //                     smtc.dispose();
        //                   }
        //                   appWindow.close();
        //                 }
        //               },
        //               colors: windowButtonColors(context),
        //             ),
        //           ],
        //         ),
        //       )
        //     :
        Container();
  }

  bool get isDark =>
      (0.299 * (color?.red ?? 256.0)) +
          (0.587 * (color?.green ?? 256.0)) +
          (0.114 * (color?.blue ?? 256.0)) <
      128.0;

  // WindowButtonColors windowButtonColors(BuildContext context) =>
  //     WindowButtonColors(
  //       iconNormal: (color == null
  //               ? Theme.of(context).brightness == Brightness.dark
  //               : isDark)
  //           ? Colors.white
  //           : Colors.black,
  //       iconMouseDown: (color == null
  //               ? Theme.of(context).brightness == Brightness.dark
  //               : isDark)
  //           ? Colors.white
  //           : Colors.black,
  //       iconMouseOver: (color == null
  //               ? Theme.of(context).brightness == Brightness.dark
  //               : isDark)
  //           ? Colors.white
  //           : Colors.black,
  //       normal: Colors.transparent,
  //       mouseOver: (color == null
  //               ? Theme.of(context).brightness == Brightness.dark
  //               : isDark)
  //           ? Colors.white.withOpacity(0.04)
  //           : Colors.black.withOpacity(0.04),
  //       mouseDown: (color == null
  //               ? Theme.of(context).brightness == Brightness.dark
  //               : isDark)
  //           ? Colors.white.withOpacity(0.04)
  //           : Colors.black.withOpacity(0.04),
  //     );
}
