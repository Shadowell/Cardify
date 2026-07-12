from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Template


CANVAS_SIZES = [
    {
        "id": "xhs-3-4",
        "label": "小红书竖图",
        "ratio_label": "3:4",
        "width": 1242,
        "height": 1656,
        "usage": "图文笔记、分享海报",
    },
    {
        "id": "xhs-4-5",
        "label": "小红书封面",
        "ratio_label": "4:5",
        "width": 1080,
        "height": 1350,
        "usage": "封面、种草首图",
    },
    {
        "id": "square-1-1",
        "label": "方图",
        "ratio_label": "1:1",
        "width": 1080,
        "height": 1080,
        "usage": "头像、社交平台通用图",
    },
    {
        "id": "video-9-16",
        "label": "竖屏视频",
        "ratio_label": "9:16",
        "width": 1080,
        "height": 1920,
        "usage": "短视频封面、截图式卡片",
    },
    {
        "id": "poster-9-20",
        "label": "长图海报",
        "ratio_label": "9:20",
        "width": 1080,
        "height": 2400,
        "usage": "长图教程、清单海报",
    },
    {
        "id": "wide-16-9",
        "label": "公众号/横图",
        "ratio_label": "16:9",
        "width": 1600,
        "height": 900,
        "usage": "公众号配图、横版封面",
    },
]


CATEGORY_VISUALS = {
    "知识卡": {
        "paper": "#F7F9FF",
        "accent": "#6E8FE8",
        "secondary": "#9CC7F2",
        "highlight": "#F2C86B",
        "pattern": "blueprint",
    },
    "分享卡": {
        "paper": "#FFF8F7",
        "accent": "#E8797F",
        "secondary": "#F2AF91",
        "highlight": "#8DC8B3",
        "pattern": "confetti",
    },
    "育儿": {
        "paper": "#FFF9EC",
        "accent": "#E9B84F",
        "secondary": "#83BDAA",
        "highlight": "#F3A6A0",
        "pattern": "playful",
    },
    "营销": {
        "paper": "#FFF7EA",
        "accent": "#E99045",
        "secondary": "#D85F72",
        "highlight": "#6E9ECF",
        "pattern": "rays",
    },
    "视频卡": {
        "paper": "#1D2230",
        "ink": "#F7F8FC",
        "muted": "#AEB7CB",
        "accent": "#7C8DFF",
        "secondary": "#4ED0C0",
        "highlight": "#FF7183",
        "pattern": "scanlines",
    },
    "旅行": {
        "paper": "#F2FBFF",
        "accent": "#58A8D5",
        "secondary": "#78C3B3",
        "highlight": "#F2C663",
        "pattern": "contours",
    },
    "探店": {
        "paper": "#FFF9F0",
        "accent": "#C89A45",
        "secondary": "#7FAA86",
        "highlight": "#E58B78",
        "pattern": "checker",
    },
    "生活": {
        "paper": "#FAF8FF",
        "accent": "#8B77C6",
        "secondary": "#78B8B0",
        "highlight": "#E89AA6",
        "pattern": "waves",
    },
}


def decorative_layers(category: str) -> list[dict]:
    visual = CATEGORY_VISUALS.get(category, CATEGORY_VISUALS["知识卡"])
    return [
        {
            "id": "template-background",
            "type": "shape",
            "role": "decorative_background",
            "frame": {"x": 0, "y": 0, "width": 1, "height": 1},
            "style": {"fill": visual["paper"], "radius": 0},
        },
        {
            "id": "template-pattern",
            "type": "shape",
            "role": "decorative_pattern",
            "frame": {"x": 0, "y": 0, "width": 1, "height": 1},
            "style": {
                "fill": "#FFFFFF",
                "fill_opacity": 0,
                "pattern": visual["pattern"],
                "pattern_color": visual["accent"],
                "pattern_opacity": 0.16,
                "pattern_spacing": 46,
                "radius": 0,
            },
        },
        {
            "id": "template-inner-frame",
            "type": "shape",
            "role": "decorative_frame",
            "frame": {"x": 0.032, "y": 0.032, "width": 0.936, "height": 0.936},
            "style": {
                "fill": "#FFFFFF",
                "fill_opacity": 0,
                "stroke": visual["accent"],
                "stroke_width": 1.2,
                "radius": 34,
            },
        },
    ]


def base_schema(default_canvas_size_id: str, category: str, layers: list[dict]) -> dict:
    visual = CATEGORY_VISUALS.get(category, CATEGORY_VISUALS["知识卡"])
    content_layers = layers
    if layers and layers[0].get("role") == "background":
        content_layers = layers[1:]

    return {
        "schema_version": "1.0",
        "canvas_sizes": CANVAS_SIZES,
        "default_canvas_size_id": default_canvas_size_id,
        "safe_area": {"top": 0.06, "right": 0.06, "bottom": 0.07, "left": 0.06},
        "layers": decorative_layers(category) + content_layers,
        "tokens": {
            "category": category,
            "palette": {
                "paper": visual["paper"],
                "ink": visual.get("ink", "#14231F"),
                "muted": visual.get("muted", "#6F8079"),
                "mint": visual["accent"],
                "sky": visual["secondary"],
                "gold": visual["highlight"],
                "pink": visual["highlight"],
            },
        },
    }


SEED_TEMPLATES = [
    {
        "id": "knowledge-note",
        "name": "知识分享卡",
        "category": "知识卡",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "知识卡",
            [
                {"id": "hero", "type": "shape", "role": "background", "frame": {"x": 0, "y": 0, "width": 1, "height": 1}, "style": {"fill": "paper"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.1, "y": 0.14, "width": 0.8, "height": 0.22}, "max_lines": 4, "style": {"font_size": 48, "weight": "bold"}},
                {"id": "body", "type": "text", "role": "summary", "frame": {"x": 0.1, "y": 0.42, "width": 0.8, "height": 0.28}, "max_lines": 8, "style": {"font_size": 28, "line_height": 1.55}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.1, "y": 0.77, "width": 0.8, "height": 0.08}, "max_lines": 2, "style": {"font_size": 22, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "note-share-poster",
        "name": "笔记分享海报卡",
        "category": "分享卡",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "分享卡",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.06, "y": 0.05, "width": 0.88, "height": 0.39}, "style": {"radius": 30, "badge": "共3张"}},
                {"id": "avatar", "type": "avatar", "role": "author_avatar", "frame": {"x": 0.08, "y": 0.48, "width": 0.09, "height": 0.07}, "style": {}},
                {"id": "author", "type": "text", "role": "author_name", "frame": {"x": 0.2, "y": 0.49, "width": 0.54, "height": 0.05}, "max_lines": 1, "style": {"font_size": 23, "weight": "bold"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.08, "y": 0.59, "width": 0.84, "height": 0.15}, "max_lines": 3, "style": {"font_size": 38, "weight": "bold"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.76, "width": 0.58, "height": 0.07}, "max_lines": 2, "style": {"font_size": 20, "color": "muted"}},
                {"id": "metrics", "type": "metrics", "role": "metrics", "frame": {"x": 0.08, "y": 0.88, "width": 0.55, "height": 0.04}, "style": {"color": "muted"}},
                {"id": "qr", "type": "qr", "role": "share_qr", "frame": {"x": 0.75, "y": 0.82, "width": 0.14, "height": 0.11}, "style": {}},
            ],
        ),
    },
    {
        "id": "parenting-note",
        "name": "育儿经验卡",
        "category": "育儿",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "育儿",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.08, "y": 0.06, "width": 0.84, "height": 0.34}, "style": {"radius": 32}},
                {"id": "avatar", "type": "avatar", "role": "author_avatar", "frame": {"x": 0.1, "y": 0.44, "width": 0.1, "height": 0.075}, "style": {"fill": "mint"}},
                {"id": "author", "type": "text", "role": "author_name", "frame": {"x": 0.23, "y": 0.45, "width": 0.55, "height": 0.05}, "max_lines": 1, "style": {"font_size": 24, "weight": "semibold"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.1, "y": 0.53, "width": 0.8, "height": 0.16}, "max_lines": 3, "style": {"font_size": 34, "weight": "bold"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.1, "y": 0.71, "width": 0.8, "height": 0.08}, "max_lines": 2, "style": {"font_size": 22, "color": "muted"}},
                {"id": "qr", "type": "qr", "role": "share_qr", "frame": {"x": 0.68, "y": 0.85, "width": 0.18, "height": 0.135}, "style": {}},
            ],
        ),
    },
    {
        "id": "marketing-note",
        "name": "营销种草卡",
        "category": "营销",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "营销",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.07, "y": 0.06, "width": 0.86, "height": 0.38}, "style": {"radius": 28}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.09, "y": 0.5, "width": 0.82, "height": 0.18}, "max_lines": 3, "style": {"font_size": 38, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.09, "y": 0.69, "width": 0.82, "height": 0.12}, "max_lines": 3, "style": {"font_size": 24}},
                {"id": "metrics", "type": "metrics", "role": "metrics", "frame": {"x": 0.09, "y": 0.86, "width": 0.55, "height": 0.05}, "style": {"color": "muted"}},
                {"id": "qr", "type": "qr", "role": "share_qr", "frame": {"x": 0.72, "y": 0.82, "width": 0.16, "height": 0.128}, "style": {}},
            ],
        ),
    },
    {
        "id": "xhs-video-shot",
        "name": "短视频截图卡",
        "category": "视频卡",
        "default_size_id": "video-9-16",
        "schema": base_schema(
            "video-9-16",
            "视频卡",
            [
                {"id": "search", "type": "shape", "role": "search_bar", "frame": {"x": 0.13, "y": 0.06, "width": 0.78, "height": 0.05}, "style": {"fill": "#727985", "radius": 18}},
                {"id": "headline", "type": "text", "role": "title", "frame": {"x": 0.1, "y": 0.23, "width": 0.72, "height": 0.32}, "max_lines": 5, "style": {"font_size": 58, "weight": "bold", "color": "paper"}},
                {"id": "rail", "type": "metrics", "role": "video_metrics", "frame": {"x": 0.84, "y": 0.37, "width": 0.12, "height": 0.34}, "style": {"orientation": "vertical"}},
                {"id": "caption", "type": "text", "role": "summary", "frame": {"x": 0.06, "y": 0.78, "width": 0.78, "height": 0.1}, "max_lines": 3, "style": {"font_size": 24, "color": "paper"}},
                {"id": "comment", "type": "shape", "role": "comment_bar", "frame": {"x": 0.06, "y": 0.93, "width": 0.72, "height": 0.045}, "style": {"fill": "#32363C", "radius": 24}},
            ],
        ),
    },
    {
        "id": "travel-guide",
        "name": "旅行攻略卡",
        "category": "旅行",
        "default_size_id": "poster-9-20",
        "schema": base_schema(
            "poster-9-20",
            "旅行",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.07, "y": 0.04, "width": 0.86, "height": 0.28}, "style": {"radius": 30}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.08, "y": 0.36, "width": 0.84, "height": 0.12}, "max_lines": 3, "style": {"font_size": 40, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.08, "y": 0.5, "width": 0.84, "height": 0.22}, "max_lines": 8, "style": {"font_size": 26}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.76, "width": 0.84, "height": 0.08}, "max_lines": 2, "style": {"font_size": 22, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "local-store",
        "name": "探店打卡卡",
        "category": "探店",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "探店",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.06, "y": 0.05, "width": 0.88, "height": 0.48}, "style": {"radius": 30}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.08, "y": 0.59, "width": 0.84, "height": 0.13}, "max_lines": 3, "style": {"font_size": 36, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.08, "y": 0.75, "width": 0.84, "height": 0.09}, "max_lines": 3, "style": {"font_size": 23}},
                {"id": "metrics", "type": "metrics", "role": "metrics", "frame": {"x": 0.08, "y": 0.9, "width": 0.72, "height": 0.05}, "style": {"color": "muted"}},
            ],
        ),
    },
    {
        "id": "checklist-note",
        "name": "清单干货卡",
        "category": "知识卡",
        "default_size_id": "poster-9-20",
        "schema": base_schema(
            "poster-9-20",
            "知识卡",
            [
                {"id": "header", "type": "shape", "role": "header", "frame": {"x": 0.06, "y": 0.05, "width": 0.88, "height": 0.11}, "style": {"fill": "mint", "radius": 28}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.1, "y": 0.085, "width": 0.8, "height": 0.035}, "max_lines": 1, "style": {"text": "实用清单 · CHECKLIST", "font_size": 22, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.08, "y": 0.21, "width": 0.84, "height": 0.14}, "max_lines": 3, "style": {"font_size": 42, "weight": "bold"}},
                {"id": "rail", "type": "shape", "role": "rail", "frame": {"x": 0.08, "y": 0.42, "width": 0.025, "height": 0.34}, "style": {"fill": "gold", "radius": 12}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.14, "y": 0.41, "width": 0.76, "height": 0.36}, "max_lines": 11, "style": {"font_size": 27}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.86, "width": 0.84, "height": 0.06}, "max_lines": 2, "style": {"font_size": 21, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "tutorial-steps",
        "name": "步骤教程卡",
        "category": "知识卡",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "知识卡",
            [
                {"id": "side", "type": "shape", "role": "side", "frame": {"x": 0.05, "y": 0.05, "width": 0.22, "height": 0.9}, "style": {"fill": "sky", "radius": 30}},
                {"id": "step-1", "type": "text", "role": "static", "frame": {"x": 0.09, "y": 0.2, "width": 0.14, "height": 0.06}, "max_lines": 1, "style": {"text": "01", "font_size": 32, "weight": "bold", "alignment": "center"}},
                {"id": "step-2", "type": "text", "role": "static", "frame": {"x": 0.09, "y": 0.45, "width": 0.14, "height": 0.06}, "max_lines": 1, "style": {"text": "02", "font_size": 32, "weight": "bold", "alignment": "center"}},
                {"id": "step-3", "type": "text", "role": "static", "frame": {"x": 0.09, "y": 0.7, "width": 0.14, "height": 0.06}, "max_lines": 1, "style": {"text": "03", "font_size": 32, "weight": "bold", "alignment": "center"}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.34, "y": 0.08, "width": 0.58, "height": 0.04}, "max_lines": 1, "style": {"text": "STEP BY STEP", "font_size": 20, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.34, "y": 0.16, "width": 0.58, "height": 0.2}, "max_lines": 4, "style": {"font_size": 40, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.34, "y": 0.43, "width": 0.58, "height": 0.31}, "max_lines": 8, "style": {"font_size": 25}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.34, "y": 0.84, "width": 0.58, "height": 0.07}, "max_lines": 2, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "quote-poster",
        "name": "金句语录卡",
        "category": "分享卡",
        "default_size_id": "square-1-1",
        "schema": base_schema(
            "square-1-1",
            "分享卡",
            [
                {"id": "panel", "type": "shape", "role": "panel", "frame": {"x": 0.06, "y": 0.06, "width": 0.88, "height": 0.88}, "style": {"fill": "pink", "radius": 40}},
                {"id": "quote", "type": "text", "role": "static", "frame": {"x": 0.12, "y": 0.11, "width": 0.2, "height": 0.16}, "max_lines": 1, "style": {"text": "“", "font_size": 88, "weight": "bold"}},
                {"id": "quote-wash", "type": "shape", "role": "quote_wash", "frame": {"x": 0.12, "y": 0.2, "width": 0.76, "height": 0.56}, "style": {"fill": "#FFFFFF", "fill_opacity": 0.22, "pattern": "rays", "pattern_color": "#FFFFFF", "pattern_opacity": 0.34, "pattern_spacing": 72, "radius": 32}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.14, "y": 0.27, "width": 0.72, "height": 0.42}, "max_lines": 6, "style": {"font_size": 50, "weight": "bold", "alignment": "center", "line_height": 1.28}},
                {"id": "quote-end", "type": "text", "role": "static", "frame": {"x": 0.7, "y": 0.7, "width": 0.18, "height": 0.14}, "max_lines": 1, "style": {"text": "”", "font_size": 80, "weight": "bold", "alignment": "trailing"}},
            ],
        ),
    },
    {
        "id": "reading-note",
        "name": "读书笔记卡",
        "category": "知识卡",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "知识卡",
            [
                {"id": "book", "type": "image", "role": "cover_image", "frame": {"x": 0.07, "y": 0.08, "width": 0.35, "height": 0.46}, "style": {"radius": 20}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.48, "y": 0.11, "width": 0.44, "height": 0.04}, "max_lines": 1, "style": {"text": "READING NOTE", "font_size": 19, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.48, "y": 0.2, "width": 0.44, "height": 0.26}, "max_lines": 5, "style": {"font_size": 35, "weight": "bold"}},
                {"id": "summary-panel", "type": "shape", "role": "summary_panel", "frame": {"x": 0.07, "y": 0.62, "width": 0.86, "height": 0.22}, "style": {"fill": "sky", "radius": 28}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.11, "y": 0.66, "width": 0.78, "height": 0.14}, "max_lines": 5, "style": {"font_size": 24}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.89, "width": 0.84, "height": 0.05}, "max_lines": 1, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "workplace-tips",
        "name": "职场经验卡",
        "category": "知识卡",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "知识卡",
            [
                {"id": "panel", "type": "shape", "role": "panel", "frame": {"x": 0.57, "y": 0.06, "width": 0.37, "height": 0.88}, "style": {"fill": "gold", "radius": 30}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.08, "y": 0.1, "width": 0.42, "height": 0.04}, "max_lines": 1, "style": {"text": "WORK SMART", "font_size": 20, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.08, "y": 0.21, "width": 0.75, "height": 0.22}, "max_lines": 4, "style": {"font_size": 42, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.08, "y": 0.52, "width": 0.43, "height": 0.25}, "max_lines": 7, "style": {"font_size": 24}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.85, "width": 0.42, "height": 0.08}, "max_lines": 2, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "study-checkin",
        "name": "学习打卡卡",
        "category": "知识卡",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "知识卡",
            [
                {"id": "day-panel", "type": "shape", "role": "day_panel", "frame": {"x": 0.07, "y": 0.06, "width": 0.86, "height": 0.16}, "style": {"fill": "sky", "radius": 30}},
                {"id": "day", "type": "text", "role": "static", "frame": {"x": 0.11, "y": 0.105, "width": 0.78, "height": 0.06}, "max_lines": 1, "style": {"text": "DAY 21 · LEARNING LOG", "font_size": 24, "weight": "semibold", "alignment": "center"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.1, "y": 0.31, "width": 0.8, "height": 0.18}, "max_lines": 4, "style": {"font_size": 42, "weight": "bold", "alignment": "center"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.13, "y": 0.57, "width": 0.74, "height": 0.2}, "max_lines": 6, "style": {"font_size": 25, "alignment": "center"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.15, "y": 0.85, "width": 0.7, "height": 0.06}, "max_lines": 2, "style": {"font_size": 20, "color": "muted", "alignment": "center"}},
            ],
        ),
    },
    {
        "id": "fitness-record",
        "name": "健身记录卡",
        "category": "生活",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "生活",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.06, "y": 0.05, "width": 0.88, "height": 0.47}, "style": {"radius": 28}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.09, "y": 0.57, "width": 0.82, "height": 0.04}, "max_lines": 1, "style": {"text": "TRAINING LOG", "font_size": 20, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.09, "y": 0.64, "width": 0.82, "height": 0.13}, "max_lines": 3, "style": {"font_size": 38, "weight": "bold"}},
                {"id": "metrics", "type": "metrics", "role": "metrics", "frame": {"x": 0.09, "y": 0.82, "width": 0.7, "height": 0.05}, "style": {"color": "muted"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.09, "y": 0.9, "width": 0.82, "height": 0.05}, "max_lines": 1, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "recipe-note",
        "name": "美食食谱卡",
        "category": "生活",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "生活",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.07, "y": 0.06, "width": 0.86, "height": 0.42}, "style": {"radius": 34}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.09, "y": 0.53, "width": 0.82, "height": 0.04}, "max_lines": 1, "style": {"text": "今日食谱 · RECIPE", "font_size": 20, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.09, "y": 0.6, "width": 0.82, "height": 0.13}, "max_lines": 3, "style": {"font_size": 38, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.09, "y": 0.77, "width": 0.82, "height": 0.1}, "max_lines": 3, "style": {"font_size": 23}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.09, "y": 0.91, "width": 0.82, "height": 0.04}, "max_lines": 1, "style": {"font_size": 19, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "product-pick",
        "name": "好物推荐卡",
        "category": "分享卡",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "分享卡",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.06, "y": 0.08, "width": 0.42, "height": 0.72}, "style": {"radius": 28}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.54, "y": 0.12, "width": 0.39, "height": 0.04}, "max_lines": 1, "style": {"text": "GOOD PICK", "font_size": 19, "weight": "semibold", "color": "muted"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.54, "y": 0.21, "width": 0.39, "height": 0.22}, "max_lines": 4, "style": {"font_size": 34, "weight": "bold"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.54, "y": 0.5, "width": 0.39, "height": 0.17}, "max_lines": 5, "style": {"font_size": 22}},
                {"id": "metrics", "type": "metrics", "role": "metrics", "frame": {"x": 0.54, "y": 0.73, "width": 0.39, "height": 0.05}, "style": {"color": "muted"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.88, "width": 0.84, "height": 0.06}, "max_lines": 2, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "outfit-look",
        "name": "穿搭分享卡",
        "category": "生活",
        "default_size_id": "xhs-3-4",
        "schema": base_schema(
            "xhs-3-4",
            "生活",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.05, "y": 0.04, "width": 0.9, "height": 0.62}, "style": {"radius": 30}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.1, "y": 0.09, "width": 0.25, "height": 0.06}, "max_lines": 1, "style": {"text": "OOTD", "font_size": 28, "weight": "bold", "color": "paper"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.08, "y": 0.72, "width": 0.84, "height": 0.13}, "max_lines": 3, "style": {"font_size": 38, "weight": "bold"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.89, "width": 0.84, "height": 0.06}, "max_lines": 2, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "beauty-review",
        "name": "美妆测评卡",
        "category": "分享卡",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "分享卡",
            [
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.07, "y": 0.07, "width": 0.48, "height": 0.5}, "style": {"radius": 30}},
                {"id": "rating", "type": "shape", "role": "rating", "frame": {"x": 0.61, "y": 0.08, "width": 0.3, "height": 0.12}, "style": {"fill": "pink", "radius": 24}},
                {"id": "rating-text", "type": "text", "role": "static", "frame": {"x": 0.64, "y": 0.11, "width": 0.24, "height": 0.05}, "max_lines": 1, "style": {"text": "REVIEW 4.8", "font_size": 20, "weight": "semibold", "alignment": "center"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.61, "y": 0.27, "width": 0.32, "height": 0.24}, "max_lines": 4, "style": {"font_size": 34, "weight": "bold"}},
                {"id": "summary-panel", "type": "shape", "role": "summary_panel", "frame": {"x": 0.07, "y": 0.64, "width": 0.86, "height": 0.2}, "style": {"fill": "pink", "radius": 28}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.11, "y": 0.68, "width": 0.78, "height": 0.12}, "max_lines": 4, "style": {"font_size": 23}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.08, "y": 0.89, "width": 0.84, "height": 0.06}, "max_lines": 2, "style": {"font_size": 20, "color": "muted"}},
            ],
        ),
    },
    {
        "id": "event-promo",
        "name": "活动促销卡",
        "category": "营销",
        "default_size_id": "xhs-4-5",
        "schema": base_schema(
            "xhs-4-5",
            "营销",
            [
                {"id": "promo", "type": "shape", "role": "promo", "frame": {"x": 0.06, "y": 0.06, "width": 0.88, "height": 0.22}, "style": {"fill": "gold", "radius": 34}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.12, "y": 0.11, "width": 0.76, "height": 0.08}, "max_lines": 1, "style": {"text": "LIMITED OFFER", "font_size": 32, "weight": "bold", "alignment": "center"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.09, "y": 0.37, "width": 0.82, "height": 0.22}, "max_lines": 4, "style": {"font_size": 46, "weight": "bold", "alignment": "center"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.14, "y": 0.66, "width": 0.72, "height": 0.12}, "max_lines": 4, "style": {"font_size": 24, "alignment": "center"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.15, "y": 0.86, "width": 0.7, "height": 0.07}, "max_lines": 2, "style": {"font_size": 20, "color": "muted", "alignment": "center"}},
            ],
        ),
    },
    {
        "id": "holiday-greeting",
        "name": "节日祝福卡",
        "category": "分享卡",
        "default_size_id": "square-1-1",
        "schema": base_schema(
            "square-1-1",
            "分享卡",
            [
                {"id": "top", "type": "shape", "role": "top", "frame": {"x": 0.08, "y": 0.08, "width": 0.84, "height": 0.18}, "style": {"fill": "pink", "radius": 34}},
                {"id": "bottom", "type": "shape", "role": "bottom", "frame": {"x": 0.18, "y": 0.78, "width": 0.64, "height": 0.12}, "style": {"fill": "gold", "radius": 30}},
                {"id": "kicker", "type": "text", "role": "static", "frame": {"x": 0.2, "y": 0.14, "width": 0.6, "height": 0.05}, "max_lines": 1, "style": {"text": "BEST WISHES", "font_size": 22, "weight": "semibold", "alignment": "center"}},
                {"id": "title", "type": "text", "role": "title", "frame": {"x": 0.14, "y": 0.35, "width": 0.72, "height": 0.22}, "max_lines": 4, "style": {"font_size": 46, "weight": "bold", "alignment": "center"}},
                {"id": "summary", "type": "text", "role": "summary", "frame": {"x": 0.18, "y": 0.62, "width": 0.64, "height": 0.1}, "max_lines": 3, "style": {"font_size": 23, "alignment": "center"}},
                {"id": "tags", "type": "text", "role": "tags", "frame": {"x": 0.22, "y": 0.815, "width": 0.56, "height": 0.04}, "max_lines": 1, "style": {"font_size": 19, "color": "muted", "alignment": "center"}},
            ],
        ),
    },
]


def seed_templates(db: Session) -> None:
    existing_templates = {template.id: template for template in db.scalars(select(Template)).all()}
    for item in SEED_TEMPLATES:
        existing = existing_templates.get(item["id"])
        if existing is None:
            db.add(
                Template(
                    id=item["id"],
                    name=item["name"],
                    category=item["category"],
                    default_size_id=item["default_size_id"],
                    schema=item["schema"],
                )
            )
            continue

        if (
            existing.name != item["name"]
            or existing.category != item["category"]
            or existing.default_size_id != item["default_size_id"]
            or existing.schema != item["schema"]
        ):
            existing.name = item["name"]
            existing.category = item["category"]
            existing.default_size_id = item["default_size_id"]
            existing.schema = item["schema"]
            existing.version += 1
    db.commit()
