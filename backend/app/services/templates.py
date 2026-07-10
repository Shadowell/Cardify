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


def base_schema(default_canvas_size_id: str, category: str, layers: list[dict]) -> dict:
    return {
        "schema_version": "1.0",
        "canvas_sizes": CANVAS_SIZES,
        "default_canvas_size_id": default_canvas_size_id,
        "safe_area": {"top": 0.06, "right": 0.06, "bottom": 0.07, "left": 0.06},
        "layers": layers,
        "tokens": {
            "category": category,
            "palette": {
                "paper": "#FFFFFD",
                "ink": "#14231F",
                "muted": "#6F8079",
                "mint": "#DFF8EC",
                "sky": "#EAF7FF",
                "gold": "#E9D7A2",
                "pink": "#FFF0F3",
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
                {"id": "image", "type": "image", "role": "cover_image", "frame": {"x": 0.06, "y": 0.05, "width": 0.88, "height": 0.39}, "style": {"radius": 30}},
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
                {"id": "headline", "type": "text", "role": "title", "frame": {"x": 0.1, "y": 0.23, "width": 0.72, "height": 0.32}, "max_lines": 5, "style": {"font_size": 58, "weight": "bold"}},
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
