#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun swiftc -warnings-as-errors src/keyboard/HIDDescriptor.swift tests/HIDDescriptorTests.swift -o .build/descriptor-tests
.build/descriptor-tests
xcrun swiftc -warnings-as-errors src/keyboard/TftUpload.swift tests/TftUploadTests.swift -o .build/tft-upload-tests
.build/tft-upload-tests
xcrun swiftc -warnings-as-errors -framework CoreGraphics -framework CoreText -framework ImageIO \
    src/display/TrackInfo.swift src/display/CanvasLayout.swift src/display/Renderer.swift \
    src/keyboard/TftUpload.swift tests/RendererTests.swift -o .build/renderer-tests
.build/renderer-tests
xcrun swiftc -warnings-as-errors -framework CoreGraphics -framework ImageIO \
    src/display/TrackInfo.swift src/spotify/LocalProvider.swift tests/SpotifyParseTests.swift -o .build/spotify-parse-tests
.build/spotify-parse-tests
xcrun swiftc -warnings-as-errors -framework CoreGraphics -framework CoreText -framework ImageIO \
    src/display/TrackInfo.swift src/display/CanvasLayout.swift src/display/Renderer.swift \
    src/spotify/LocalProvider.swift src/keyboard/TftUpload.swift src/app/DryRun.swift \
    tests/DryRunTests.swift -o .build/dry-run-tests
.build/dry-run-tests
xcrun swiftc -warnings-as-errors -framework CoreGraphics -framework CoreText -framework ImageIO \
    src/display/TrackInfo.swift src/display/CanvasLayout.swift src/display/Renderer.swift \
    src/spotify/LocalProvider.swift src/app/DryRun.swift src/app/Daemon.swift \
    src/keyboard/HIDDescriptor.swift src/keyboard/TftUpload.swift src/keyboard/TftTransport.swift \
    src/keyboard/RegistryInspector.swift src/cli/main.swift -o .build/rk-s98
.build/rk-s98 --help >/dev/null
if .build/rk-s98 info --vid invalid >.build/invalid-output.txt 2>.build/invalid-error.txt; then
    echo 'FAIL: invalid VID accepted' >&2
    exit 1
fi
if .build/rk-s98 info --unknown >.build/invalid-output.txt 2>.build/invalid-error.txt; then
    echo 'FAIL: unknown option accepted' >&2
    exit 1
fi
if .build/rk-s98 display test.png >.build/invalid-output.txt 2>.build/invalid-error.txt; then
    echo 'FAIL: unsupported command accepted' >&2
    exit 1
fi
if .build/rk-s98 upload-solid blue >.build/invalid-output.txt 2>.build/invalid-error.txt; then
    echo 'FAIL: upload without confirmation accepted' >&2
    exit 1
fi
if .build/rk-s98 render >.build/invalid-output.txt 2>.build/invalid-error.txt; then
    echo 'FAIL: render without --mock accepted' >&2
    exit 1
fi
if .build/rk-s98 daemon >.build/invalid-output.txt 2>.build/invalid-error.txt; then
    echo 'FAIL: daemon without --dry-run accepted' >&2
    exit 1
fi
.build/rk-s98 render --mock --output .build/preview.png
width=$(sips -g pixelWidth .build/preview.png | awk '/pixelWidth/ { print $2 }')
height=$(sips -g pixelHeight .build/preview.png | awk '/pixelHeight/ { print $2 }')
if [ "$width" != 320 ] || [ "$height" != 172 ]; then
    echo "FAIL: preview is ${width}x${height}" >&2
    exit 1
fi
printf '\205\005\165\010\225\100\261\002' >.build/test-descriptor.bin
.build/rk-s98 descriptor .build/test-descriptor.bin >.build/test-descriptor.json
.build/descriptor-tests .build/test-descriptor.json
printf '%s\n' 'PASS: CLI help, invalid arguments, unsupported command and offline JSON smoke checks'
