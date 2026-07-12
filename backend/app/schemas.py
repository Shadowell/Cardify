from datetime import datetime
from typing import Any, Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field


class CanvasSizeSchema(BaseModel):
    id: str
    label: str
    ratio_label: str
    width: int = Field(gt=0)
    height: int = Field(gt=0)
    usage: str


class FrameSchema(BaseModel):
    x: float = Field(ge=0, le=1)
    y: float = Field(ge=0, le=1)
    width: float = Field(gt=0, le=1)
    height: float = Field(gt=0, le=1)


class LayerSchema(BaseModel):
    id: str
    type: Literal["text", "image", "avatar", "qr", "metrics", "shape"]
    frame: FrameSchema
    role: str
    max_lines: int | None = Field(default=None, ge=1)
    style: dict[str, Any] = Field(default_factory=dict)


class TemplateDocumentSchema(BaseModel):
    schema_version: str = "1.0"
    canvas_sizes: list[CanvasSizeSchema]
    default_canvas_size_id: str
    safe_area: dict[str, float]
    layers: list[LayerSchema]
    tokens: dict[str, Any] = Field(default_factory=dict)


class TemplateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    name: str
    category: str
    default_size_id: str
    version: int
    template_schema: TemplateDocumentSchema = Field(alias="schema", validation_alias=AliasChoices("schema", "template_schema"))


class TemplateListOut(BaseModel):
    items: list[TemplateOut]


class GenerationCreate(BaseModel):
    input_text: str = Field(min_length=1, max_length=5000)
    template_id: str | None = None


class GenerationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: Literal["pending", "running", "succeeded", "failed"]
    input_text: str
    template_id: str | None
    output: dict[str, Any] | None
    error: str | None
    created_at: datetime
    updated_at: datetime


class WorkCreate(BaseModel):
    template_id: str
    title: str = Field(min_length=1, max_length=160)
    input_text: str = Field(min_length=1, max_length=5000)
    render_params: dict[str, Any] = Field(default_factory=dict)


class WorkUpdate(WorkCreate):
    pass


class WorkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str | None
    template_id: str
    title: str
    input_text: str
    render_params: dict[str, Any]
    export_path: str | None
    created_at: datetime
    updated_at: datetime


class WorkListOut(BaseModel):
    items: list[WorkOut]


class ExportImageCreate(BaseModel):
    filename: str = Field(default="cardify-export.png", min_length=1, max_length=120)
    image_base64: str = Field(min_length=1)


class WorkAssetCreate(BaseModel):
    kind: Literal["cover", "avatar"]
    filename: str = Field(min_length=1, max_length=120)
    image_base64: str = Field(min_length=1)


class AppleLoginCreate(BaseModel):
    identity_token: str = Field(min_length=8)
    authorization_code: str | None = None
    display_name: str | None = Field(default=None, max_length=80)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    apple_subject: str
    display_name: str | None
    created_at: datetime


class AuthSessionOut(BaseModel):
    user: UserOut
    access_token: str
    token_type: str = "bearer"


class SubscriptionVerifyCreate(BaseModel):
    user_id: str
    product_id: str = Field(min_length=1)
    transaction_id: str = Field(min_length=1)
    expires_at: datetime | None = None


class SubscriptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    source: str
    product_id: str
    transaction_id: str
    status: str
    expires_at: datetime | None
    created_at: datetime
