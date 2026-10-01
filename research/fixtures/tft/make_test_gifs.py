#!/usr/bin/env python3
"""Write single-frame 320x172 GIF fixtures with Pillow.

Generating these files does not touch the keyboard. Pillow is only a local
authoring dependency for this fixture script.
"""

from pathlib import Path

from PIL import Image

WIDTH = 320
HEIGHT = 172
ROOT = Path(__file__).resolve().parent


def solid(color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGB", (WIDTH, HEIGHT), color)


def checkerboard(block: int = 4) -> Image.Image:
    if WIDTH % block or HEIGHT % block:
        raise ValueError("block size must divide 320 and 172")
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            pixels[x, y] = (255, 255, 255) if ((x // block) + (y // block)) & 1 else (0, 0, 0)
    return image


def main() -> None:
    images = {
        "black.gif": solid((0, 0, 0)),
        "red.gif": solid((255, 0, 0)),
        "green.gif": solid((0, 255, 0)),
        "blue.gif": solid((0, 0, 255)),
        "checkerboard.gif": checkerboard(),
    }
    for name, image in images.items():
        path = ROOT / name
        image.save(path, format="GIF", save_all=False)
        print(f"{name} {path.stat().st_size}")


if __name__ == "__main__":
    main()
