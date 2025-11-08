#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

/// Cell data passed from CPU (must match Swift CellData struct)
struct CellData {
    float2 position;           // x, y position in pixels
    float4 glyphTexCoords;     // x, y, width, height in texture space (0-1)
    float4 foreground;         // RGBA foreground color
    float4 background;         // RGBA background color
    uint flags;                // Text attributes (bold, italic, underline, etc.)
    uint3 _padding;            // Alignment padding
};

/// Vertex shader output / Fragment shader input
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 foreground;
    float4 background;
    uint flags;
};

// MARK: - Constants

constant uint FLAG_BOLD = 0x01;
constant uint FLAG_ITALIC = 0x02;
constant uint FLAG_UNDERLINE = 0x04;
constant uint FLAG_BLINK = 0x08;
constant uint FLAG_INVERSE = 0x10;
constant uint FLAG_STRIKETHROUGH = 0x20;

// MARK: - Vertex Shader

vertex VertexOut vertex_main(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2& viewportSize [[buffer(0)]],
    constant float2& cellDimensions [[buffer(1)]],
    constant float2* quadVertices [[buffer(2)]],
    constant CellData* cellData [[buffer(3)]]
) {
    // Get cell data for this instance
    CellData cell = cellData[instanceID];

    // Get quad vertex (0-5, two triangles forming a quad)
    float2 quadVertex = quadVertices[vertexID];

    // Calculate pixel position
    float2 pixelPos = cell.position + quadVertex * cellDimensions;

    // Convert to normalized device coordinates (-1 to 1)
    float2 ndc = (pixelPos / viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;  // Flip Y axis (Metal has top-left origin, NDC has bottom-left)

    // Calculate texture coordinates
    float2 texCoord = cell.glyphTexCoords.xy + quadVertex * cell.glyphTexCoords.zw;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.texCoord = texCoord;
    out.foreground = cell.foreground;
    out.background = cell.background;
    out.flags = cell.flags;

    return out;
}

// MARK: - Fragment Shader

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> glyphTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Sample glyph texture
    float4 texColor = glyphTexture.sample(textureSampler, in.texCoord);

    // Handle inverse video
    float4 fg = in.foreground;
    float4 bg = in.background;
    if (in.flags & FLAG_INVERSE) {
        float4 temp = fg;
        fg = bg;
        bg = temp;
    }

    // Use glyph alpha to blend foreground color over background
    // The glyph texture has pre-rasterized glyphs where:
    // - Alpha channel contains the glyph coverage (antialiasing)
    // - RGB channels are white (from rasterization)

    float glyphAlpha = texColor.a;

    // Blend: background color with foreground text
    float4 color = mix(bg, fg, glyphAlpha);

    // Handle underline (draw a line in the bottom 15% of the cell)
    if (in.flags & FLAG_UNDERLINE) {
        float underlineY = 0.85;  // Position from top (0=top, 1=bottom)
        float underlineThickness = 0.08;

        // Calculate local Y coordinate within this cell (0 at top, 1 at bottom)
        float localY = fract(in.texCoord.y / in.background.a);  // Approximate

        // Simple approach: just brighten the foreground a bit near bottom
        // A more accurate approach would require passing cell-local coordinates
        if (localY > underlineY && localY < underlineY + underlineThickness) {
            color = fg;
        }
    }

    // Handle strikethrough (draw a line in the middle 50% of the cell)
    if (in.flags & FLAG_STRIKETHROUGH) {
        float strikeY = 0.45;
        float strikeThickness = 0.08;

        float localY = fract(in.texCoord.y / in.background.a);

        if (localY > strikeY && localY < strikeY + strikeThickness) {
            color = fg;
        }
    }

    return color;
}

// MARK: - Alternative: Two-Pass Rendering (Background + Foreground)

/// Background-only vertex shader
vertex VertexOut vertex_background(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2& viewportSize [[buffer(0)]],
    constant float2& cellDimensions [[buffer(1)]],
    constant float2* quadVertices [[buffer(2)]],
    constant CellData* cellData [[buffer(3)]]
) {
    CellData cell = cellData[instanceID];
    float2 quadVertex = quadVertices[vertexID];
    float2 pixelPos = cell.position + quadVertex * cellDimensions;
    float2 ndc = (pixelPos / viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.texCoord = float2(0.0, 0.0);
    out.foreground = cell.foreground;
    out.background = cell.background;
    out.flags = cell.flags;

    return out;
}

/// Background-only fragment shader (solid color)
fragment float4 fragment_background(VertexOut in [[stage_in]]) {
    float4 bg = in.background;
    if (in.flags & FLAG_INVERSE) {
        return in.foreground;
    }
    return bg;
}

// MARK: - Cursor Rendering Shaders

struct CursorVertexOut {
    float4 position [[position]];
    float2 localCoord;  // 0-1 coordinates within cursor quad
};

/// Cursor vertex shader
vertex CursorVertexOut cursor_vertex(
    uint vertexID [[vertex_id]],
    constant float2& viewportSize [[buffer(0)]],
    constant float2& cursorPosition [[buffer(1)]],
    constant float2& cursorSize [[buffer(2)]],
    constant float2* quadVertices [[buffer(3)]]
) {
    float2 quadVertex = quadVertices[vertexID];

    // Transform to pixel coordinates
    float2 pixelPos = cursorPosition + quadVertex * cursorSize;

    // Convert to NDC
    float2 ndc = (pixelPos / viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    CursorVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.localCoord = quadVertex;

    return out;
}

/// Cursor fragment shader
fragment float4 cursor_fragment(
    CursorVertexOut in [[stage_in]],
    constant float4& color [[buffer(0)]],
    constant uint& style [[buffer(1)]]
) {
    // style 0 = filled, style 1 = outline

    if (style == 1) {
        // Outline cursor - only draw border
        float borderWidth = 0.1;  // 10% of cursor size

        bool isEdge = (in.localCoord.x < borderWidth ||
                      in.localCoord.x > 1.0 - borderWidth ||
                      in.localCoord.y < borderWidth ||
                      in.localCoord.y > 1.0 - borderWidth);

        if (!isEdge) {
            discard_fragment();
        }
    }

    return color;
}
