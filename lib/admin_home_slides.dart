import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_operations.dart';
import 'home_slides.dart';

class AdminHomeSlidesPage extends StatefulWidget {
  const AdminHomeSlidesPage({
    super.key,
    required this.client,
    required this.canEdit,
    this.gateway,
    this.verifyChange,
    this.chooseImage,
    this.saveImage,
  });
  final SupabaseClient client;
  final bool canEdit;
  final HomeSlidesGateway? gateway;
  final Future<bool> Function()? verifyChange;
  final Future<XFile?> Function()? chooseImage;
  final Future<void> Function(Uint8List bytes, String extension)? saveImage;
  @override
  State<AdminHomeSlidesPage> createState() => _AdminHomeSlidesPageState();
}

class _AdminHomeSlidesPageState extends State<AdminHomeSlidesPage> {
  late final HomeSlidesGateway gateway =
      widget.gateway ?? HomeSlidesGateway(widget.client);
  List<HomeSlide> slides = [];
  final title = TextEditingController();
  final keys = <String, GlobalKey>{};
  Uint8List? selected;
  String? mime, message;
  bool busy = false, loading = true, failed = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final rows = await gateway.load(admin: true);
      if (mounted) {
        setState(() {
          slides = rows;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          message = 'Unable to load slides. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choose() async {
    try {
      final file =
          await (widget.chooseImage?.call() ??
              openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'PNG or JPEG',
                    extensions: ['png', 'jpg', 'jpeg'],
                  ),
                ],
              ));
      if (file == null || !mounted) return;
      if (await file.length() > 524288) {
        throw const FormatException('Image too large');
      }
      final bytes = await file.readAsBytes();
      final type =
          bytes.length >= 8 &&
              bytes[0] == 137 &&
              bytes[1] == 80 &&
              bytes[2] == 78 &&
              bytes[3] == 71
          ? 'image/png'
          : bytes.length >= 3 &&
                bytes[0] == 255 &&
                bytes[1] == 216 &&
                bytes[2] == 255
          ? 'image/jpeg'
          : null;
      if (type == null) throw const FormatException('Invalid image');
      // Validate decoding and dimensions before preview or upload.
      await HomeSlide.parse({
        'id': 'preview',
        'kind': 'image',
        'title': 'Preview',
        'mime': type,
        'image_base64': base64Encode(bytes),
      });
      if (mounted) {
        setState(() {
          selected = bytes;
          mime = type;
          message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Choose a valid PNG or JPEG image up to 512 KB.',
        );
      }
    }
  }

  Future<void> change(Future<void> Function() action, String success) async {
    if (busy || !widget.canEdit) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (!await (widget.verifyChange?.call() ??
          verifyAdminMfa(context, widget.client))) {
        return;
      }
      if (!mounted) return;
      await action();
      if (!mounted) return;
      await reload();
      if (mounted && !failed) setState(() => message = success);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Unable to update slides. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    if (slides.where((slide) => slide.kind == 'image').length >= 8) {
      setState(
        () => message =
            'You can add up to eight images. Delete one before adding another.',
      );
      return;
    }
    final bytes = selected, type = mime, name = title.text.trim();
    if (bytes == null || type == null || name.isEmpty || name.length > 80) {
      setState(
        () => message =
            'Choose an image and enter a title (up to 80 characters).',
      );
      return;
    }
    await change(() async {
      await gateway.add(name, type, bytes);
      if (mounted) {
        title.clear();
        setState(() {
          selected = null;
          mime = null;
        });
      }
    }, 'Slide added.');
  }

  Future<void> download(HomeSlide slide) async {
    try {
      Uint8List bytes;
      String extension;
      if (slide.image != null) {
        bytes = slide.image!;
        extension = slide.mime == 'image/jpeg' ? 'jpg' : 'png';
      } else {
        final boundary =
            keys[slide.id]?.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null) throw StateError('Preview not ready');
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('Image unavailable');
          bytes = data.buffer.asUint8List();
        } finally {
          image.dispose();
        }
        extension = 'png';
      }
      if (widget.saveImage != null) {
        await widget.saveImage!(bytes, extension);
      } else {
        final path = await getSaveLocation(
          suggestedName: 'freelan-${slide.kind}.$extension',
          acceptedTypeGroups: [
            XTypeGroup(label: 'Image', extensions: [extension]),
          ],
        );
        if (path == null) return;
        await XFile.fromData(
          bytes,
          mimeType: extension == 'jpg' ? 'image/jpeg' : 'image/png',
        ).saveTo(path.path);
      }
      if (mounted) setState(() => message = 'Slide saved.');
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Unable to save the slide. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Home slideshow'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: busy ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Home slideshow',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage the slides shown on the user home page. Download any slide as an image.',
            ),
            const SizedBox(height: 20),
            if (widget.canEdit)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a slide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add up to eight PNG or JPEG images, each up to 512 KB. Wide images work best.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        maxLength: 80,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Slide title',
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : choose,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              selected == null
                                  ? 'Choose image'
                                  : 'Change image',
                            ),
                          ),
                          if (selected != null) const Text('Image selected'),
                          FilledButton.icon(
                            onPressed: busy ? null : upload,
                            icon: const Icon(Icons.add),
                            label: const Text('Add slide'),
                          ),
                        ],
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: AspectRatio(
                              aspectRatio: 2.25,
                              child: HomeSlideArt(
                                slide: HomeSlide(
                                  id: 'preview',
                                  kind: 'image',
                                  title: 'Preview',
                                  image: selected,
                                  mime: mime,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Semantics(liveRegion: true, child: Text(message!)),
              ),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (failed)
              TextButton(
                onPressed: busy ? null : reload,
                child: const Text('Retry'),
              )
            else ...[
              for (final slide in slides)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: RepaintBoundary(
                            key: keys.putIfAbsent(slide.id, () => GlobalKey()),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                aspectRatio: 2.25,
                                child: HomeSlideArt(slide: slide),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => download(slide),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download'),
                            ),
                            if (widget.canEdit)
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => change(
                                        () => gateway.setEnabled(
                                          slide,
                                          !slide.enabled,
                                        ),
                                        slide.enabled
                                            ? 'Slide hidden.'
                                            : 'Slide visible.',
                                      ),
                                icon: Icon(
                                  slide.enabled
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                label: Text(slide.enabled ? 'Hide' : 'Show'),
                              ),
                            if (widget.canEdit && slide.kind == 'image')
                              TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text(
                                                  'Delete slide?',
                                                ),
                                                content: Text(slide.title),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c, true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                        if (confirmed == true && mounted) {
                                          await change(
                                            () => gateway.delete(slide),
                                            'Slide deleted.',
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            if (widget.canEdit) ...[
                              IconButton(
                                tooltip: 'Move up',
                                onPressed: busy || slides.first.id == slide.id
                                    ? null
                                    : () => change(
                                        () => gateway.move(slide, -1),
                                        'Slide moved.',
                                      ),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                onPressed: busy || slides.last.id == slide.id
                                    ? null
                                    : () => change(
                                        () => gateway.move(slide, 1),
                                        'Slide moved.',
                                      ),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                            ],
                            Text(slide.enabled ? 'Visible' : 'Hidden'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
