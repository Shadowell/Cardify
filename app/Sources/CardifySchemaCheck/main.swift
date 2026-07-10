import CardifyCore
import Foundation

let json = """
{
  "schema_version": "1.0",
  "canvas_sizes": [
    {"id":"xhs-3-4","label":"小红书竖图","ratio_label":"3:4","width":1242,"height":1656,"usage":"图文笔记"}
  ],
  "default_canvas_size_id": "xhs-3-4",
  "safe_area": {"top":0.06,"right":0.06,"bottom":0.07,"left":0.06},
  "layers": [
    {"id":"title","type":"text","role":"title","frame":{"x":0.1,"y":0.1,"width":0.8,"height":0.2},"max_lines":3,"style":{"font_size":42,"weight":"bold"}}
  ],
  "tokens": {}
}
"""

do {
    let document = try JSONDecoder().decode(TemplateDocument.self, from: Data(json.utf8))
    try document.validateFrames()
    precondition(document.defaultCanvasSize.ratioLabel == "3:4")
    precondition(document.layers.first?.style.double("font_size", default: 0) == 42)
    print("Cardify schema check passed")
} catch {
    fputs("Cardify schema check failed: \(error)\n", stderr)
    exit(1)
}
