import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _UpdatePhase { idle, compiling, installing, failed }

/// In-app local rebuild: compile with live logs, then detach install (app quits).
class LocalUpdateDialog extends ConsumerStatefulWidget {
  const LocalUpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LocalUpdateDialog(),
    );
  }

  @override
  ConsumerState<LocalUpdateDialog> createState() => _LocalUpdateDialogState();
}

class _LisaSpeedRepo {
  _LisaSpeedRepo._(this.root);

  final String root;

  String get scriptPath => '$root/scripts/rebuild-and-install.command';
  String get appDir => '$root/hiddify-app';

  String get pathPrefix {
    final home = Platform.environment['HOME'] ?? '';
    final flutterBins = <String>[
      '/Users/ldy/flutter/bin',
      if (home.isNotEmpty) '$home/flutter/bin',
    ].where((dir) => File('$dir/flutter').existsSync() || File('$dir/dart').existsSync());
    final flutter = flutterBins.isEmpty ? '/Users/ldy/flutter/bin' : flutterBins.first;
    return '$flutter:${home.isEmpty ? '' : '$home/.pub-cache/bin:'}/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin';
  }

  static _LisaSpeedRepo? locate() {
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      if ((Platform.environment['LISASPEED_ROOT'] ?? '').isNotEmpty) Platform.environment['LISASPEED_ROOT']!,
      if (home.isNotEmpty) '$home/LisaSpeed',
      '/Users/ldy/LisaSpeed',
    ];
    for (final root in candidates) {
      final repo = _LisaSpeedRepo._(root);
      if (File(repo.scriptPath).existsSync()) return repo;
    }
    return null;
  }
}

class _LocalUpdateDialogState extends ConsumerState<LocalUpdateDialog> with InfraLogger {
  final _logCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  _UpdatePhase _phase = _UpdatePhase.idle;
  Process? _process;
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;

  @override
  void dispose() {
    _outSub?.cancel();
    _errSub?.cancel();
    _process?.kill();
    _logCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _append(String line) {
    if (!mounted) return;
    final next = _logCtrl.text.isEmpty ? line : '${_logCtrl.text}\n$line';
    _logCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Future<void> _startCompile() async {
    if (_phase == _UpdatePhase.compiling || _phase == _UpdatePhase.installing) return;

    final repo = _LisaSpeedRepo.locate();
    if (repo == null) {
      setState(() => _phase = _UpdatePhase.failed);
      _append('[[ERROR]] 找不到仓库（试过 \$HOME/LisaSpeed 与 /Users/ldy/LisaSpeed）');
      return;
    }

    setState(() => _phase = _UpdatePhase.compiling);
    _logCtrl.clear();
    _append('开始本地编译（离线依赖，不退出应用）…');
    _append('仓库：${repo.root}');

    try {
      final process = await Process.start(
        '/bin/bash',
        [repo.scriptPath, 'compile'],
        workingDirectory: repo.appDir,
        environment: {
          ...Platform.environment,
          'PATH': repo.pathPrefix,
          'GIT_SSL_NO_VERIFY': 'true',
          'COCOAPODS_DISABLE_STATS': 'true',
        },
      );
      _process = process;

      void handleLine(String line) {
        _append(line);
        if (line.contains('[[ERROR]]')) {
          if (mounted) setState(() => _phase = _UpdatePhase.failed);
        }
      }

      _outSub = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(handleLine);
      _errSub = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(handleLine);

      final code = await process.exitCode;
      _process = null;
      if (!mounted) return;
      if (code == 0 && _phase != _UpdatePhase.failed) {
        _append('编译完成，自动开始安装…');
        await _startInstall();
      } else if (_phase != _UpdatePhase.failed) {
        setState(() => _phase = _UpdatePhase.failed);
        _append('编译退出码：$code');
      }
    } catch (e, st) {
      loggy.error('local update compile failed', e, st);
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.failed);
      _append('[[ERROR]] $e');
    }
  }

  Future<void> _startInstall() async {
    if (_phase == _UpdatePhase.installing) return;
    setState(() => _phase = _UpdatePhase.installing);
    _append('启动分离安装进程（应用即将退出并自动重新打开）…');

    try {
      final repo = _LisaSpeedRepo.locate();
      if (repo == null) {
        setState(() => _phase = _UpdatePhase.failed);
        _append('[[ERROR]] 找不到仓库，无法安装');
        return;
      }
      // Fully detached so install survives LisaSpeed being killed.
      await Process.start(
        '/bin/bash',
        [repo.scriptPath, 'install'],
        workingDirectory: repo.appDir,
        mode: ProcessStartMode.detached,
        environment: {
          ...Platform.environment,
          'PATH': repo.pathPrefix,
        },
      );
      _append('安装进程已分离。若数秒后未自动退出，请手动关闭应用。');
    } catch (e, st) {
      loggy.error('local update install failed', e, st);
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.failed);
      _append('[[ERROR]] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider).requireValue;
    final accent = ConnectionButtonTheme.accentOf(context);
    final busy = _phase == _UpdatePhase.compiling || _phase == _UpdatePhase.installing;

    return TechDialog(
      title: t.pages.about.localUpdateTitle,
      icon: Icons.system_update_alt_rounded,
      width: 560,
      maxHeight: 560,
      scrollable: false,
      content: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.pages.about.localUpdateHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0B1220)
                      : const Color(0xFFF3F7FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
                ),
                // Desktop TextField already paints a scrollbar; wrapping another
                // Scrollbar without disabling the inherited one draws two thumbs.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: Scrollbar(
                    controller: _scrollCtrl,
                    thumbVisibility: true,
                    child: TextField(
                      controller: _logCtrl,
                      scrollController: _scrollCtrl,
                      readOnly: true,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.all(12),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: t.pages.about.localUpdateIdle,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['monospace'],
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (busy) ...[
              const Gap(10),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                  const Gap(10),
                  Text(
                    _phase == _UpdatePhase.installing
                        ? t.pages.about.localUpdateInstalling
                        : t.pages.about.localUpdateRunning,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TechDialogActions.text(
          context,
          label: t.common.addToClipboard,
          onPressed: busy ? null : () => Clipboard.setData(ClipboardData(text: _logCtrl.text)),
        ),
        TechDialogActions.cancel(
          context,
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          label: t.pages.about.localUpdateClose,
        ),
        if (_phase == _UpdatePhase.idle || _phase == _UpdatePhase.failed)
          TechDialogActions.ok(context, onPressed: _startCompile, label: t.pages.about.localUpdateStart),
      ],
    );
  }
}
