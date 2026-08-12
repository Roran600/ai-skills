# Image Generation Skill for OpenCode

Generate high-quality images using OpenRouter MCP with advanced features like batch processing, upscaling, and metadata tracking.

## Features

- 🎨 **Dynamic Model Discovery** - Automatically fetches available image generation models from OpenRouter MCP
- 🔄 **Batch Generation** - Generate multiple images in a single session (up to 10 prompts × 5 variants)
- ⬆️ **Upscaling Support** - Scale images 2x or 4x for higher quality
- 📸 **Reference Images** - Use reference images for style guidance (up to 5 images)
- 🏷️ **Aspect Ratio & Resolution** - Full control over output dimensions
- 📝 **Metadata Tracking** - Automatic metadata JSON generation for each image
- 🔒 **Security First** - Anti-injection validation for all prompts
- 💳 **Credit Management** - Real-time credit balance checking and cost estimation

## Prerequisites

- OpenCode with OpenRouter MCP configured
- Node.js 14+
- Valid OpenRouter account with image generation credits

## Installation

The skill is included with OpenCode. To use it:

```bash
# Load via OpenCode CLI
opencode skill image-generation
```

## Usage

### Quick Start

1. Run the skill: `opencode skill image-generation`
2. Follow the 8-question interactive workflow
3. Generated images and metadata will be saved to your specified directory

### Interactive Workflow

#### Question 1: Prompts
Enter the prompts for image generation (one per line, max 10 prompts)

```
Example:
A futuristic city at sunset
Minimalist white room with plants
Abstract geometric patterns
```

#### Question 2: Model Selection
Choose how to select the image generation model:
- **1. Automatic (Recommended)** - Selects the cheapest available model
- **2. Manual** - Browse and select from top 15 models by price
- **3. Custom** - Enter a specific model slug (e.g., `openai/dall-e-3`)

#### Question 3: Aspect Ratio
Choose the output aspect ratio:
- 16:9 (Landscape) - Recommended
- 1:1 (Square)
- 4:3 (Portrait-ish)
- 9:16 (Portrait)
- 21:9 (Ultra-wide)
- Custom ratio

#### Question 4: Resolution
Select the output quality level:
- **1K** - Fast (~20-30s), Cheap (~$0.03-0.08)
- **2K** - Medium (~30-45s), Medium price (~$0.06-0.15)
- **4K** - Slow (~45-60s), Expensive (~$0.12-0.40)
- Custom resolution

#### Question 5: Reference Images (Optional)
Provide reference images for style guidance:
- URLs: `https://example.com/image.jpg`
- Local paths: `/home/user/image.png`
- Supported formats: PNG, JPG, WEBP, GIF
- Maximum: 5 images

#### Question 6: Variants
Number of different images to generate per prompt:
- 1 to 5 variants
- More variants = more options, higher cost

#### Question 7: Upscaling (Optional)
Enable upscaling for higher resolution:
- **None** - Keep original resolution
- **2x** - Double the resolution (~$0.02-0.05 per image)
- **4x** - Quadruple the resolution (~$0.04-0.08 per image)

#### Question 8: Output Path
Choose where to save generated images:
- **Current directory** (./)
- **Images subdirectory** (./images/)
- **Custom path** (/path/to/directory)

## Output Structure

Generated files are organized in your specified directory:

```
images_generated/
├─ image_20260812_103000_001_dalle3.png
├─ image_20260812_103000_001_dalle3_metadata.json
├─ image_20260812_103000_002_dalle3.png
├─ image_20260812_103000_002_dalle3_metadata.json
└─ batch_summary_20260812_103000.json
```

### Metadata Format

Each image has an accompanying JSON file with detailed metadata:

```json
{
  "filename": "image_20260812_103000_001_dalle3.png",
  "prompt": "A futuristic city at sunset with neon lights",
  "model_used": "openai/dall-e-3",
  "generation_id": "gen-abc123xyz",
  "source": "openrouter-mcp-inline",
  "aspect_ratio": "16:9",
  "resolution": {
    "requested": "1K",
    "actual_pixels": "1536x864",
    "upscaled": false,
    "upscale_factor": null
  },
  "generation": {
    "timestamp": "2026-08-12T10:30:00Z",
    "duration_ms": 45000,
    "cost_usd": 0.08,
    "provider": "together"
  },
  "upscaling": {
    "applied": false,
    "factor": null,
    "duration_ms": null,
    "cost_usd": null
  },
  "batch_info": {
    "batch_id": "batch_20260812_103000",
    "variant_number": 1,
    "total_variants": 2,
    "prompt_index": 1,
    "total_prompts": 3
  }
}
```

### Batch Summary

A `batch_summary_*.json` file is generated with aggregated statistics:

```json
{
  "batch_id": "batch_20260812_103000",
  "timestamp": "2026-08-12T10:30:00Z",
  "total_generated": 6,
  "total_upscaled": 3,
  "total_cost_usd": 0.54,
  "total_time_ms": 270000,
  "models_used": ["openai/dall-e-3"],
  "success_rate": "100%",
  "errors": 0,
  "configuration": {
    "num_prompts": 3,
    "num_variants": 2,
    "aspect_ratio": "16:9",
    "resolution": "1K",
    "upscale_enabled": true,
    "upscale_factor": "2x",
    "reference_images_used": 2
  }
}
```

## Security

### Prompt Validation

All prompts are validated for security:

✅ **Allowed:**
- Any creative content (violence, explicit, fantasy, sci-fi, dark art, etc.)
- All languages and dialects
- Emojis and Unicode characters
- Long, detailed prompts

❌ **Blocked:**
- SQL Injection attempts (SELECT, DROP, UNION, etc.)
- Command Injection (backticks, pipes, semicolons)
- Path Traversal (../, C:\, etc.)
- Null bytes
- Prompts outside 5-1500 character range

### Credit Management

- ⚠️ Warning if balance < $0.50
- ❌ Error if balance is $0
- Pre-calculation of total cost before generation
- Live balance update after generation

## Examples

### Example 1: Quick Landscape Batch

```
Q1: Prompts
   A beautiful sunset over mountains
   Ocean waves at night with stars
   Forest path in autumn

Q2: Automatic model selection
Q3: 16:9 (Landscape)
Q4: 1K
Q5: No reference images
Q6: 1 variant
Q7: No upscaling
Q8: ./images/

Result: 3 images, $0.12 total
```

### Example 2: High-Quality with Upscaling

```
Q1: Prompts
   A professional product photo of a luxury watch
   Modern interior design living room

Q2: Manual selection (openai/dall-e-3)
Q3: 1:1 (Square)
Q4: 2K
Q5: 2 reference images
Q6: 2 variants
Q7: 2x upscaling
Q8: /home/user/premium-images

Result: 4 images + 4 upscaled = 8 files, $0.52 total
```

### Example 3: Creative Exploration

```
Q1: Prompts (4 creative prompts)
Q2: Manual selection (cheapest model)
Q3: 4:3
Q4: 1K
Q5: No references
Q6: 3 variants
Q7: 4x upscaling
Q8: ./creative_batch

Result: 12 images + 12 upscaled = 24 files, $1.32 total
```

## Troubleshooting

### "Insufficient credits"
- Check your OpenRouter account balance
- Reduce the number of prompts or variants
- Skip upscaling to save costs

### "Generation failed"
- Check your internet connection
- Verify OpenRouter API is accessible
- Try a different model
- Check if the model supports your requested resolution

### "Cannot write to path"
- Ensure the output directory is writable
- Check disk space availability
- Verify the path exists or is creatable

## Pricing Guide

Typical costs for image generation (varies by model):

| Model | Cost | Quality | Speed |
|-------|------|---------|-------|
| Cheaper models | $0.02-0.04 | Good | Fast |
| Standard models | $0.04-0.08 | Excellent | Medium |
| Premium models | $0.08-0.15 | Top-tier | Slow |

Upscaling: +$0.02-0.08 per image (2x: $0.02-0.05, 4x: $0.04-0.08)

## Limitations

- **Max 10 prompts per session** (to prevent accidental large batches)
- **Max 5 variants per prompt** (max 50 images per batch)
- **Max 5 reference images**
- **Max 10 minute timeout** per session
- **Prompt length: 5-1500 characters**

## Support

For issues or feature requests, visit:
https://github.com/anomalyco/opencode/issues

## License

MIT License - See LICENSE.txt for details

## Development

### Architecture

```
index.js
├── Constants & Configuration
├── Utilities (validation, file I/O, etc.)
├── MCP Integration (model fetching, generation)
├── Interactive Workflow (8 questions)
├── Image Processing (base64 decode, save)
├── Metadata Generation
└── Main Workflow Orchestration
```

### Future Enhancements

- [ ] Support for multiple models in one batch
- [ ] Advanced upscaling algorithms
- [ ] Batch history and replay
- [ ] Integration with image editing tools
- [ ] Web UI for easier interaction
- [ ] Scheduled batch generation
- [ ] Cost optimization suggestions

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-08-12  
**Compatibility:** OpenCode 1.0+
