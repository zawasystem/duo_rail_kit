# Third-party notices

The package's MIT License does not replace the following notices for third-party
material. Font binaries are not copied into this repository or the pub.dev
archive; the documentation images contain rendered text and icons.

## Flutter platform templates — BSD 3-Clause

The iOS and Android hosts in `example/ios/` and `example/android/` were generated
from Flutter SDK 3.47.8 templates and adapted for this standalone example.
Their template-derived code and generated template assets retain Flutter's
license. Source: [Flutter templates](https://github.com/flutter/flutter/tree/master/packages/flutter_tools/templates).
The following notice is reproduced verbatim from that SDK's root `LICENSE`:

```text
Copyright 2014 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## Fonts used in documentation images

The renderer loads `Roboto-Regular.ttf` and `MaterialIcons-Regular.otf` from the
selected Flutter SDK's `bin/cache/artifacts/material_fonts/`. It does not download
replacement fonts or embed font files in the repository. The source files and
license files checked for these notices are in the
[Flutter material-font artifact](https://storage.googleapis.com/flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/fonts.zip),
selected by the SDK's `bin/internal/material_fonts.version`.

### Roboto — Apache License 2.0

- Creator: Google.
- Embedded font copyright: `Copyright 2011 Google Inc. All Rights Reserved.`
- Source file: `Roboto-Regular.ttf`; accompanying license: `Roboto_LICENSE.txt`.
- License: [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Roboto is used to render the example text in `doc/images/*.png`. The font file
is unchanged and is not distributed here. The rendered UI uses the example's
text, sizes, and colors.

### Material Icons — Creative Commons Attribution 4.0

- Creator: Google.
- Embedded font copyright: `Copyright 2019 Google LLC. All Rights Reserved.`
- Source file: `MaterialIcons-Regular.otf`; accompanying license:
  `MaterialIcons_LICENSE.txt`.
- License supplied with this exact Flutter artifact:
  [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/),
  with its [legal code](https://creativecommons.org/licenses/by/4.0/legalcode).

Material Icons glyphs are rasterized, scaled, and colored within the example UI
in `doc/images/*.png`. The font file and glyph outlines are not modified or
redistributed. The images' icon elements retain the supplied CC BY 4.0 terms;
the package's MIT notice does not replace them. Neither Google nor the Flutter
Authors endorse this package. The supplied license disclaims warranties; see
the linked legal code.

These notices describe the artifacts actually used, rather than assuming that
another version of Roboto or Material Icons has identical licensing. Recheck
the selected artifact's notices when changing the renderer's SDK or fonts.
