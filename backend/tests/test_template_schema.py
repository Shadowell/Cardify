from app.schemas import TemplateDocumentSchema
from app.services.templates import SEED_TEMPLATES


def test_seed_template_documents_are_valid():
    for template in SEED_TEMPLATES:
        document = TemplateDocumentSchema.model_validate(template["schema"])
        assert document.default_canvas_size_id in {size.id for size in document.canvas_sizes}
        assert document.layers
        for layer in document.layers:
            assert layer.frame.x + layer.frame.width <= 1.01
            assert layer.frame.y + layer.frame.height <= 1.01
