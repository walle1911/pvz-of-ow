#!/usr/bin/env python3
"""
帧序列资产导入/清理工具。

用法:
  # 1) 清理已有帧目录: 把 alpha==0 的像素 RGB 置零, 消除白底残留导致的"白色方块"。
  python3 import_frame_sequences.py clean <frame_dir>

  # 2) 从 GIF 抽帧并清理 (GIF 无真 alpha, 抽帧常残留白底, 必须清理)。
  python3 import_frame_sequences.py gif <input.gif> <out_dir> [--frames N] [--pad WxH]

  # 3) 从雪碧图按行优先切帧并清理。
  python3 import_frame_sequences.py sheet <sheet.png> <out_dir> --cols C --rows R [--frame-w W --frame-h H] [--count N]

说明:
  - 所有模式都会做 "alpha 预清理": alpha==0 的像素 RGB 一律置 (0,0,0)。
    这是消除游戏内白色方块的关键 —— Godot 的 fix_alpha_border 与双线性缩放
    会把透明像素的 RGB 泄漏到角色边缘, 若透明区残留白色 RGB 就会显出白块。
  - 输出文件名固定为 000.png, 001.png ... 便于脚本按 %03d 顺序加载。
"""

import argparse
import os
import sys

try:
    from PIL import Image, ImageSequence
except ImportError:
    sys.stderr.write("缺少 Pillow, 请先运行: pip3 install Pillow\n")
    sys.exit(1)


def clean_alpha(im: Image.Image) -> Image.Image:
    """alpha==0 的像素 RGB 置零, 返回 RGBA 副本。"""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    cleaned = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 and (r or g or b):
                px[x, y] = (0, 0, 0, 0)
                cleaned += 1
    return im, cleaned


def save_frame(im: Image.Image, out_dir: str, index: int) -> str:
    os.makedirs(out_dir, exist_ok=True)
    name = f"{index:03d}.png"
    path = os.path.join(out_dir, name)
    im.save(path, "PNG")
    return path


def cmd_clean(args):
    total_files = 0
    total_pixels = 0
    for root, _dirs, files in os.walk(args.dir):
        for f in sorted(files):
            if not f.lower().endswith(".png"):
                continue
            path = os.path.join(root, f)
            im = Image.open(path)
            im, cleaned = clean_alpha(im)
            im.save(path, "PNG")
            total_files += 1
            total_pixels += cleaned
            flag = f" (-{cleaned})" if cleaned else ""
            print(f"  cleaned {os.path.relpath(path, args.dir)}{flag}")
    print(f"完成: {total_files} 个文件, 清理 {total_pixels} 个残留像素。")


def cmd_gif(args):
    gif = Image.open(args.gif)
    frames = [f.convert("RGBA") for f in ImageSequence.Iterator(gif)]
    if args.frames and args.frames < len(frames):
        # 均匀采样到目标帧数
        step = len(frames) / args.frames
        frames = [frames[int(i * step)] for i in range(args.frames)]
    count = 0
    total = 0
    for i, f in enumerate(frames):
        if args.pad:
            pw, ph = args.pad
            canvas = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
            ox = (pw - f.width) // 2
            oy = (ph - f.height) // 2
            canvas.paste(f, (ox, oy), f)
            f = canvas
        f, cleaned = clean_alpha(f)
        total += cleaned
        save_frame(f, args.out_dir, i)
        count += 1
    print(f"完成: 抽出 {count} 帧, 清理 {total} 个残留像素 -> {args.out_dir}")


def cmd_sheet(args):
    sheet = Image.open(args.sheet).convert("RGBA")
    sw, sh = sheet.size
    fw = args.frame_w or (sw // args.cols)
    fh = args.frame_h or (sh // args.rows)
    count = 0
    total = 0
    idx = 0
    for r in range(args.rows):
        for c in range(args.cols):
            if args.count and idx >= args.count:
                break
            box = (c * fw, r * fh, c * fw + fw, r * fh + fh)
            frame = sheet.crop(box)
            frame, cleaned = clean_alpha(frame)
            total += cleaned
            save_frame(frame, args.out_dir, idx)
            idx += 1
            count += 1
    print(f"完成: 切出 {count} 帧 ({fw}x{fh}), 清理 {total} 个残留像素 -> {args.out_dir}")


def build_parser():
    p = argparse.ArgumentParser(description="帧序列资产导入/清理工具")
    sub = p.add_subparsers(dest="cmd", required=True)

    pc = sub.add_parser("clean", help="清理目录下所有 PNG 的 alpha 残留")
    pc.add_argument("dir", help="帧目录 (递归)")
    pc.set_defaults(func=cmd_clean)

    pg = sub.add_parser("gif", help="从 GIF 抽帧 + 清理")
    pg.add_argument("gif", help="输入 GIF")
    pg.add_argument("out_dir", help="输出帧目录")
    pg.add_argument("--frames", type=int, help="采样到指定帧数")
    pg.add_argument("--pad", type=lambda s: tuple(int(v) for v in s.split("x")),
                    help="统一画布大小, 例 239x220")
    pg.set_defaults(func=cmd_gif)

    ps = sub.add_parser("sheet", help="从雪碧图切帧 + 清理")
    ps.add_argument("sheet", help="雪碧图 PNG")
    ps.add_argument("out_dir", help="输出帧目录")
    ps.add_argument("--cols", type=int, required=True)
    ps.add_argument("--rows", type=int, required=True)
    ps.add_argument("--frame-w", type=int)
    ps.add_argument("--frame-h", type=int)
    ps.add_argument("--count", type=int, help="只取前 N 帧")
    ps.set_defaults(func=cmd_sheet)

    return p


if __name__ == "__main__":
    args = build_parser().parse_args()
    args.func(args)
