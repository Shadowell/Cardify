import pytest

from app.schemas import TemplateDocumentSchema
from app.services.templates import CANVAS_SIZES, SEED_TEMPLATES


EXPECTED_CANVAS_SIZE_IDS = {size["id"] for size in CANVAS_SIZES}
EXPECTED_CATEGORIES = {"分享卡", "视频卡", "育儿", "营销", "探店", "旅行", "知识卡", "生活"}


def test_seed_template_documents_are_valid():
    for template in SEED_TEMPLATES:
        document = TemplateDocumentSchema.model_validate(template["schema"])
        assert document.default_canvas_size_id in {size.id for size in document.canvas_sizes}
        assert document.layers
        for layer in document.layers:
            assert layer.frame.x + layer.frame.width <= 1.01
            assert layer.frame.y + layer.frame.height <= 1.01


def test_seed_templates_cover_mvp_scenarios_and_sizes():
    assert len(SEED_TEMPLATES) >= 20
    assert EXPECTED_CATEGORIES.issubset({template["category"] for template in SEED_TEMPLATES})

    for template in SEED_TEMPLATES:
        document = TemplateDocumentSchema.model_validate(template["schema"])
        assert {size.id for size in document.canvas_sizes} == EXPECTED_CANVAS_SIZE_IDS
        assert template["default_size_id"] == document.default_canvas_size_id
        assert any(layer.role == "title" for layer in document.layers)


def test_canvas_size_ratios_match_labels():
    for canvas_size in CANVAS_SIZES:
        width_ratio, height_ratio = [int(value) for value in canvas_size["ratio_label"].split(":")]
        expected = width_ratio / height_ratio
        actual = canvas_size["width"] / canvas_size["height"]
        assert actual == pytest.approx(expected, abs=0.01)


def test_text_layers_have_safe_capacity_across_all_sizes():
    for template in SEED_TEMPLATES:
        document = TemplateDocumentSchema.model_validate(template["schema"])
        for layer in document.layers:
            if layer.type != "text":
                continue

            assert layer.max_lines is not None
            font_size = float(layer.style.get("font_size", 24))
            assert font_size >= 18

            for canvas_size in document.canvas_sizes:
                available_width = layer.frame.width * canvas_size.width
                available_height = layer.frame.height * canvas_size.height
                line_height = float(layer.style.get("line_height", 1.22))
                scaled_line_height = font_size * line_height * 0.72
                required_height = scaled_line_height * layer.max_lines
                readable_chars = available_width / max(font_size * 0.58 * 0.72, 1)

                assert available_height >= required_height * 0.9, (
                    template["id"],
                    layer.id,
                    canvas_size.id,
                )
                assert readable_chars >= 4, (
                    template["id"],
                    layer.id,
                    canvas_size.id,
                )
